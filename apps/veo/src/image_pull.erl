-module(image_pull).

-export([pull/1]).


pull(Image) ->
    httpc:request(post, Image, {unix_socket, "/var/run/docker.sock"}).
