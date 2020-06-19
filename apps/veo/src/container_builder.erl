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
-include("../include/service.hrl").
-export([build/1]).
-export([get_config/1]).
-export([parse_inspect/2]).

%%-------------------------------------------------------------------
%% @doc
%% Builds the json to send to the docker API from a service record.
%% @end
%%-------------------------------------------------------------------
-spec(build(Service::#service{}) -> binary()). 
build(#service{
	 environment=Env, 
	 args=Command,
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
	 healthcheck=HealthCheck
	}) ->
    B0 = [{<<"Image">>, list_to_binary(Image)},
	  {<<"AttachStdout">>, false},
	  {<<"AttachStderr">>, false}
	 ],
    B1 = case default_command(Command) of
	     undefined ->
		 B0;
	     Cmd ->
		 lists:append(B0, [{<<"Cmd">>, Cmd}])
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

    EnvWithPorts = case Ports of
		       [] -> Env;
		       PortList ->
			   {Count, PortEnvs} = lists:foldl(fun(#port{container_port = Container,
								    host_port=_Host,
								    random = IsZero}, Acc) ->
								   case IsZero of
								       false -> 
									   Acc;
								       true ->
								   	   {C,A} = Acc,
								   	   NewEnv = lists:append(A, ["PORT"++integer_to_list(C)++"="++integer_to_list(Container)]),
								   	   {C+1, NewEnv}
								   end
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
    	    {<<"Memory">>, default_memory(Memory)},
    	    {<<"NetworkMode">>, default_network(Network)},				      
    	    {<<"CpuCount">>, default_cpu(Cpu)},
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
    Config = case default_ports(Ports) of
    		 #{} ->
    		     lists:append(LabelConfig,[{<<"HostConfig">>, Host}]);
    		 Po ->
    		     PortMapping = lists:map(fun({Container, Bindings, _}) ->
    						     {Container, Bindings}
    					     end, Po),
    		     WithPorts = lists:append(Host, [{<<"PortBindings">>, PortMapping}]),
    		     lists:append(LabelConfig, [{<<"HostConfig">>, WithPorts}])
    	     end,
    io:format("Encoding ~p~n", [Config]),
    jsx:encode(Config).

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
    Memory = proplists:get_value(<<"Memory">>, HostConfig, 0),
    CPU = proplists:get_value(<<"CpuShares">>, HostConfig, 0),
    Disk = proplists:get_value(<<"DiskQuota">>, HostConfig, 0),
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
       args=Cmd,
       cpus=CPU,
       memory=Memory,
       disk=Disk
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
    InspectName = proplists:get_value('Name', Inspect, undefined),
    Container = settings:get_application(InspectName),
    parse_inspect(Inspect, Container).

%%%===================================================================
%%% Internal functions
%%%===================================================================

get_test_command(undefined, _) ->
    [];
get_test_command(Cmd, Flag) when is_list(Cmd) ->
    get_test_command(list_to_binary(Cmd), Flag);
get_test_command(Cmd, true) ->
    [<<"CMD-SHELL">>, Cmd];
get_test_command(Cmd, false) ->
    [<<"CMD">>, Cmd].

default_command([]) ->
    undefined;
default_command(undefined) ->
    undefined;
default_command(Cmd) ->
    CommandList = lists:foldl(fun(C, Acc) ->
				      Split = re:split(C, "=", [{return, list}]),
				      Converted = lists:map(fun(E) ->
								    list_to_binary(E)
							    end, Split),
				      lists:append(Acc, Converted)
			      end, [], Cmd),
    CommandList.

default_memory(undefined) ->
    0.0;
default_memory(Memory) ->
    Memory.

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
    0.0;
default_cpu(Cpu) ->
    Cpu.

default_ports(#{}) ->
    #{};
default_ports([]) ->
    #{};
default_ports(undefined) ->
    #{};
default_ports(Ports) ->
    Mappings = lists:foldl(fun(#port{container_port=Container, protocol=Proto, host_port=Host}, Acc) ->
				   {Port, IsZero} = case Host of
							0 ->
							    {ok, Listen} = gen_tcp:listen(0, []),
							    {ok, P} = inet:port(Listen),
							    gen_tcp:close(Listen),
							    {list_to_binary(integer_to_list(P)), true};
							_ ->
							    {list_to_binary(integer_to_list(Host)), false}
						    end,
				   ContainerPort = case Proto of 
						       undefined -> list_to_binary(Container);
						       _ -> list_to_binary(integer_to_list(Container)++"/"++atom_to_list(Proto))
						   end,
						    
				   Format = [{ContainerPort, [[{
								<<"HostPort">>, Port
							       }
							      ]]
					     , IsZero}],
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
							  [C, H, <<"shared">>];
						      [C, H, Opt] ->
							  [C, H, default_bind_opts(Opt)]
						  end,
			[[
			 {<<"Target">>, list_to_binary(Container)},
			 {<<"Source">>, list_to_binary(Host)},
			 {<<"Type">>, <<"bind">>},
			 {<<"BindOptions">>, [{<<"Propagation">>, default_bind_opts(Opts)}]}
			] | Acc]
		end,
		[], Vol).

default_bind_opts(undefined) ->
    <<"shared">>;
default_bind_opts([]) ->
    <<"shared">>;
default_bind_opts(Opt) when is_list(Opt) ->
    list_to_binary(Opt);
default_bind_opts(Opt) when is_binary(Opt) ->
    Opt.

default_env([]) ->
    undefined;
default_env(undefined) ->
    undefined;
default_env(Env) ->
    lists:foldl(fun(Elem, Acc) ->
			[list_to_binary(Elem)|Acc]
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

parse_ports(null, _) ->
    [];
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
