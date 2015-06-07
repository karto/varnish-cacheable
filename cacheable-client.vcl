#
# Varnish VCL for client cacheable
#
# Author Karto Martin <source@karto.net>
# Copyright (c) 2015 Karto Martin. All Right Reserved.
# License The MIT License
#


sub cacheable_hit_set_cacheable {
    
    ###
    # rfc7234   Hypertext Transfer Protocol (HTTP/1.1): Caching
    # 
    # 4.  Constructing Responses from Caches    https://tools.ietf.org/html/rfc7234#section-4
    # 
    #    When presented with a request, a cache MUST NOT reuse a stored
    #    response, unless:
    # 
    #    o  The presented effective request URI (Section 5.5 of [RFC7230]) and
    #       that of the stored response match, and
    # if (req.url != obj.http.VAR-Url) {}
    # 
    #    o  the request method associated with the stored response allows it
    #       to be used for the presented request, and
    # if (req.method != obj.http.VAR-Method) {}
    # 
    #    o  selecting header fields nominated by the stored response (if any)
    #       match those presented (see Section 4.1), and
    # if (obj.http.Vary == "*") {}
    # 
    #    o  the presented request does not contain the no-cache pragma
    #       (Section 5.4), nor the no-cache cache directive (Section 5.2.1),
    #       unless the stored response is successfully validated
    #       (Section 4.3), and
    if ((req.http.Pragma ~ "(?i)(^|,)\s*no-cache\s*(,|$)" && ! req.http.Cache-Control ) || 
            req.http.Cache-Control ~ "(?i)(^|,)\s*no-cache\s*(,|$)") {
        set req.http.X-Cacheable = "pass;req;no-cache";
    }
    
    # 
    #    o  the stored response does not contain the no-cache cache directive
    #       (Section 5.2.2.2), unless it is successfully validated
    #       (Section 4.3), and
    elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*no-cache\s*(,|$)") {
        set req.http.X-Cacheable = "pass;obj;no-cache";
    }
    
    # 
    #    o  the stored response is either:
    # 
    #       *  fresh (see Section 4.2), or
    #           The calculation to determine if a response is fresh is:
    #           
    #                response_is_fresh = (freshness_lifetime > current_age)
    #           
    #           freshness_lifetime is defined in Section 4.2.1; current_age is
    #           defined in Section 4.2.3.
    #           
    #           Clients can send the max-age or min-fresh cache directives in a
    #           request to constrain or relax freshness calculations for the
    #           corresponding response (Section 5.2.1).
    
    else {
    
        # 4.2.1.  Calculating Freshness Lifetime    https://tools.ietf.org/html/rfc7234#section-4.2.1
        #    5.2.1.1.  max-age
        #    The "max-age" request directive indicates that the client is
        #    unwilling to accept a response whose age is greater than the
        #    specified number of seconds.  Unless the max-stale request directive
        #    is also present, the client is not willing to accept a stale
        #    response.
        if (req.http.Cache-Control ~ "(?i)(^|,)\s*max-age=\d+\s*(,|$)") {
            set req.http.TMP-freshness_lifetime = std.duration(regsub(
                    req.http.Cache-Control, "(?i)^(?:.*,)?\s*max-age=(\d+)\s*(?:,.*)?$", "\1s"), 0s)+"s";
        }
        else {
            set req.http.TMP-freshness_lifetime = obj.http.VAR-freshness_lifetime;
        }
        
        # 4.2.3.  Calculating Age    https://tools.ietf.org/html/rfc7234#section-4.2.3
        set req.http.TMP-current_age = (std.duration(obj.http.VAR-freshness_lifetime, 0s) - obj.ttl)+"s";
        
        #   5.2.1.3.  min-fresh
        #   The "min-fresh" request directive indicates that the client is
        #   willing to accept a response whose freshness lifetime is no less than
        #   its current age plus the specified time in seconds.  That is, the
        #   client wants a response that will still be fresh for at least the
        #   specified number of seconds.
        if (req.http.Cache-Control ~ "(?i)(^|,)\s*min-fresh=\d+\s*(,|$)") {
            set req.http.TMP-min-fresh = std.duration(regsub(
                    req.http.Cache-Control, "(?i)^(?:.*,)?\s*min-fresh=(\d+)\s*(?:,.*)?$", "\1s"), 0s)+"s";
        }
        else {
            set req.http.TMP-min-fresh = "0.000s";
        }
        
        # 4.2.  Freshness   https://tools.ietf.org/html/rfc7234#section-4.2
        if (std.duration(req.http.TMP-freshness_lifetime, 0s) > std.duration(req.http.TMP-current_age, 0s) + std.duration(req.http.TMP-min-fresh, 0s)) {
            set req.http.X-Cacheable = "deliver;fresh";
        }
        elsif (req.http.Cache-Control ~ "(?i)(^|,)\s*min-fresh=\d+\s*(,|$)") {
            set req.http.X-Cacheable = "fetch;min-fresh="+req.http.TMP-min-fresh+";max-age="+req.http.TMP-freshness_lifetime;
        }
        elsif (req.http.Cache-Control ~ "(?i)(^|,)\s*max-age=\d+\s*(,|$)" && 
               req.http.Cache-Control !~ "(?i)(^|,)\s*max-stale(=\d+)?\s*(,|$)") {
            set req.http.X-Cacheable = "fetch;max-age="+req.http.TMP-freshness_lifetime;
        }
    
        # 
        #       *  allowed to be served stale (see Section 4.2.4), or
        #   4.2.4.  Serving Stale Responses
        #   A "stale" response is one that either has explicit expiry information
        #   or is allowed to have heuristic expiry calculated, but is not fresh
        #   according to the calculations in Section 4.2.
        #
        #   A cache MUST NOT generate a stale response if it is prohibited by an
        #   explicit in-protocol directive (e.g., by a "no-store" or "no-cache"
        #   cache directive, a "must-revalidate" cache-response-directive, or an
        #   applicable "s-maxage" or "proxy-revalidate" cache-response-directive;
        #   see Section 5.2.2).
        #           Note that cached responses that contain the "must-revalidate" and/or
        #           "s-maxage" response directives are not allowed to be served stale
        #           (Section 4.2.4) by shared caches.  In particular, a response with
        #           either "max-age=0, must-revalidate" or "s-maxage=0" cannot be used to
        #           satisfy a subsequent request without revalidating it on the origin
        #           server.
    
        # 5.2.2.1.  must-revalidate
        #   The "must-revalidate" response directive indicates that once it has
        #   become stale, a cache MUST NOT use the response to satisfy subsequent
        #   requests without successful validation on the origin server.
        #   The must-revalidate directive is necessary to support reliable
        #   operation for certain protocol features.  In all circumstances a
        #   cache MUST obey the must-revalidate directive; in particular, if a
        #   cache cannot reach the origin server for any reason, it MUST generate
        #   a 504 (Gateway Timeout) response.
        elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*must-revalidate\s*(,|$)") {
            set req.http.X-Cacheable = "fetch;must-revalidate"+req.http.X-Cacheable;
        }
        
        # 5.2.2.7.  proxy-revalidate
        #
        #   The "proxy-revalidate" response directive has the same meaning as the
        #   must-revalidate response directive, except that it does not apply to
        #   private caches.
        elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*proxy-revalidate\s*(,|$)") {
            set req.http.X-Cacheable = "fetch;proxy-revalidate"+req.http.X-Cacheable;
        }
        
        # 5.2.2.9.  s-maxage
        #   The "s-maxage" response directive indicates that, in shared caches,
        #   the maximum age specified by this directive overrides the maximum age
        #   specified by either the max-age directive or the Expires header
        #   field.  The s-maxage directive also implies the semantics of the
        #   proxy-revalidate response directive.
        elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*s-maxage=\d+\s*(,|$)") {
            set req.http.X-Cacheable = "fetch;s-maxage"+req.http.X-Cacheable;
        }
        
        #
        #   A cache MUST NOT send stale responses unless it is disconnected
        #   (i.e., it cannot contact the origin server or otherwise find a
        #   forward path) or doing so is explicitly allowed (e.g., by the
        #   max-stale request directive; see Section 5.2.1).
        #
        # 5.2.1.2.  max-stale
        #   The "max-stale" request directive indicates that the client is
        #   willing to accept a response that has exceeded its freshness
        #   lifetime.  If max-stale is assigned a value, then the client is
        #   willing to accept a response that has exceeded its freshness lifetime
        #   by no more than the specified number of seconds.  If no value is
        #   assigned to max-stale, then the client is willing to accept a stale
        #   response of any age.
        elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*max-stale=?\s*(,|$)") {
            set req.http.X-Cacheable = "deliver;max-stale";
        }
        elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*max-stale=\d+\s*(,|$)") {
            set req.http.TMP-max-stale = std.duration(regsub(
                    obj.http.Cache-Control, "(?i)^(?:.*,)?\s*max-stale=(\d+)\s*(?:,.*)?$", "\1s"), 0s)+"s";
            if (std.duration(req.http.TMP-freshness_lifetime, 0s) + std.duration(req.http.TMP-max-stale, 0s) > std.duration(req.http.TMP-current_age, 0s)) {
                set req.http.X-Cacheable = "deliver;max-stale="+req.http.TMP-max-stale+";max-age="+req.http.TMP-freshness_lifetime;
            }
            else {
                set req.http.X-Cacheable = "fetch;max-stale="+req.http.TMP-max-stale+";max-age="+req.http.TMP-freshness_lifetime;
            }
        }
        
        # is backend is sick
        elsif ( ! std.healthy(req.backend_hint)) {
            set req.http.X-Cacheable = "deliver;disconnected";
        }
        
        # 3.  The stale-while-revalidate Cache-Control Extension    http://tools.ietf.org/html/rfc5861#section-3
        #   When present in an HTTP response, the stale-while-revalidate Cache-
        #   Control extension indicates that caches MAY serve the response in
        #   which it appears after it becomes stale, up to the indicated number
        #   of seconds.
        elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*stale-while-revalidate=?\s*(,|$)") {
            set req.http.X-Cacheable = "deliver;stale-while-revalidate";
        }
        elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*stale-while-revalidate=\d*\s*(,|$)") {
            set req.http.TMP-stale-while-revalidate = std.duration(regsub(
                    obj.http.Cache-Control, "(?i)^(?:.*,)?\s*stale-while-revalidate=(\d+)\s*(?:,.*)?$", "\1s"), 0s)+"s";
            if (std.duration(req.http.TMP-freshness_lifetime, 0s) + std.duration(req.http.TMP-stale-while-revalidate, 0s) > std.duration(req.http.TMP-current_age, 0s)) {
                set req.http.X-Cacheable = "deliver;stale-while-revalidate="+req.http.TMP-stale-while-revalidate+";max-age="+req.http.TMP-freshness_lifetime;
            }
            else {
                set req.http.X-Cacheable = "fetch;stale-while-revalidate="+req.http.TMP-stale-while-revalidate+";max-age="+req.http.TMP-freshness_lifetime;
            }
        }
        
        # 
        #       *  successfully validated (see Section 4.3).
        else {
            set req.http.X-Cacheable = "fetch;revalidate";
        }
        
        # 
        #    Note that any of the requirements listed above can be overridden by a
        #    cache-control extension; see Section 5.2.3.
        #    
        
        # 4.  The stale-if-error Cache-Control Extension    http://tools.ietf.org/html/rfc5861#section-4
        #   The stale-if-error Cache-Control extension indicates that when an
        #   error is encountered, a cached stale response MAY be used to satisfy
        #   the request, regardless of other freshness information.
        #
        #   When used as a request Cache-Control extension, its scope of
        #   application is the request it appears in; when used as a response
        #   Cache-Control extension, its scope is any request applicable to the
        #   cached response in which it occurs.
        #
        #   Its value indicates the upper limit to staleness; when the cached
        #   response is more stale than the indicated amount, the cached response
        #   SHOULD NOT be used to satisfy the request, absent other information.
        #
        #   In this context, an error is any situation that would result in a
        #   500, 502, 503, or 504 HTTP response status code being returned.
        #
        #   Note that this directive does not affect freshness; stale cached
        #   responses that are used SHOULD still be visibly stale when sent
        #   (i.e., have a non-zero Age header and a warning header, as per HTTP's
        #   requirements).
        if (req.http.X-Cacheable ~ "^fetch;") {
            if (req.http.Cache-Control ~ "(?i)(^|,)\s*stale-if-error=?\s*(,|$)") {
                set req.http.X-Cacheable = req.http.X-Cacheable+";req;stale-if-error";
            }
            elsif (req.http.Cache-Control ~ "(?i)(^|,)\s*stale-if-error=\d+\s*(,|$)") {
                set req.http.TMP-stale-if-error = std.duration(regsub(
                        req.http.Cache-Control, "(?i)^(?:.*,)?\s*stale-if-error=(\d+)\s*(?:,.*)?$", "\1s"), 0s)+"s";
                if (std.duration(req.http.TMP-freshness_lifetime, 0s) + std.duration(req.http.TMP-stale-if-error, 0s) > std.duration(req.http.TMP-current_age, 0s)) {
                    set req.http.X-Cacheable = req.http.X-Cacheable+";req;stale-if-error="+req.http.TMP-stale-if-error;
                }
            }
            elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*stale-if-error=?\s*(,|$)") {
                set req.http.X-Cacheable = req.http.X-Cacheable+";obj;stale-if-error";
            }
            elsif (obj.http.Cache-Control ~ "(?i)(^|,)\s*stale-if-error=\d+\s*(,|$)") {
                set req.http.TMP-stale-if-error = std.duration(regsub(
                        obj.http.Cache-Control, "(?i)^(?:.*,)?\s*stale-if-error=(\d+)\s*(?:,.*)?$", "\1s"), 0s);
                if (std.duration(req.http.TMP-freshness_lifetime, 0s) + std.duration(req.http.TMP-stale-if-error, 0s) > std.duration(req.http.TMP-current_age, 0s)) {
                    set req.http.X-Cacheable = req.http.X-Cacheable+";obj;stale-if-error="+req.http.TMP-stale-if-error;
                }
            }
        }
        
    }
    
}

sub cacheable_hit_revalidate {

    # return (fetch);
    # Varnish SNAFU - Would be nice just to just request a 304 Not Modified.
    # set obj.ttl = 0s;
    # softpurge.purge();
    # return (fetch);
    # Alternative - there is no need to remove all variations
    if (obj.ttl < 0s) {
        return (fetch);
    }
    else {
        std.log("cacheable_hit_cacheable: TODO: Better revalidation instead of pass");
        std.syslog(13, "cacheable_hit_cacheable: TODO: Better revalidation of pass");
        header.append(req.http.VAR-Log, "cacheable_hit_cacheable: TODO: Better revalidation instead of pass");
        return (pass);
    }
}

