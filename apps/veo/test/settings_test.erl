-module(settings_test).
-include_lib("eunit/include/eunit.hrl").
-include("../include/container.hrl").

ulimit_test() ->    
    application:start(yamerl),
    [H|[T]] = settings:get_applications(),
    io:format(user, "Service ~p~n", [T]),
    #service{ulimits=[#ulimits{name=Name, soft=Soft, hard=Hard}]} = T,
    ?assert(Name == "memlock"),
    ?assert(Soft == -1),
    ?assert(Hard == -1),
    Built = container_builder:build(T),
    io:format(user, "Built ~p~n", [Built]).    

node_test() ->    
    application:start(yamerl),
    PrivDir = code:priv_dir(veo),
    Parsed = settings:get_nodes(PrivDir++"/cluster.yml"),
    io:format(user, "*********NODES*********~n~p~n", [Parsed]).


telegraf_test() ->	
    application:start(yamerl),
    [H|[_T]] = settings:get_applications(),
    io:format(user, "Service ~p~n", [H]).


	
    
