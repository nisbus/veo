%%%-------------------------------------------------------------------
%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2019, nisbus
%%% @doc
%%% Parser methods for converting records to docker json and vice versa.
%%% 
%%% @end
%%% Created :  6 Dec 2019 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(container_builder).

-include("../include/container.hrl").
-export([build/1]).
-export([get_config/1]).
-export([parse_inspect/2, set_container_properties_from_inspect/2]).

%%-------------------------------------------------------------------
%% @doc
%% Builds the json to send to the docker API from a service record.
%% @end
%%-------------------------------------------------------------------
-spec(build(Service::#service{}) -> binary()). 
build(#service{
	 environment=Environment,	 
	 image=Image,
	 volumes=Volumes,
	 memory=Memory,
	 pid_mode=Pid,	 
	 network_mode=Network,
	 cpus=Cpu,
	 privileged=Privileged,
	 auto_remove=AutoRemove,
	 labels=Labels,
	 ports=Ports,
	 healthcheck=HealthCheck,
	 ulimits=ULimits,
	 dns=Dns,
	 command=Command,
	 entrypoint=Entrypoint,
	 task=Task,
	 name=Name
	}) ->
    B = [{<<"Image">>, list_to_binary(Image)},
	  {<<"AttachStdout">>, false},
	  {<<"AttachStderr">>, false}
	 ],
    BE = case Entrypoint of 
	     undefined -> B;
	     _ -> 
		 lists:append(B, [{<<"Entrypoint">>, default_entrypoint(Entrypoint)}])
	 end,
    B0 = case ULimits of
	     undefined ->
		 BE;
	     _ ->
		 lists:append(BE, parse_ulimits(ULimits))
	 end,
    BDns = case Dns of 
	       undefined ->
		   B0;
	       _ -> lists:append(B0, [{<<"Dns">>, lists:map(fun(D) -> list_to_binary(D) end, Dns)}])
	   end,
    B1 = case default_command(Command) of
	     undefined ->
		 BDns;
	     Cmd ->
		 lists:append(BDns, [{<<"Cmd">>, Cmd}])
	 end,
    B2 = case HealthCheck of 
	     undefined -> B1;
	     #healthcheck{cmd=HealthCmd, start_period=Start, interval=Interval, timeout=Timeout, retries=Retries, shell=Shell} ->
		 Health = [{<<"Healthcheck">>,
			    [{<<"Test">>, get_test_command(HealthCmd, Shell)},
			     {<<"Interval">>, Interval},
			     {<<"Timeout">>, Timeout},
			     {<<"Retries">>, Retries},
			     {<<"StartPeriod">>, Start}
			    ]
			   }
			  ],
		 lists:append(B1, Health)
	 end,

    DefaultPorts = default_ports(Ports),
    Env = case Environment of
	      [] ->
		  [list_to_binary("MESOS_CONTAINER_NAME="++Name)];
	      _ ->
		  lists:append(Environment, [list_to_binary("MESOS_CONTAINER_NAME="++Name)])
	  end,
		      
    EnvWithPorts = case DefaultPorts of
		       #{} -> Env;
		       [] -> Env;
		       PortList ->
			   {Count, PortEnvs} = lists:foldl(fun(#port{container_port = Container,
								     host_port=_Host, name=Name}, Acc) ->
								   {C,A} = Acc,
								   io:format("Port name ~p~n", [Name]),
								   NewEnv = case Name of
										<<"ready_port">> ->
										    lists:append(A, ["PORT_READYPORT"++"="++integer_to_list(Container)]);
										_ ->
										    lists:append(A, ["PORT"++integer_to_list(C)++"="++integer_to_list(Container)])
									    end,
								   {C+1, NewEnv}								   
							   end, {0, []}, PortList),
			   case Count of 
			       0 ->
				   Env;
			       _ ->
				   case Env of 
				       undefined -> Env;
				       _ -> 
					   lists:append(Env, PortEnvs)
				   end
			   end
    end,

    BaseConfig = case default_env(EnvWithPorts) of
    		     undefined ->
    			 B2;
    		     E ->
    			 lists:append(B2, [{<<"Env">>, E}])
    		 end,
    
    H0 = [
	  {<<"Memory">>, get_memory_from_service(Memory)},
	  {<<"NetworkMode">>, default_network(Network)},				      
	  {<<"CpuShares">>, default_cpu(Cpu)},
	  {<<"CpuQuota">>, default_cpu_quota(Cpu)},
	  {<<"AutoRemove">>, default_autoremove(AutoRemove)},
	  {<<"Privileged">>, default_privileged(Privileged)}
	 ],
    H1 = case default_volumes(Volumes) of
    	     undefined ->
    		 H0;
    	     V ->
    		 lists:append(H0,[{<<"Mounts">>, V}])
    end,
		 
    Host = case default_pid(Pid) of
    	       undefined ->
    		   H1;
    	       P ->		   
    		   [{<<"PidMode">>, P}| H1]
    	   end,
    LabelConfig = case default_labels(Labels) of 
    		      undefined ->
    			  BaseConfig;
    		      L -> 
    			  lists:append(BaseConfig, [{<<"Labels">>, L}])
    		  end,
    Config = case DefaultPorts of
    		 #{} ->
    		     lists:append(LabelConfig,[{<<"HostConfig">>, Host}]);
    		 Po ->
    		     PortMapping = lists:map(fun(#port{container_port=Container, protocol=Proto, host_port=HostPort}) ->
						     PortAndProto = case Proto of 
									undefined ->
									    list_to_binary(integer_to_list(Container));
									_ -> 
									    list_to_binary(integer_to_list(Container)++"/"++atom_to_list(Proto))
								    end,
						     {PortAndProto, [[{<<"HostPort">>, HostPort}]]}
    					     end, Po),		 
    		     WithPorts = lists:append(Host, [{<<"PortBindings">>, PortMapping}]),
    		     lists:append(LabelConfig, [{<<"HostConfig">>, WithPorts}])
    	     end,
    case Task of
	undefined ->
	    io:format("Encoding ~p~n", [Config]),
	    JSON = jsx:encode(Config),
	    JSON;
	_->	    
	    ConfigWithTask = lists:append(Config, Task),
	    io:format("Encoding ~p~n", [ConfigWithTask]),
	    jsx:encode(ConfigWithTask)
    end.

%%-------------------------------------------------------------------
%% @doc
%% Fills in the container properties from an inspect result
%% @end
%%-------------------------------------------------------------------
-spec(set_container_properties_from_inspect(Inspect::any(), Service::#service{}) -> #container{}).
set_container_properties_from_inspect(Inspect, Service) ->
    Config = proplists:get_value('Config', Inspect, undefined),
    HostName = proplists:get_value(<<"Hostname">>, Config, undefined),
    State =  proplists:get_value('State', Inspect, undefined),
    Status = proplists:get_value(<<"Status">>, State, undefined),
    #container{service=Service, status=Status, hostname=HostName}.
%%-------------------------------------------------------------------
%% @doc
%% Parses the settings reported by the docker daemon into a service record.
%% @end
%%-------------------------------------------------------------------
-spec(parse_inspect(Inspect::any(), Service::#service{}) -> #service{}).
parse_inspect(Inspect, #service{ports=ServicePorts}) ->
    Config = proplists:get_value('Config', Inspect, undefined),
    HostConfig = proplists:get_value('HostConfig', Inspect, undefined),
    Volumes = proplists:get_value(<<"Binds">>, HostConfig, []),
    Image = proplists:get_value(<<"Image">>, Config, undefined),
    Labels = proplists:get_value(<<"Labels">>, Config, undefined),
    NetworkMode = proplists:get_value(<<"NetworkMode">>, HostConfig, undefined),
    Ports = parse_ports(proplists:get_value(<<"PortBindings">>, HostConfig, []), ServicePorts),
    PidMode = proplists:get_value(<<"PidMode">>, HostConfig, undefined),
    Privileged = proplists:get_value(<<"Privileged">>, HostConfig, false),
    TaskID = proplists:get_value(<<"MESOS_TASK_ID">>, Labels, undefined),
    InspectName = proplists:get_value('Name', Inspect, undefined),
    Env = proplists:get_value(<<"Env">>, Config, []),
    Cmd = proplists:get_value(<<"Cmd">>, Config, proplists:get_value('Args', Inspect, "")),
    Memory = parse_memory_from_inspect(proplists:get_value(<<"Memory">>, HostConfig, 0)),
    CPU = parse_cpu_from_inspect(proplists:get_value(<<"CpuShares">>, HostConfig, 0)),
    Disk = proplists:get_value(<<"DiskQuota">>, HostConfig, 0),
    ULimits = parse_ulimits_from_inspect(proplists:get_value(<<"ULimits">>, HostConfig, undefined)),
    Dns = proplists:get_value(<<"Dns">>, HostConfig, undefined),
    Entrypoint = proplists:get_value(<<"Entrypoint">>, Config, undefined),
    Name = case TaskID of 
	       undefined ->
		   InspectName;
	       _ ->
		   TaskID
	   end,
    RestartPolicy = proplists:get_value(<<"RestartPolicy">>, HostConfig, undefined),
    Count = proplists:get_value(<<"MaximumRetryCount">>, RestartPolicy, 0),
    ContainerStrategy = proplists:get_value(<<"Name">>, RestartPolicy, restart),
    Strategy = case ContainerStrategy of
		   <<"on-failure">> -> restart;
		   <<"">> -> never;
		   <<"no">> -> never;
		   <<"always">> -> restart;
		   <<"unless_stopped">> -> restart;
		   _ -> restart
	       end,
    #service{
       name=Name,
       image=Image,
       restart=Strategy,
       restart_count=Count,
       labels=Labels,
       volumes=Volumes,
       ports=Ports,
       privileged=Privileged,
       network_mode=NetworkMode,
       pid_mode=PidMode,
       environment=Env,
       cpus=CPU,
       memory=Memory,
       disk=Disk,
       ulimits=ULimits,
       dns=Dns,
       command=Cmd,
       entrypoint=Entrypoint
      }.

%%-------------------------------------------------------------------
%% @doc
%% Gets the service record for a running container by calling docker 
%% daemon inspect
%% @end
%%-------------------------------------------------------------------
-spec(get_config(CID::binary()) -> #service{}).
get_config(CID) ->
    {ok, Inspect} = docker_container:container(CID),
    io:format("Got config ~p~n", [Inspect]),
    InspectName = proplists:get_value('Name', Inspect, undefined),
    Container = settings:get_application(InspectName),
    Return = case Container of 
		 [] ->
		     parse_inspect(Inspect, #service{});
		 _ -> parse_inspect(Inspect, Container)
	     end,
    Return.

%%%===================================================================
%%% Internal functions
%%%===================================================================
parse_memory_from_inspect(0) ->
    0;
parse_memory_from_inspect(Memory) ->
    Memory/1024/1024/1024.

parse_cpu_from_inspect(0) ->
    0;
parse_cpu_from_inspect(Cpu) ->
    Cpu/1024.

parse_ulimits(undefined) ->
    undefined;
parse_ulimits(ULimits) ->
    Mapped = lists:map(fun(#ulimits{name=Name, soft=Soft, hard=Hard}) ->
			       [{<<"Name">>,list_to_binary(Name)}, {<<"Soft">>,Soft}, {<<"Hard">>,Hard}]
		       end, ULimits),
    [{<<"Ulimits">>, Mapped}].

parse_ulimits_from_inspect(undefined) ->
    undefined;
parse_ulimits_from_inspect(ULimits) ->
    lists:map(fun(Limit) ->
		      #ulimits{name = proplists:get_value("Name", Limit),
			       soft = proplists:get_value("Soft", Limit),
			       hard = proplists:get_value("Hard", Limit)
			       }
		      end, ULimits).
		      
get_memory_from_service(undefined) ->
    0;
get_memory_from_service(Memory) when is_float(Memory) ->
    get_memory_from_service(float_to_list(Memory, [{decimals,0}]));
get_memory_from_service(Memory) when is_list(Memory) ->
    get_memory_from_service(list_to_integer(Memory));
get_memory_from_service(Memory) when is_integer(Memory) ->    
    Memory*1024*1024*1024.

get_test_command(undefined, _) ->
    [];
get_test_command(Cmd, Flag) when is_list(Cmd) ->
    get_test_command(list_to_binary(Cmd), Flag);
get_test_command(Cmd, true) ->
    [<<"CMD-SHELL">>, Cmd];
get_test_command(Cmd, false) ->
    [<<"CMD">>, Cmd].

default_entrypoint(E) ->
    io:format("E ~p~n", [E]),
    Entrypoint = case io_lib:latin1_char_list(E) of
		     true ->
			 [list_to_binary(E)];
		     false ->
			 lists:map(fun(En) ->
					   list_to_binary(En)
				   end, E)
		 end,
    Entrypoint.

default_command([]) ->
    undefined;
default_command(undefined) ->
    undefined;
default_command(Cmd) ->
    CommandList = case io_lib:latin1_char_list(Cmd) of
		      true ->
			  Split = re:split(Cmd, " ", [{return, list}]),
			  lists:map(fun(E) ->
					    list_to_binary(E)
				    end,Split);
		      false ->	    
			  lists:foldl(fun(Part, Acc) ->
					      C = case is_binary(Part) of
						      true ->
							  binary_to_list(Part);
						      false ->
							  Part
						  end,				
					      case lists:member("=", C) of
						  true ->
						      Split = re:split(C, "=", [{return, list}]),
						      Converted = lists:map(fun(E) ->
										    list_to_binary(E)
							      end, Split),
						      lists:append(Acc, Converted);
						  false ->
						      lists:append(Acc, [list_to_binary(C)])
					      end
				      end, [], Cmd)
		  end,
    CommandList.

%% default_memory(undefined) ->
%%     0.0;
%% default_memory(Memory) ->
%%     Memory.

default_pid(undefined) ->
    undefined;
default_pid(_) ->
    <<"host">>.

default_network(undefined) ->
    <<"default">>;
default_network(<<"default">>) ->
    <<"default">>;
default_network(<<"bridge">>) ->
    <<"bridge">>;
default_network(_) ->
    <<"host">>.

default_cpu(undefined) ->
    0;
default_cpu(Cpu) when is_float(Cpu) ->
    default_cpu(float_to_list(Cpu, [{decimals,0}]));
default_cpu(Cpu) when is_list(Cpu) ->
    default_cpu(list_to_integer(Cpu));
default_cpu(Cpu) when is_integer(Cpu) ->			 
    Cpu*1024.

default_cpu_quota(undefined) ->
    0;
default_cpu_quota(Cpu) when is_float(Cpu) ->
    default_cpu_quota(float_to_list(Cpu, [{decimals,0}]));
default_cpu_quota(Cpu) when is_list(Cpu) ->
    default_cpu_quota(list_to_integer(Cpu));
default_cpu_quota(Cpu) when is_integer(Cpu) ->			 
    Cpu*100000.

default_ports(#{}) ->
    #{};
default_ports([]) ->
    #{};
default_ports(undefined) ->
    #{};
default_ports(Ports) ->
    Mappings = lists:foldl(fun(#port{container_port=ContainerPortSpecified, protocol=Proto, host_port=Host, name=Name}, Acc) ->
				   {Port, IsZero} = case Host of
							0 ->
							    {ok, Listen} = gen_tcp:listen(0, []),
							    {ok, P} = inet:port(Listen),
							    gen_tcp:close(Listen),
							    {list_to_binary(integer_to_list(P)), true};
							_ ->
							    {list_to_binary(integer_to_list(Host)), false}
						    end,
				   Container = case ContainerPortSpecified of 
						   0 ->						  
						       list_to_integer(binary_to_list(Port));
						   _ -> ContainerPortSpecified
					       end,
				   Format = [#port{container_port=Container, 
						   protocol=Proto,
						   host_port=Port,
						   random=IsZero,
						   name=Name}],
				   lists:append(Acc, Format)
			   end,
			   [], Ports),
    Mappings.

default_autoremove(undefined) ->
    false;
default_autoremove(false) ->
    false;
default_autoremove(_) ->
    true.

default_privileged(undefined) ->
    false;
default_privileged(false) ->
    false;
default_privileged(_) ->
    true.


default_volumes([]) ->
    undefined;
default_volumes(undefined) ->
    undefined;
default_volumes(Vol) ->
    lists:foldl(fun(Elem, Acc) ->
			Split = re:split(Elem, ":", [{return,list}]),
			[Container, Host, Opts] = case Split of
						      [C, H] ->
							  [C, H, <<"rprivate">>];
						      [C, H, Opt] ->
							  [C, H, default_bind_opts(Opt)]
						  end,
			[[
			  {<<"Target">>, list_to_binary(Container)},
			  {<<"Source">>, list_to_binary(Host)},
			  {<<"Type">>, <<"bind">>},
			  {<<"Mode">>, default_bind_mode(Opts)},
			  {<<"RW">>, is_rw(default_bind_mode(Opts))},
			  {<<"BindOptions">>, [{<<"Propagation">>, default_bind_opts(Opts)}]}
			] | Acc]
		end,
		[], Vol).

default_bind_mode(undefined) ->
    <<"rw">>;
default_bind_mode(<<"rw">>) ->
    <<"rw">>;
default_bind_mode(<<"ro">>) ->
    <<"ro">>;
default_bind_mode(<<"rshared">>) ->
    <<"rshared">>;
default_bind_mode(Other) when is_list(Other) ->
    list_to_binary(Other);
default_bind_mode(Other) when is_binary(Other) ->
    Other.


is_rw(<<"rw">>) ->
    true;
is_rw(<<"">>) ->
    true;
is_rw(_) ->
    false.

default_bind_opts(undefined) ->
    <<"rprivate">>;
default_bind_opts([]) ->
    <<"rprivate">>;
default_bind_opts(Opt) when is_list(Opt) ->
    list_to_binary(Opt);
default_bind_opts(<<"rshared">>)->
    <<"rshared">>;
default_bind_opts(_)->
    <<"rprivate">>.

default_env([]) ->
    undefined;
default_env(undefined) ->
    undefined;
default_env(Env) ->
    lists:foldl(fun(Elem, Acc) ->
			case is_list(Elem) of
			    true ->
				[list_to_binary(Elem)|Acc];
			    false -> [Elem|Acc]
			end
		end, [], Env).

default_labels([]) ->
    undefined;
default_labels(undefined) ->
    undefined;
default_labels(Labels) ->
    lists:foldl(fun(Elem, Acc) ->
			[Name, Value] = re:split(Elem, "=", [{return,list}]),
			[{
			 list_to_binary(Name), list_to_binary(Value)
			} | Acc]
		end,
		[], Labels).

parse_ports([{}], []) ->
    [];
parse_ports(null, _) ->
    [];
parse_ports(Ports, []) ->
    lists:foldl(fun(Port, Acc) ->
			{ContainerAndProto, [[_,{_,HostPort}]]} = Port,
			Split = binary:split(ContainerAndProto, <<"/">>),
			BasePort = case Split of
				       [CPort, Proto] ->
					   #port{container_port=binary_to_integer(CPort), protocol=get_protocol(Proto), host_port=binary_to_integer(HostPort)};
				       [CPort|[]] ->
					   #port{container_port=binary_to_integer(CPort), protocol=tcp, host_port=binary_to_integer(HostPort)}
				   end,
			Acc++[BasePort]
		end, [], Ports);
    
parse_ports(Ports, ServicePorts) ->
    lists:foldl(fun(Port, Acc) ->
			{ContainerAndProto, [[_,{_,HostPort}]]} = Port,
			Split = binary:split(ContainerAndProto, <<"/">>),
			BasePort = case Split of
				       [CPort, Proto] ->
					   #port{container_port=binary_to_integer(CPort), protocol=get_protocol(Proto), host_port=binary_to_integer(HostPort)};
				       [CPort|[]] ->
					   #port{container_port=binary_to_integer(CPort), protocol=tcp, host_port=binary_to_integer(HostPort)}
				   end,
			#port{container_port=BaseContainer} = BasePort,
			[H|_] = lists:filter(fun(#port{container_port=ContainerPort}) ->
					     ContainerPort == BaseContainer
				     end, ServicePorts),
			Result = BasePort#port{name=H#port.name, random=H#port.random},
			Acc++[Result]
		end, [], Ports).

get_protocol(<<"udp">>) ->
    udp;
get_protocol(_) ->
    tcp.
