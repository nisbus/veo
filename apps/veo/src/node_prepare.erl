-module(node_prepare).
-include("../include/service.hrl").
-export([pull/1, pull_image/2]).

pull(File) ->
    Apps = settings:get_applications(File),
    lists:map(fun(#service{image=Image}) ->
		      spawn(node_prepare, pull_image, [Image, self()])
	      end,Apps).

pull_image(Image, Sender) ->
    io:format(user, "docker_image ~p, requested by ~p~n", [Image, Sender]),
    Pulled = os:cmd("docker pull "++Image),
    io:format("Pulled ~p~n", [Pulled]).
 
