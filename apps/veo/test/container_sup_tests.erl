-module(container_sup_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/container.hrl").

container_add_service_test() ->
    PrivDir = code:priv_dir(veo),
    application:start(yamerl),
    [_H|[B]] = settings:get_applications(PrivDir++"/veo.yml"),
    io:format(user, "Service = ~p~n",[B]).

