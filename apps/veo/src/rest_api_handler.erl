%% @hidden
%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2020, nisbus
%%% @doc
%%% Handler for the REST API
%%%
%%% @end
%%% Created :  19 Jun 2020 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------

-module(rest_api_handler).
-behaviour(cowboy_rest).
-export([init/2,
	allowed_methods/2,
	content_types_accepted/2,
	content_types_provided/2,
	resource_exists/2,
	handle_request/2]).

-export([container_to_parse/1]).
-record(state, {op }).
-include("../include/node.hrl").
-include("../include/container.hrl").

init(Req, Opts) ->
    [Op | _] = Opts,
    lager:debug("Init REST ~p, Req ~p", [Op, Req]),
    State = #state{op=Op},
    {cowboy_rest, Req, State}.

content_types_accepted(Req, State) ->
    {[{<<"application/json">>, handle_request}], Req, State}.

content_types_provided(Req, State) ->
    {[{<<"application/json">>, handle_request}], Req, State}.    

allowed_methods(Req, State) ->
    {[<<"GET">>, <<"OPTIONS">>, <<"POST">>, <<"DELETE">>], Req, State}.

resource_exists(Req, State) ->
    {true, Req, State}.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                       API implementation                         %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
handle_request(Req, #state{op=Op} = State) ->
    lager:debug("Handling request ~p, ~p",[Op, Req]),
    Rq = 
	case Op of
	    containers ->
		containers(Req);
	    nodes ->
		node_info(Req);
	    container ->
	        container(Req)
	end,
    {ok, Rq, State}.

node_info(Req) ->
    Node = cowboy_req:binding(node, Req, undefined),
    case Node of 
	undefined -> %% Return all nodes
	    {AllResources,_} = rpc:multicall(node_monitor, get_resources, []),
	    lager:debug("Got all nodes ~p", [AllResources]),
	    Nodes = lists:map(fun(N) ->
				      node_to_parse(N)
			      end, AllResources),
	    cowboy_req:reply(200, 
			     #{<<"content-type">> => <<"application/json">>}, 
			     to_json(Nodes), 
			     Req);
	_ -> %% Only requested node
	    NodeName = list_to_atom(binary_to_list(Node)),
	    Result = rpc:call(NodeName, node_monitor, get_resources,[]),
	    cowboy_req:reply(200, 
			     #{<<"content-type">> => <<"application/json">>}, 
			     to_json(node_to_parse(Result)), 
			     Req)
    end.

containers(Req) ->
    Node = cowboy_req:binding(node, Req, undefined),
    case Node of
	undefined -> %% All containers
	    {AllContainers,_} = rpc:multicall([node()]++nodes(), container_sup, list_containers, []),
	    lager:debug("All containers ~p", [AllContainers]),
	    Result = lists:foldl(fun(C0, Acc) ->
					 Acc ++ lists:map(fun(C) ->
								  lager:debug("Parsing Container ~p", [C]),
								  container_to_parse(C)
							  end, C0)
				 end, [], AllContainers),
	    cowboy_req:reply(200,
			 #{<<"content-type">> => <<"application/json">>}, 
			 to_json(Result), 
			 Req);
	_ ->
	    NodeName = list_to_atom(binary_to_list(Node)),
	    NodeContainers = rpc:call(NodeName, container_sup, list_containers,[]),
	    Containers = case NodeContainers of
			     [] -> [];
			     _ -> lists:map(fun(C) ->
						    container_to_parse(C)
					    end, NodeContainers)
			 end,
	    lager:debug("Got containers for node ~p", [Containers]),
	    cowboy_req:reply(200,
			 #{<<"content-type">> => <<"application/json">>}, 
			 to_json(Containers), 
			 Req)
    end.

container(Req) ->
    Container = cowboy_req:binding(container, Req, undefined),
%   Node = get_container_node(Container),
    case cowboy_req:method(Req) of
	<<"GET">> ->
	    case Container of
		undefined ->
		    cowboy_req:reply(404, #{<<"content-type">> => <<"application/json">>},
				     <<"No container specified for GET request">>,
				     Req);
		_ ->
		    {AllContainers,_} = rpc:multicall([node()]++nodes(), container_sup, list_containers, []),
		    Result = lists:foldl(fun(C0, Acc) ->
						 Acc ++ lists:map(fun(C) ->
									  C
								  end, C0)
					 end, [], AllContainers),		  
		    Found = lists:filter(fun(#container{service=#service{name=Name}}) ->
					 Name == Container
				 end, Result),
		    X = lists:map(fun(C) ->
					  container_to_parse(C)
				  end, Found),
		    cowboy_req:reply(200,
				     #{<<"content-type">> => <<"application/json">>}, 
				     to_json(X), 
				     Req)
	    end;
	<<"DELETE">> -> %% Stop/kill a container	
	    cowboy_req:reply(501, #{<<"content-type">> => <<"application/json">>}, Req);
	<<"POST">> ->  %% Create/start a container
	    {ok, Body, Req0} = cowboy_req:read_body(Req),
	    Service = json_to_service(Body),
	    case container_sup:add_service(Service) of
		{error, {Code, Error}} ->					      
		    cowboy_req:reply(Code, #{<<"content-type">> => <<"application/json">>}, 
				     error_to_binary(Error), Req0);
		{error, Error} ->
		    cowboy_req:reply(500, #{<<"content-type">> => <<"application/json">>}, 
				     error_to_binary(Error), Req0);
		_ ->
		    cowboy_req:reply(200, #{<<"content-type">> => <<"application/json">>}, 
					    <<"success">>, Req0)		    
	    end
    end.

error_to_binary(Error) when is_binary(Error) ->
    Error;
error_to_binary(Error) when is_list(Error) ->
    error_to_binary(list_to_binary(Error));
error_to_binary(Error) when is_atom(Error) ->
    error_to_binary(atom_to_list(Error)).
%% get_container_node(Container) ->
%%     AllContainers = rpc:multicall([node()]++nodes(), container_sup, list_containers, []),
%%     lists:filter(fun(C) ->
%% 			 proplists:get_value(<<"id">>, C, undefined) == Container
%% 		 end, AllContainers).
    
			      
to_json(Result) ->
    lager:debug("Encoding result ~p", [Result]),
    JSON = jsx:encode(Result),
    JSON.					 

node_to_parse(#node_state{node=Node, role=Role, 
			  memory= #memory{
				     used = UsedMem,
				     available= AvailMem,
				     total = TotalMem
				    },
			 cpu = #cpu{
				  count = Cpus,
				  used=UsedCpu,
				  available=AvailCpu
				 },
			 disk= #disk{
				 used=UsedDisk,
				 available=AvailDisk,
				 total=TotalDisk}}) ->
    {N0, R0} = case Role of
		   {N, R} -> {list_to_binary(atom_to_list(N)), list_to_binary(R)};
		   _ -> 
		       {list_to_binary(atom_to_list(Node)), list_to_binary(Role)}
	       end,
    [
     {<<"node">>, N0},
     {<<"role">>, R0},
     {<<"total_memory">>, TotalMem},
     {<<"used_memory">>, UsedMem},
     {<<"available_memory">>, AvailMem},
     {<<"cpus">>, Cpus},
     {<<"used_cpus">>, UsedCpu},
     {<<"available_cpus">>, AvailCpu},
     {<<"total_disk">>, TotalDisk},
     {<<"used_disk">>, UsedDisk},
     {<<"available_disk">>, AvailDisk}
    ].

container_to_parse(#container{
		     restart_counter=Restarts,
		     status=Status,
		     ip_address=IP,
		     service=#service{
				id=ID,
				name=Name,
				restart=Restart,
				privileged=Priv,
				network_mode=Network,
				pid_mode=Pid,
				roles=Roles,
				hosts=Hosts,
				cpus=Cpu,
				memory=Mem,
				disk=Disk,
				labels=Labels,
				environment=Env,
				volumes=Vols,
				ports=Ports,
				args=Args,
				auto_remove=AutoR,
				group=Group,
				group_role=GroupRole,
				group_policy=Policy,
				healthcheck=HealthCheck
			       }}) ->
    [
     {<<"name">>, possibly_list(Name)},
     {<<"id">>, ID},
     {<<"restart_count">>, Restarts},
     {<<"status">>, Status},
     {<<"ip_address">>, IP},
     {<<"restart_policy">>, possibly_atom(Restart)},
     {<<"privileged">>, Priv},
     {<<"network_mode">>, possibly_list(Network)},
     {<<"pid_mode">>, possibly_list(Pid)},
     {<<"roles">>, lists:map(fun(R) -> possibly_list(R) end, Roles)},
     {<<"hosts">>, lists:map(fun(H) -> possibly_list(H) end, Hosts)},
     {<<"cpus">>, Cpu},
     {<<"memory">>, Mem},
     {<<"disk">>, Disk},
     {<<"labels">>, lists:map(fun(L) -> possibly_list(L) end, Labels)},
     {<<"environment">>, lists:map(fun(E) -> possibly_list(E) end, Env)},
     {<<"volumes">>, Vols},
     {<<"ports">>, lists:map(fun(P) -> port_to_json(P) end, Ports)},
     {<<"args">>, Args},
     {<<"auto_remove">>, AutoR},
     {<<"group">>, possibly_list(Group)},
     {<<"group_role">>, GroupRole},
     {<<"group_policy">>, Policy},
     {<<"healthcheck">>, healthcheck_to_json(HealthCheck)}
    ];
container_to_parse(CatchAll) ->
    io:format(user, "No match ~p~n",[CatchAll]).


port_to_json(#port{container_port=Container,
		  host_port=Host,
		  protocol=Protocol,
		  random=Random}) ->
    [{<<"container_port">>, Container},
     {<<"host_port">>, Host},
     {<<"protocol">>, Protocol},
     {<<"auto_assigned">>, Random}].

healthcheck_to_json(undefined) ->
    undefined;
healthcheck_to_json(#healthcheck{
		       cmd=Cmd,
		       start_period=Start,
		       interval=Interval,
		       timeout=Timeout,
		       retries=Retries,
		       shell=Shell
		      }) ->
    [
     {<<"cmd">>,Cmd},
     {<<"start_period">>, Start},
     {<<"interval">>, Interval},
     {<<"timeout">>, Timeout},
     {<<"retries">>, Retries},
     {<<"shell">>, Shell}
    ].


possibly_atom(undefined) ->
    undefined;
possibly_atom(Atom) ->
    atom_to_binary(Atom, utf8).

possibly_list(undefined) ->
    undefined;
possibly_list(L) when is_binary(L) ->
    L;
possibly_list(L) when is_list(L) ->
    list_to_binary(L).

json_to_service(JSON) ->
    Decode = jsx:decode(JSON),
    Name = proplists:get_value(<<"name">>, Decode, undefined),
    Image = proplists:get_value(<<"image">>, Decode, undefined),
    Restart = proplists:get_value(<<"restart">>, Decode, never),
    Priv= proplists:get_value(<<"privileged">>, Decode, false),
    Net = proplists:get_value(<<"network_mode">>, Decode, undefined),
    Pid = proplists:get_value(<<"pid_mode">>, Decode, undefined),
    Roles = proplists:get_value(<<"roles">>, Decode, []),
    Hosts = proplists:get_value(<<"hosts">>, Decode, []),
    CPU = proplists:get_value(<<"cpus">>, Decode, 0),
    Mem = proplists:get_value(<<"memory">>, Decode, 0),
    Disk = proplists:get_value(<<"disk">>, Decode, 0),
    Labels = proplists:get_value(<<"labels">>, Decode, []),
    Env = proplists:get_value(<<"environment">>, Decode, []),
    Vol = proplists:get_value(<<"volumes">>, Decode, []),
    Ports = json_to_ports(proplists:get_value(<<"ports">>, Decode, [])),
    Args = proplists:get_value(<<"args">>, Decode, []),
    Remove = proplists:get_value(<<"auto_remove">>, Decode, false),
    Group = proplists:get_value(<<"group">>, Decode, undefined),
    GroupRole = proplists:get_value(<<"group_role">>, Decode, undefined),
    GroupPolicy = proplists:get_value(<<"group_policy">>, Decode, undefined),
    Health = json_to_health_check(proplists:get_value(<<"healthcheck">>, Decode, undefined)),
    #service{
       name=Name,
       image=binary_to_list(Image),
       restart = Restart,
       privileged=Priv,
       network_mode=Net,
       pid_mode=Pid,
       roles=Roles,
       hosts=Hosts,
       cpus=CPU,
       memory=Mem,
       disk=Disk,
       labels=Labels,
       environment=Env,
       volumes=Vol,
       ports= Ports,
       args=Args,
       auto_remove=Remove,
       group=Group,
       group_role=GroupRole,
       group_policy=GroupPolicy,
       healthcheck=Health
      }.

json_to_health_check(undefined)->
    undefined;
json_to_health_check(Health) ->
    #healthcheck{
       cmd=proplists:get_value(<<"cmd">>, Health, undefined),
       start_period=proplists:get_value(<<"start_period">>, Health, 0),
       interval=proplists:get_value(<<"interval">>, Health, 0),
       timeout=proplists:get_value(<<"timeout">>, Health, 0),
       retries=proplists:get_value(<<"retries">>, Health, 0),
       shell=proplists:get_value(<<"shell">>,Health, false)
      }.

json_to_ports(undefined) ->
    [];
json_to_ports([]) ->
    [];
json_to_ports(Ports) ->
    lists:map(fun(Port) ->
		      #port{
			 container_port=proplists:get_value(<<"container_port">>, Port, undefined),
			 host_port=proplists:get_value(<<"host_port">>, Port, undefined),
			 protocol=proplists:get_value(<<"protocol">>, Port, tcp),
			 random=proplists:get_value(<<"random">>, Port, false),
			 name=proplists:get_value(<<"name">>, Port, undefined)
			}
	      end, Ports).


