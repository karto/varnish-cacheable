#
# Varnish VCL subroutine trace / debug logging
#
# Author Karto Martin <source@karto.net>
# Copyright (c) 2015 Karto Martin. All Right Reserved.
# License The MIT License
#

sub vcl_recv {
    std.log("vcl_recv: req: " + req.method + " " + req.url + " " + req.proto + " restarts: " + req.restarts + " ttl: " + req.ttl + " mode: "+req.http.Var-Mode);
    std.log("vcl_recv: backend: " + req.backend_hint + " healthy: " + std.healthy(req.backend_hint));
}

sub vcl_pipe {
    std.log("vcl_pipe: req: " + req.method + " " + req.url + " " + req.proto + " restarts: " + req.restarts + " ttl: " + req.ttl + " mode: "+req.http.Var-Mode);
    std.log("vcl_pipe: bereq: " + bereq.method + " " + bereq.url + " " + bereq.proto);
    std.log("vcl_pipe: backend: " + req.backend_hint + " healthy: " + std.healthy(req.backend_hint));
}

sub vcl_pass {
    std.log("vcl_pass: req: " + req.method + " " + req.url + " " + req.proto + " restarts: " + req.restarts + " ttl: " + req.ttl + " mode: "+req.http.Var-Mode);
    std.log("vcl_pass: backend: " + req.backend_hint + " healthy: " + std.healthy(req.backend_hint));
}
sub vcl_hash {
    std.log("vcl_hash: req: " + req.method + " " + req.url + " " + req.proto + " restarts: " + req.restarts + " ttl: " + req.ttl + " mode: "+req.http.Var-Mode);
    std.log("vcl_hash: backend: " + req.backend_hint + " healthy: " + std.healthy(req.backend_hint));
}

sub vcl_purge {
    std.log("vcl_purge: req: " + req.method + " " + req.url + " " + req.proto + " restarts: " + req.restarts + " ttl: " + req.ttl + " mode: "+req.http.Var-Mode);
    std.log("vcl_purge: backend: " + req.backend_hint + " healthy: " + std.healthy(req.backend_hint));
}

sub vcl_hit {
    std.log("vcl_hit: req: " + req.method + " " + req.url + " " + req.proto + " restarts: " + req.restarts + " ttl: " + req.ttl + " mode: "+req.http.Var-Mode);
    std.log("vcl_hit: obj: proto: " + obj.proto + " ttl: " + obj.ttl + " grace: " + obj.grace + " hits: " + obj.hits + " Age: " + obj.http.Age + " X-Caching: " + obj.http.X-Caching + " X-Cacheable: " + obj.http.X-Cacheable);
    std.log("vcl_hit: obj: keep: " + obj.keep + " reason: " + obj.reason + " status: " + obj.status + " ttl: " + obj.ttl);
    std.log("vcl_hit: backend: " + req.backend_hint + " healthy: " + std.healthy(req.backend_hint));
}

sub vcl_miss {
    std.log("vcl_miss: req: " + req.method + " " + req.url + " " + req.proto + " restarts: " + req.restarts + " ttl: " + req.ttl + " mode: "+req.http.Var-Mode);
    std.log("vcl_miss: backend: " + req.backend_hint + " healthy: " + std.healthy(req.backend_hint));
}

sub vcl_deliver {
    std.log("vcl_deliver: req: " + req.method + " " + req.url + " " + req.proto + " restarts: " + req.restarts + " ttl: " + req.ttl + " mode: "+req.http.Var-Mode);
    std.log("vcl_deliver: resp: " + resp.status + " " + resp.reason + " " + resp.proto + " hits: " + obj.hits + " X-Cacheable: " + resp.http.X-Cacheable);
    std.log("vcl_deliver: obj: hits: " + obj.hits + " uncacheable: " + obj.uncacheable);
    std.log("vcl_deliver: backend: " + req.backend_hint + " healthy: " + std.healthy(req.backend_hint));
}

sub vcl_synth {
    std.log("vcl_synth: req: " + req.method + " " + req.url + " " + req.proto + " restarts: " + req.restarts + " ttl: " + req.ttl + " mode: "+req.http.Var-Mode);
    std.log("vcl_synth: resp: " + resp.status + " " + resp.reason + " " + resp.proto + " X-Cacheable: " + resp.http.X-Cacheable);
    std.log("vcl_synth: backend: " + req.backend_hint + " healthy: " + std.healthy(req.backend_hint));
}

sub vcl_backend_fetch {
    std.log("vcl_fetch: bereq: " + bereq.method + " " + bereq.url + " " + bereq.proto + " retries: " + bereq.retries + " uncacheable: " + bereq.uncacheable + " mode: "+bereq.http.Var-Mode);
    std.log("vcl_fetch: backend: " + bereq.backend + " healthy: " + std.healthy(bereq.backend));
}
sub vcl_backend_response {
    std.log("vcl_response: bereq: " + bereq.method + " " + bereq.url + " " + bereq.proto + " retries: " + bereq.retries + " uncacheable: " + bereq.uncacheable + " mode: "+bereq.http.Var-Mode);
    std.log("vcl_response: beresp: " + beresp.status + " " + beresp.reason + " " + beresp.proto + " ttl: " + beresp.ttl + " grace: " + beresp.grace + " keep: " + beresp.keep + " uncacheable: " + beresp.uncacheable);
    std.log("vcl_response: backend: " + bereq.backend + " healthy: " + std.healthy(bereq.backend) + " name: " + beresp.backend.name + " ip: " + beresp.backend.ip + " port: " + std.port(beresp.backend.ip));
}
sub vcl_backend_error {
    std.log("vcl_error: beresp: " + beresp.status + " " + beresp.reason + " " + beresp.proto + " grace: " + beresp.grace);
    std.log("vcl_error: backend: " + bereq.backend + " healthy: " + std.healthy(bereq.backend));
}

