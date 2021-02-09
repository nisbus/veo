-module(settings_test).
-include_lib("eunit/include/eunit.hrl").
-include("../include/container.hrl").

node_test() ->    
    application:start(yamerl),
    PrivDir = code:priv_dir(veo),
    Parsed = settings:get_nodes(PrivDir++"/veo.yml"),
    io:format(user, "*********NODES*********~n~p~n", [Parsed]).


telegraf_test() ->	
    application:start(yamerl),
    [H|[_T]] = settings:get_applications(),
    io:format(user, "Service ~p~n", [H]).


	
    
