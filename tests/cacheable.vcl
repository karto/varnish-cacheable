#
# Varnish VCL to test cacheable
#
# Author Karto Martin <source@karto.net>
# Copyright (c) 2015 Karto Martin. All Right Reserved.
# License The MIT License
#

#backend bad {
#    .host = "127.0.0.1"; .port = "1";
#}
#backend sick {
#    .host = "127.0.0.1"; .port = "1"; .probe = { }
#}


#######################################################################
# Client side

sub vcl_recv {
    call cacheable_recv;
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
    call cacheable_hit;
}
sub vcl_miss {
    call cacheable_miss;
}
#sub vcl_deliver {
#}
#sub vcl_synth {
#}


#######################################################################
# Backend Fetch

#sub vcl_backend_fetch {
#}
sub vcl_backend_response {
    call cacheable_backend_response;
}

