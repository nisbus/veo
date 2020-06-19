-module(container_sup_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/container.hrl").

container_add_service_test() ->
    application:start(yamerl),
    [H|B] = settings:get_applications(),
    container_sup:add_service(B).

