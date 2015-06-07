#
# Varnish VCL to test rfc7234
#
# Author Karto Martin <source@karto.net>
# Copyright (c) 2015 Karto Martin. All Right Reserved.
# License The MIT License
#
vcl 4.0;

import std;
import header;

include "varnish-rfc7234/tracing.vcl";
include "varnish-rfc7234/synth.vcl";
include "varnish-rfc7234/rfc7234.vcl";

backend bad {
    .host = "127.0.0.1"; .port = "1";
}
backend sick {
    .host = "127.0.0.1"; .port = "1"; .probe = { }
}


#######################################################################
# Client side

sub vcl_recv {

    call synth_recv;
    call rfc7234_recv;

    if (req.http.X-Backend == "bad") {
        set req.backend_hint = bad;
    }
    if (req.http.X-Backend == "sick") {
        set req.backend_hint = sick;
    }
    if (req.http.X-Miss) {
        set req.hash_always_miss = true;
    }

    if (req.method == "PRI") {
        /* We do not support SPDY or HTTP/2.0 */
        return (synth(405));
    }
    if (req.method != "GET" &&
      req.method != "HEAD" &&
      req.method != "PUT" &&
      req.method != "POST" &&
      req.method != "TRACE" &&
      req.method != "OPTIONS" &&
      req.method != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }

    if (req.method != "GET" && req.method != "HEAD" && req.method != "POST") {
        /* We only deal with GET, HEAD and POST*/
        return (pass);
    }
    if (req.http.Authorization || req.http.Cookie) {
        /* Not cacheable by default */
        return (pass);
    }
    return (hash);
}
#sub vcl_pipe {
#}
#sub vcl_pass {
#}
#sub vcl_hash {
#}
#sub vcl_purge {
#}
sub vcl_hit {
    
    call rfc7234_hit;
    
}
#sub vcl_miss {
#}
sub vcl_deliver {

    call rfc7234_deliver;
    
    if (obj.uncacheable)  { set resp.http.X-Cache = "PASS"; }
    elsif (0 == obj.hits) { set resp.http.X-Cache = "MISS"; }
    else                  { set resp.http.X-Cache = "HIT"; }
    
}
sub vcl_synth {
    set resp.http.X-Cache = "MISS";
    set resp.http.X-Cacheable = "NO:synth";
}


#######################################################################
# Backend Fetch

sub vcl_backend_fetch {
    call rfc7234_backend_fetch;
}
sub vcl_backend_response {
    
    if (beresp.http.Since-Modified) {
        set beresp.http.Last-Modified = now - std.duration(beresp.http.Since-Modified, 0s);
    }
    
    call rfc7234_backend_response_cacheable;
    
    set beresp.http.X-Caching = beresp.ttl+"/"+beresp.grace+"/"+beresp.keep+"/"+beresp.uncacheable;
    
    if (beresp.uncacheable)  { set beresp.http.X-Cacheable = "NO:"+beresp.http.X-Cacheable; }
    else                     { set beresp.http.X-Cacheable = "YES:"+beresp.http.X-Cacheable; }
    #if (beresp.uncacheable)  { set beresp.http.X-Cacheable = "H4P:"+beresp.http.X-Cacheable; }
    #elsif (beresp.ttl == 0s) { set beresp.http.X-Cacheable = "NO:"+beresp.http.X-Cacheable; }
    #else                     { set beresp.http.X-Cacheable = "YES:"+beresp.http.X-Cacheable; }
    
    return (deliver);
}

