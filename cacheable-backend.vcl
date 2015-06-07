#
# Varnish VCL for backend cacheable
#
# Author Karto Martin <source@karto.net>
# Copyright (c) 2015 Karto Martin. All Right Reserved.
# License The MIT License
#


sub cacheable_backend_response_cacheable {
    
    ###
    # rfc7231   Hypertext Transfer Protocol (HTTP/1.1): Semantics and Content
    # rfc7234   Hypertext Transfer Protocol (HTTP/1.1): Caching
    # rfc7234   3.  Storing Responses in Caches    https://tools.ietf.org/html/rfc7234#section-3
    #
    # A cache MUST NOT store a response to any request, unless:
    
    # o  The request method is understood by the cache and defined as being
    #    cacheable, and
    # rfc7231   4.2.3.  Cacheable Methods    https://tools.ietf.org/html/rfc7231#section-4.2.3
    if ("GET" != bereq.method && "HEAD" != bereq.method) {
        set beresp.http.X-Cacheable = "NO;method";
        set beresp.uncacheable = true;
        set beresp.ttl = 0s; // No hit for pass
    }

    ## varnish - default understood status codes   
    ## : 200 203         300 301 302 304 307 404     410
    ## rfc7231 - cacheable by default status codes 
    ## : 200 203 204 206 300 301             404 405 410 414 501
    ## consider for default : 204 205
    ## consider for freshness: 302 303 307 401 403 405 406 500 501 502 503 504 505
    ## never be cached: 201 202 305 306 402 408 409 411 412 413 415 417
    #
    ###: custom understood status codes
    ## : 200 203 204 205 300 301 302 303 304 307 308 
    ## : 400 403 404 405 406 410 414 418 
    ## : 500 501 502 503 504 505 
    
    # o  the response status code is understood by the cache, and
    # rfc7231   6.1.  Overview of Status Codes    https://tools.ietf.org/html/rfc7231#section-6.1
    elsif (regsub(beresp.status, "", "") !~ "^(20[0345]|30[0123478]|40[03456]|41[048]|50[012345])$") {
        set beresp.http.X-Cacheable = "H4P;status";
        set beresp.uncacheable = true;
        set beresp.ttl = 119s; // Hit for pass
    }
    
    # o  the "no-store" cache directive (see Section 5.2) does not appear
    #    in request or response header fields, and
    # rfc7234   5.2.1.5.  no-store    https://tools.ietf.org/html/rfc7234#section-5.2.1.5
    elsif (bereq.http.Cache-Control ~ "(?i)(^|,)\s*no-store\s*(,|$)") {
        set beresp.http.X-Cacheable = "H4P;req;no-store";
        set beresp.uncacheable = true;
        set beresp.ttl = 119s; // Hit for pass
    }
    # rfc7234   5.2.2.3.  no-store    https://tools.ietf.org/html/rfc7234#section-5.2.2.3
    elsif (beresp.http.Cache-Control ~ "(?i)(^|,)\s*no-store\s*(,|$)") {
        set beresp.http.X-Cacheable = "H4P;resp;no-store";
        set beresp.uncacheable = true;
        set beresp.ttl = 119s; // Hit for pass
    }
    
    # o  the "private" response directive (see Section 5.2.2.6) does not
    #    appear in the response, if the cache is shared, and
    # rfc7234   5.2.2.6.  private    https://tools.ietf.org/html/rfc7234#section-5.2.2.6
    elsif (beresp.http.Cache-Control ~ "(?i)(^|,)\s*private\s*(,|$)") {
        set beresp.http.X-Cacheable = "H4P;private";
        set beresp.uncacheable = true;
        set beresp.ttl = 119s; // Hit for pass
    }
    
    # o  the Authorization header field (see Section 4.2 of [RFC7235]) does
    #    not appear in the request, if the cache is shared, unless the
    #    response explicitly allows it (see Section 3.2), and
    # rfc7234   3.2.  Storing Responses to Authenticated Requests    https://tools.ietf.org/html/rfc7234#section-3.2
    elsif (bereq.http.Authorization && beresp.http.Cache-Control !~ "(?i)(^|,)\s*(must-revalidate|public|s-maxage=\d+|dr-maxage=\d+)\s*(?=,|$)") {
        set beresp.http.X-Cacheable = "NO:authorization";
        set beresp.uncacheable = true;
        set beresp.ttl = 0s; // No hit for pass
    }
    
    # o  the response either:
    # rfc7234   4.2.1.  Calculating Freshness Lifetime  https://tools.ietf.org/html/rfc7234#section-4.2.1
    # A cache can calculate the freshness lifetime (denoted as
    # freshness_lifetime) of a response by using the first match of the
    # following:

    #    o  If the cache is varnish and the v-maxage response directive
    #       is present, use its value, or
    #    *  contains a dr-maxage=ttl[+grace] response directive (custom varnish ttl and grace)
    elsif (beresp.http.Cache-Control ~ "(?i)(^|,)\s*dr-maxage=\d+(\+\d+)?\s*(,|$)") {
        set beresp.http.X-Cacheable = "YES;"+regsub(beresp.http.Cache-Control, "(?i)^(?:.*,)?\s*(dr-maxage=\d+(?:\+\d+)?)\s*(?:,.*)?$", "\1");
        set beresp.ttl = std.duration(regsub(beresp.http.Cache-Control, "(?i)^(?:.*,)?\s*dr-maxage=(\d+)(?:\+\d+)?\s*(?:,.*)?$", "\1")+"s", 0s);
        if (beresp.http.Cache-Control ~ "(?i)(^|,)\s*dr-maxage=\d+\+\d+\s*(,|$)") {
            set beresp.http.X-Cacheable = beresp.http.X-Cacheable+";dr;grace="+std.duration(beresp.http.VAR-stale-if-error, 0s);
            set beresp.grace = std.duration(regsub(beresp.http.Cache-Control, "(?i)^(?:.*,)?\s*dr-maxage=\d+\+(\d+)\s*(?:,.*)?$", "\1")+"s", 0s);
        }
    }
    
    #    o  If the cache is shared and the s-maxage response directive
    #       (Section 5.2.2.9) is present, use its value, or
    #    *  contains a s-maxage response directive (see Section 5.2.2.9)
    #       and the cache is shared, or
    # rfc7234   5.2.2.9.  s-maxage    https://tools.ietf.org/html/rfc7234#section-5.2.2.9
    elsif (beresp.http.Cache-Control ~ "(?i)(^|,)\s*s-maxage=\d+\s*(,|$)") {
        set beresp.http.X-Cacheable = "YES;"+regsub(beresp.http.Cache-Control, "(?i)^(?:.*,)?\s*(s-maxage=\d+)\s*(?:,.*)?$", "\1");
        set beresp.ttl = std.duration(regsub(beresp.http.Cache-Control, "(?i)^(?:.*,)?\s*s-maxage=(\d+)\s*(?:,.*)?$", "\1")+"s", 0s);
    }
    
    #    o  If the max-age response directive (Section 5.2.2.8) is present,
    #       use its value, or
    #    *  contains a max-age response directive (see Section 5.2.2.8), or
    # rfc7234   5.2.2.8.  max-age    https://tools.ietf.org/html/rfc7234#section-5.2.2.8
    elsif (beresp.http.Cache-Control ~ "(?i)(^|,)\s*max-age=\d+\s*(,|$)") {
        set beresp.http.X-Cacheable = "YES;"+regsub(beresp.http.Cache-Control, "(?i)^(?:.*,)?\s*(max-age=\d+)\s*(?:,.*)?$", "\1");
        set beresp.ttl = std.duration(regsub(beresp.http.Cache-Control, "(?i)^(?:.*,)?\s*max-age=(\d+)\s*(?:,.*)?$", "\1")+"s", 0s);
    }
    
    #    o  If the Expires response header field (Section 5.3) is present, use
    #       its value minus the value of the Date response header field, or
    #    *  contains an Expires header field (see Section 5.3), or
    # rfc7234   5.3.  Expires    https://tools.ietf.org/html/rfc7234#section-5.3
    elsif (beresp.http.Expires) {
        if (std.time(beresp.http.Expires, now) > std.time(beresp.http.Date, now)) {
            set beresp.http.X-Cacheable = "YES;"+"expires="+(std.time(beresp.http.Expires, now) - std.time(beresp.http.Date, now));
            set beresp.ttl = std.time(beresp.http.Expires, now) - std.time(beresp.http.Date, now);
        }
        else {
            set beresp.http.X-Cacheable = "H4P;"+"expires=past";
            set beresp.uncacheable = true;
            set beresp.ttl =  119s; // Hit for pass
        }
    }

    #    o  Otherwise, no explicit expiration time is present in the response.
    #       A heuristic freshness lifetime might be applicable; see
    #       Section 4.2.2.
    
    #    *  contains a Cache Control Extension (see Section 5.2.3) that
    #       allows it to be cached, or
    #elsif (beresp.http.Cache-Control ~ "(?i)(^|,)\s*extension\s*(,|$)") { }
    
    
    ## varnish - default understood status codes   
    ## : 200 203         300 301 302 304 307 404     410
    ## rfc7231 - cacheable by default status codes 
    ## : 200 203 204 206 300 301             404 405 410 414 501
    ## consider for default : 204 205
    ## consider for freshness: 302 303 307 401 403 405 406 500 501 502 503 504 505
    ## never be cached: 201 202 305 306 402 408 409 411 412 413 415 417
    ##
    ###: custom understood status codes
    ## : 200 203 204 205 206 300 301 302 303 304 307 308 
    ## : 400 403 404 405 406 410 414 418 
    ## : 500 501 502 503 504 505 
    ##
    ###: custom cacheable by default
    ## : 200 203 204 300 301 302 303 304 307 308 
    ## : 404 405 410 414 418 500 501 502 503 504

    #    *  has a status code that is defined as cacheable by default (see
    #       Section 4.2.2), or
    # rfc7231   6.1.  Overview of Status Codes    https://tools.ietf.org/html/rfc7231#section-6.1
    # rfc7231 and varnish default status codes : 200 203 204 300 301 302 304 307 404 405 410 414 501
    elsif (regsub(beresp.status, "", "") ~ "^(20[034]|30[01247]|40[45]|41[04]|501)$") {
        if (beresp.http.Last-Modified && std.time(beresp.http.Last-Modified, now) < now) {
            set beresp.http.X-Cacheable = "YES:default=10s<"+regsub((now - std.time(beresp.http.Last-Modified, now)) * 0.1, "\.\d\d\d$", "")+"s<1d";
            if ((now - std.time(beresp.http.Last-Modified, now)) * 0.1 <= 10s) {
                set beresp.ttl = 10s;
            }
            elsif ((now - std.time(beresp.http.Last-Modified, now)) * 0.1 < 1d) {
                set beresp.ttl = (now - std.time(beresp.http.Last-Modified, now)) * 0.1;
            }
            else {
                set beresp.ttl = 1d;
            }
        }
        else {
            set beresp.http.X-Cacheable = "YES:default=119s";
            set beresp.ttl = 119s;
        }
    }
    ## Extended default status codes
    ## : 303 308 418 500 502 503 504
    elsif (regsub(beresp.status, "", "") ~ "^(30[38]|418|50[0234])$") {
        if (beresp.http.Last-Modified && std.time(beresp.http.Last-Modified, now) < now) {
            set beresp.http.X-Cacheable = "YES:extended=10s<"+regsub((now - std.time(beresp.http.Last-Modified, now)) * 0.01, "\.\d\d\d$", "")+"<1h";
            if ((now - std.time(beresp.http.Last-Modified, now)) * 0.01 <= 10s) {
                set beresp.ttl = 10s;
            }
            elsif ((now - std.time(beresp.http.Last-Modified, now)) * 0.01 < 1h) {
                set beresp.ttl = (now - std.time(beresp.http.Last-Modified, now)) * 0.01;
            }
            else {
                set beresp.ttl = 1h;
            }
        }
        else {
            set beresp.http.X-Cacheable = "YES:extended=19s";
            set beresp.ttl = 19s;
        }
    }
    
    #    *  contains a public response directive (see Section 5.2.2.5).
    # rfc7234   5.2.2.5.  public    https://tools.ietf.org/html/rfc7234#section-5.2.2.5
    elsif (beresp.http.Cache-Control ~ "(?i)(^|,)\s*public\s*(,|$)") {
        if (beresp.http.Last-Modified && std.time(beresp.http.Last-Modified, now) < now) {
            set beresp.http.X-Cacheable = "YES:public=10s<"+regsub((now - std.time(beresp.http.Last-Modified, now)) * 0.1, "\.\d\d\d$", "")+"<1d";
            if ((now - std.time(beresp.http.Last-Modified, now)) * 0.1 <= 10s) {
                set beresp.ttl = 10s;
            }
            elsif ((now - std.time(beresp.http.Last-Modified, now)) * 0.1 < 1d) {
                set beresp.ttl = (now - std.time(beresp.http.Last-Modified, now)) * 0.1;
            }
            else {
                set beresp.ttl = 1d;
            }
        }
        else {
            set beresp.http.X-Cacheable = "YES:public=119s";
            set beresp.ttl = 119s;
        }
    }
    
    # The rest - no matching rules
    else {
        set beresp.http.X-Cacheable = "NO:others";
        set beresp.uncacheable = true;
        set beresp.ttl = 0s; // No hit for pass
    }
    
    # Set grace
    if (beresp.http.Cache-Control !~ "(?i)(^|,)\s*dr-maxage=\d+\+\d+\s*(,|$)") {

        # 3.  The stale-while-revalidate Cache-Control Extension    http://tools.ietf.org/html/rfc5861#section-3
        #   When present in an HTTP response, the stale-while-revalidate Cache-
        #   Control extension indicates that caches MAY serve the response in
        #   which it appears after it becomes stale, up to the indicated number
        #   of seconds.
        if (beresp.http.Cache-Control ~ "(?i)(^|,)\s*stale-while-revalidate=\d*\s*(,|$)") {
            set beresp.http.VAR-stale-while-revalidate = std.duration(regsub(
                    beresp.http.Cache-Control, "(?i)^(?:.*,)?\s*stale-while-revalidate=(\d+)\s*(?:,.*)?$", "\1s"), 0s)+"s";
        }

        # 4.  The stale-if-error Cache-Control Extension    http://tools.ietf.org/html/rfc5861#section-4
        #   The stale-if-error Cache-Control extension indicates that when an
        #   error is encountered, a cached stale response MAY be used to satisfy
        #   the request, regardless of other freshness information.
        if (beresp.http.Cache-Control ~ "(?i)(^|,)\s*stale-if-error=\d+\s*(,|$)") {
            set beresp.http.VAR-stale-if-error = std.duration(regsub(
                    beresp.http.Cache-Control, "(?i)^(?:.*,)?\s*stale-if-error=(\d+)\s*(?:,.*)?$", "\1s"), 0s)+"s";
        }
        
        # Default grace
        if (beresp.http.Last-Modified && std.time(beresp.http.Last-Modified, now) < now) {
            if ((now - std.time(beresp.http.Last-Modified, now)) * 0.5 <= 10s) {
                set beresp.http.VAR-stale-default = "10s";
            }
            elsif ((now - std.time(beresp.http.Last-Modified, now)) * 0.5 < 1d) {
                set beresp.http.VAR-stale-default = ((now - std.time(beresp.http.Last-Modified, now)) * 0.5)+"s";
            }
            else {
                set beresp.http.VAR-stale-default = "86400s";
            }
        }
        else {
            set beresp.http.VAR-stale-default = "59s";
        }
    
        
        # Pick largest grace
        if (std.duration(beresp.http.VAR-stale-while-revalidate, 0s) >= std.duration(beresp.http.VAR-stale-if-error, 0s) && 
                std.duration(beresp.http.VAR-stale-while-revalidate, 0s) > std.duration(beresp.http.VAR-stale-default, 0s)) {
            set beresp.http.X-Cacheable = beresp.http.X-Cacheable+";swr;grace="+std.duration(beresp.http.VAR-stale-while-revalidate, 0s);
            set beresp.grace = std.duration(beresp.http.VAR-stale-while-revalidate, 0s);
        }
        elsif (std.duration(beresp.http.VAR-stale-if-error, 0s) >= std.duration(beresp.http.VAR-stale-while-revalidate, 0s) && 
                std.duration(beresp.http.VAR-stale-if-error, 0s) > std.duration(beresp.http.VAR-stale-default, 0s)) {
            set beresp.http.X-Cacheable = beresp.http.X-Cacheable+";sie;grace="+std.duration(beresp.http.VAR-stale-if-error, 0s);
            set beresp.grace = std.duration(beresp.http.VAR-stale-if-error, 0s);
        }
        else {
            set beresp.http.X-Cacheable = beresp.http.X-Cacheable+";def;grace="+std.duration(beresp.http.VAR-stale-default, 0s);
            set beresp.grace = std.duration(beresp.http.VAR-stale-default, 0s);
        }
        
    }
    
    # Set cache info for verbose
    set beresp.http.X-Caching = beresp.ttl + "/" + beresp.grace + "/" + beresp.keep + "/" + beresp.uncacheable;

    # cacheable for freshness and stale serving
    if ( ! beresp.uncacheable) {
        set beresp.http.VAR-freshness_lifetime = beresp.ttl+"s";
        if (beresp.ttl == 0s) {
            std.log("cacheable_backend_response_cacheable: ttl=1ms hack for stale serving");
            set beresp.ttl = 1ms;
        }
    }

}

