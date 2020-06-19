-module(container_parse_test).

-include_lib("eunit/include/eunit.hrl").
-include("../include/container.hrl").

parsing_container_test() ->
    Parse = rest_api_handler:container_to_parse(#container{}),
    ?assert(is_list(Parse)).
