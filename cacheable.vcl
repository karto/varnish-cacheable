#
# Varnish VCL for cacheable
#
# Author Karto Martin <source@karto.net>
# Copyright (c) 2015 Karto Martin. All Right Reserved.
# License The MIT License
#


#######################################################################
# Client side

sub cacheable_recv {
    
    # Only deal with "normal" types
    if ("GET"   != req.method && "HEAD"    != req.method && "POST"   != req.method && "PUT" != req.method && 
        "TRACE" != req.method && "OPTIONS" != req.method && "DELETE" != req.method) {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }
    
    # 5.2.1.6.  no-transform    http://tools.ietf.org/html/rfc7234#section-5.2.1.6
    #   The "no-transform" request directive indicates that an intermediary
    #   (whether or not it implements a cache) MUST NOT transform the
    #   payload, as defined in Section 5.7.2 of [RFC7230].
    if (req.http.Cache-Control ~ "(?i)(^|,)\s*no-transform\s*(,|$)") {
        set req.esi = false;
    }

    # Only cache GET or HEAD requests. This makes sure the POST requests are always passed.
    # POST could be cached, but varnish doesn't support it
    if ("GET" != req.method && "HEAD" != req.method) {
        /* We only deal with GET and HEAD by default */
        return (pass);
    }
    
}
#sub cacheable_pipe {
#}
#sub cacheable_pass {
#}
#sub cacheable_hash {
#}
#sub cacheable_purge {
#}
sub cacheable_hit {
    
    call cacheable_hit_set_cacheable;
    
    # 5.2.1.7.  only-if-cached
    if (req.http.Cache-Control ~ "(?i)(^|,)\s*only-if-cached\s*(,|$)" && req.http.X-Cacheable !~ "^deliver;") {
        return (synth (504, "hit/only-if-cached"));
    }
    
    # pass cacheable
    if (req.http.X-Cacheable ~ "^pass;") {
        return (pass);
    }
    
    # Fetch cacheable
    if (req.http.X-Cacheable ~ "^fetch;") {
        call cacheable_hit_revalidate;
    }
    
    # Unknown not deliverable cacheable
    if (req.http.X-Cacheable !~ "^deliver;") {
        std.log("cacheable_hit_cacheable: Unknown cacheable directive: " + req.http.X-Cacheable);
        std.syslog(13, "cacheable_hit_cacheable: Unknown cacheable directive: " + req.http.X-Cacheable);
        header.append(req.http.VAR-Log, "cacheable_hit_cacheable: Unknown cacheable directive: " + req.http.X-Cacheable);
        return (pass);
    }
    
}
sub cacheable_miss {
    
    # 5.2.1.7.  only-if-cached
    if (req.http.Cache-Control ~ "(?i)(^|,)\s*only-if-cached\s*(,|$)") {
        return (synth (504, "miss/only-if-cached"));
    }
    
}
sub cacheable_deliver {
    if (obj.uncacheable) {
        set resp.http.X-Cache = "PASS";
    } elsif (obj.hits == 0) {
        set resp.http.X-Cache = "MISS";
    } else {
        set resp.http.X-Cache = "HIT";
    }
}

#######################################################################
# Backend Fetch

#sub cacheable_backend_fetch {
#}
sub cacheable_backend_response {
    
    call cacheable_backend_response_cacheable;
}
#sub cacheable_backend_error {
#}


#######################################################################
# Housekeeping

#sub cacheable_init {
#}
#sub cacheable_fini {
#}
