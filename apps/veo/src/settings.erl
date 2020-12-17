%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2020, nisbus
%%% @doc
%%% Wrapper for the settings file.
%%% Gets the service specified in the settings file and the nodes.
%%% This is useful for pre-assigning services and node roles via a file.
%%%
%%% @end
%%% Created :  19 Jun 2020 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(settings).
-export([get_nodes/0, get_nodes/1, get_applications/0, get_applications/1, get_application/2, get_roles/1, parse_service/1]).
-include("../include/container.hrl").

%%--------------------------------------------------------------------
%% @doc
%% Gets the nodes from the default file (cluster.yml)
%% @end
%%--------------------------------------------------------------------
-spec get_nodes() -> [{atom(), string()}].
get_nodes() ->
    get_nodes(default_file()).

%%--------------------------------------------------------------------
%% @doc
%% Gets the nodes from the file specified
%% @end
%%--------------------------------------------------------------------
-spec get_nodes(File::string()) -> [{atom(), string()}].
get_nodes(File) ->
    [Parsed] = yamerl_constr:file(File),
    io:format(user, "Parsed ~p~n", [Parsed]),
    Nodes = proplists:get_value("nodes", Parsed),
    lists:foldl(fun([{_, Node}, {_, Role}], Acc) ->
			[{list_to_atom(Node), Role} | Acc]
		end,[], Nodes).
	
%%--------------------------------------------------------------------
%% @doc
%% Gets the role for a specific node.
%% @end
%%--------------------------------------------------------------------
-spec get_roles(atom()) -> undefined | binary().			 
get_roles(Node) ->
    Nodes = get_nodes(),
    Role = lists:filter(fun({N, _R}) ->
				Node =:= N
			end, Nodes),
    case Role of
	[] -> undefined;
	[H|_] -> H;
	R -> R
    end.
	    

%%--------------------------------------------------------------------
%% @doc
%% Gets the all the applications from the default file (cluster.yml).
%% @end
%%--------------------------------------------------------------------
-spec get_applications() -> [#service{}].			 
get_applications() ->
    get_applications(default_file()).

%%--------------------------------------------------------------------
%% @doc
%% Gets the all the applications from the specified file.
%% @end
%%--------------------------------------------------------------------
-spec get_applications(string()) -> [#service{}].
get_applications(File) ->
    [Parsed] = yamerl_constr:file(File),
    Services = proplists:get_value("services", Parsed),
    lists:foldl(fun(Service, Acc) ->
			[parse_service(Service) | Acc]
		end, [], Services).

%%--------------------------------------------------------------------
%% @doc
%% Gets a specific applications from the specified file.
%% @end
%%--------------------------------------------------------------------
-spec get_application(string(), _) -> [#service{} | {_,_,_,_,_,_,_}].
get_application(File, Name) ->
    Applications = get_applications(File),
    lists:filter(fun(#service{name=ServiceName}) ->
			 ServiceName =:= Name
		 end, Applications).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Parses a service from YAML to #service record
%% @end
%%--------------------------------------------------------------------
parse_service(Service) ->
    {Name, Settings} = Service,
    Image = proplists:get_value("image", Settings, undefined),
    Restart = parse_restart(proplists:get_value("restart", Settings, never)),
    RestartCount = proplists:get_value("restart_count", Settings, 0),
    NetworkMode = proplists:get_value("network_mode", Settings, undefined),
    PidMode = proplists:get_value("pid_mode", Settings, undefined),
    Privileged = proplists:get_value("privileged", Settings, false),
    Command = proplists:get_value("command", Settings, undefined),
    EntryPoint = proplists:get_value("entrypoint", Settings, undefined),
    CPU = proplists:get_value("cpus", Settings, 0),
    Disk = proplists:get_value("disk", Settings, 0),
    Memory = proplists:get_value("memory", Settings, 0),
    Roles = proplists:get_value("roles", Settings, []),
    Hosts = proplists:get_value("hosts", Settings, []),
    Labels = proplists:get_value("labels", Settings, []),
    Env = proplists:get_value("environment", Settings, []),
    Vols = proplists:get_value("volumes", Settings, []),
    Group = proplists:get_value("group", Settings, undefined),
    GroupRole = proplists:get_value("group_role", Settings, undefined),
    GroupPolicy = proplists:get_value("group_policy", Settings, undefined),
    Ports = parse_ports(proplists:get_value("ports", Settings, #{})),
    AutoRemove= proplists:get_value("auto_remove", Settings, false),
    HealthCheck = parse_health_check(proplists:get_value("health_check", Settings, undefined)),
    Instances = parse_instances(proplists:get_value("instances", Settings, 1)),
    ULimits = parse_ulimits(proplists:get_value("ulimits", Settings, undefined)),
    Dns = proplists:get_value("dns", Settings, undefined),
    S = #service{
	   name=Name,
	   image=Image,
	   restart=Restart,
	   restart_count=RestartCount,
	   privileged=Privileged,
	   network_mode=NetworkMode,
	   pid_mode=PidMode,
	   roles=Roles,
	   hosts=Hosts,
	   cpus=CPU,
	   memory=Memory,
	   disk=Disk,
	   labels=Labels,
	   environment=Env,
	   volumes=Vols,
	   ports=Ports,
	   auto_remove=AutoRemove,
	   group=Group,
	   group_policy=GroupPolicy,
	   group_role=GroupRole,
	   healthcheck=HealthCheck,
	   instances=Instances,
	   ulimits=ULimits,
	   dns=Dns,
	   command=Command,
	   entrypoint=EntryPoint},
    T = is_record(S, service),
    io:format(user, "Parsed to service record ~p~n",[T]),
    S.
    
    
parse_instances("all") ->
    all;
parse_instances(Int) when is_integer(Int) ->
    Int;
parse_instances(Int) when is_list(Int) ->
    list_to_integer(Int).

parse_restart("on-failure") ->
    restart;
parse_restart("never") ->
    never;
parse_restart("restart") ->
    restart;
parse_restart(_) ->
    never.

parse_health_check(undefined) ->
    undefined;
parse_health_check(HealthCheck) ->
    Cmd = proplists:get_value("cmd", HealthCheck, []),
    Interval = proplists:get_value("interval", HealthCheck, 0),
    StartPeriod = proplists:get_value("start_period", HealthCheck, 0),
    Timeout = proplists:get_value("timeout", HealthCheck, 0),
    Retries = proplists:get_value("retries", HealthCheck, 0),
    Shell = proplists:get_value("shell", HealthCheck, false),
    #healthcheck{
       cmd=Cmd, 
       interval=Interval,
       start_period=StartPeriod,
       timeout=Timeout,
       retries=Retries,
       shell=Shell
      }.
    
parse_ulimits(undefined) ->
    undefined;
parse_ulimits(ULimits) when is_list(ULimits) ->
    lists:map(fun({Name, [{"soft", Soft}, {"hard", Hard}]}) ->
		      #ulimits{name=Name, soft=Soft, hard=Hard}
	      end, ULimits).
   
-spec parse_ports(#{} | binary()) -> #{} | [#port{}].
parse_ports(#{}) ->
    #{};
parse_ports(Ports) ->
    lists:foldl(fun(Elem, Acc) ->
			[{Item, PortList}] = Elem,
			PortProps = lists:flatten(PortList),
			Proto = get_protocol(proplists:get_value("protocol", PortProps, undefined)),
			HostPort = proplists:get_value("host_port", PortProps),
			Name = proplists:get_value("name", PortProps, Item),
			ContainerPort = case is_list(proplists:get_value("container_port", PortProps)) of
					    true ->
						list_to_integer(proplists:get_value("container_port", PortProps));
					    false ->
						proplists:get_value("container_port", PortProps)
					end,
			{Port, IsZero} = case HostPort of
					     "0" ->
						 {ok, Listen} = gen_tcp:listen(0, []),
						 {ok, P} = inet:port(Listen),
						 gen_tcp:close(Listen),
						 {P, true};
					     _ ->
						 case is_list(HostPort) of 
						     true ->
							 {list_to_integer(HostPort), false};
						     false ->
							 {HostPort, false}
						 end
					 end,
			lists:append(Acc, [#port{
					      host_port = Port,
					      container_port = ContainerPort,
					      protocol = Proto,
					      random = IsZero,
					      name = Name
					    }]
				    )			
		end,
		[], Ports).

get_protocol(undefined) ->
    tcp;
get_protocol([_|[]]) ->
    tcp;
get_protocol([_|Proto]) ->
    case Proto of
	<<"udp">> -> udp;
	_ -> tcp
    end.


default_file() ->
    Dir = code:priv_dir(veo),
    Dir++"/veo.yml".
