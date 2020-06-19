-module(container_storage_test).
-include_lib("eunit/include/eunit.hrl").
-include("../include/container.hrl").

create_container_table_test() ->
    application:set_env(mnesia, dir, "."),
    container_storage:ensure_mnesia_started(),
    mnesia:create_schema([node()]),
    Created = container_storage:create_container_table(),
    io:format(user, "Created table ~p~n", [Created]),
    ?assert(Created =:= ok).
    
save_container_test() ->
    C = #container{},
    Saved = container_storage:save_container(C),
    io:format(user, "Saved ~p~n", [Saved]).

load_containers_by_node_test() ->
    Node = erlang:node(),
    C = #container{node = Node},
    container_storage:save_container(C),
    Containers = container_storage:containers_for_node(Node),
    [H|_] = Containers,
    ?assert(Node =:= H#container.node).

load_containers_by_names_test() ->
    Node = erlang:node(),
    C0 = #container{node=Node, id="HASH", service=#service{name="nginx"}},
    container_storage:save_container(C0),
    [HASH|_] = container_storage:container_by_id("HASH"),
    ?assert(HASH#container.id =:= "HASH"),
    [NGINX|_] = container_storage:containers_by_service_name("nginx").
%    #container{service=#service{name=Name} = NGINX,
%    ?assert(Name =:= "nginx").
    
create_and_load_a_fully_nested_container_test() ->
    S = #service{id = <<"asdfasdf">>,
		 name="nginx",
		 restart=restart,
		 restart_count=2,
		 privileged=true,
		 network_mode = <<"host">>,
		 pid_mode = <<"host">>,
		 roles=["master", "slave"],
		 hosts=["localhost"],
		 cpus=5.0,
		 memory=8000.0,
		 disk=320000.0,
		 labels=[<<"LABEL=LABEL">>],
		 ports=[#port{host_port=1, container_port=1, name="testPort", protocol=udp, random=true}],
		 healthcheck=#healthcheck{cmd=inherit, start_period=5, interval=8,timeout=4,retries=3,shell=true}		 
		},
    TestObject = #container{id="HASHED",
			    restart_counter=2,
			    pid = self(),
			    service=S,
			    status = running,
			    ip_address = {127,0,0,1},
			    port_maps=[],
			    node=erlang:node()},
    Saved = container_storage:save_container(TestObject),
    io:format(user, "Saved ~p~n", [Saved]),
    [Found|_] = container_storage:container_by_id("HASHED"),
    io:format(user, "H= ~p~n",[Found]).
    
delete_container_by_id_test() ->    
    C = #container{id="delete_me"},
    container_storage:save_container(C),
    container_storage:remove_container("delete_me"),
    Found = container_storage:container_by_id("delete_me"),
    ?assert([] =:= Found).
    
    
    
    
    
    
    
