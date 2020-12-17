-module(container_sup_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/container.hrl").

container_add_service_test() ->
    PrivDir = code:priv_dir(veo),
    application:start(yamerl),
    [H|[B]] = settings:get_applications(PrivDir++"/test_cluster.yml"),
    io:format(user, "Service = ~p~n",[B]).
%    container_sup:add_service(B).

