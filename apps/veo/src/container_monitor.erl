%%%-------------------------------------------------------------------
%%% @author nisbus <nisbus@nisbus@gmail.com>
%%% @copyright (C) 2019, nisbus
%%% @doc
%%% Starts and monitors a container.
%%% Set the restart strategy to manage the lifetime of the container
%%% @end
%%% Created :  5 Dec 2019 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(container_monitor).

-behaviour(gen_server).

%% API
-export([start_link/1]).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2, stop/2,
	 create/4]).

-define(SERVER, ?MODULE).
-include("../include/node.hrl").
-include("../include/container.hrl").
-include("../../../_build/default/lib/erldns/include/erldns.hrl").
%%%===================================================================
%%% API
%%%===================================================================
stop(CID, Pid) ->
    gen_server:cast(Pid, [stop, CID]).
%%--------------------------------------------------------------------
%% @doc
%% Starts the server using the provided service record.
%% @end
%%--------------------------------------------------------------------
-spec start_link(Service::#service{}|term()) -> {ok, Pid :: pid()} |
		      {error, Error :: {already_started, pid()}} |
		      {error, Error :: term()} |
		      ignore.
start_link(#service{name=Name, image=Image, task=Task} = Service) ->
    case Task of
	undefined ->
	    Json = container_builder:build(Service),
	    create(Name, Json, Image, Service);
	_ ->
	    % Make sure that tasks never restart and are removed on completion
	    TaskNeverRestart = Service#service{restart=never, auto_remove=true},
	    Json = container_builder:build(TaskNeverRestart),
	    erlcron:cron(Name, Task, {container_monitor, create, [Name,Json, Image, Service]})
    end;

start_link(CID) when is_binary(CID) ->
    SafeId = to_atom_safe(CID),
    Service = container_builder:get_config(CID),
    Res = gen_server:start_link({local, SafeId}, ?MODULE, [Service#service{restart=never, id=CID}, true], []),
    check_assignment(Res, Service),
    folsom_metrics:notify({veo_started_containers, 1}),
    Res.
    

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) -> {ok, State :: term()} |
			      {ok, State :: term(), Timeout :: timeout()} |
			      {ok, State :: term(), hibernate} |
			      {stop, Reason :: term()} |
			      ignore.
init([#service{id=ContainerID, healthcheck=HealthCheck} = Service, Exists]) ->
    process_flag(trap_exit, true),
    case Exists of
	true ->
	    gen_server:cast(self(), monitor);
	false ->
	    gen_server:cast(self(), start)		
    end,
    case HealthCheck of
	undefined -> void;
	#healthcheck{interval=Interval} ->
	    case Interval of
		0 ->
		    timer:send_interval(5000, check_health);
		_ ->
		    timer:send_interval(Interval, check_health)
	    end
    end,
    {ok, Inspect} = docker_container:container(ContainerID),
    Container = container_builder:set_container_properties_from_inspect(Inspect, Service),
    gen_server:cast(self, stats),
    {ok, 
     Container#container{
       id=ContainerID,
       logs=[],
       restart_counter = 0,
       service=Service,
       pid=self(),
       node=erlang:node()
      }
    }.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request :: term(), From :: {pid(), term()}, State :: term()) ->
			 {reply, Reply :: term(), NewState :: term()} |
			 {reply, Reply :: term(), NewState :: term(), Timeout :: timeout()} |
			 {reply, Reply :: term(), NewState :: term(), hibernate} |
			 {noreply, NewState :: term()} |
			 {noreply, NewState :: term(), Timeout :: timeout()} |
			 {noreply, NewState :: term(), hibernate} |
			 {stop, Reason :: term(), Reply :: term(), NewState :: term()} |
			 {stop, Reason :: term(), NewState :: term()}.
handle_call(info, _From, State) ->
    {reply, State, State};
handle_call(logs, _From, #container{logs=Logs} = State) ->
    {reply, Logs, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request :: term(), State :: term()) ->
			 {noreply, NewState :: term()} |
			 {noreply, NewState :: term(), Timeout :: timeout()} |
			 {noreply, NewState :: term(), hibernate} |
			 {stop, Reason :: term(), NewState :: term()}.
handle_cast(stop, #container{id=CID}=State) ->
    docker_container:stop(CID),
    docker_container:delete(CID),
    SupName = global:whereis_name(list_to_atom(atom_to_list(erlang:node())++atom_to_list(container_sup))),
    supervisor:terminate_child(SupName, self()),
    Service = State#container.service,
    NewState = State#container{service=Service#service{restart=never}},
    container_storage:save_container(NewState),
    {noreply, NewState};

handle_cast(start, #container{id=CID}=State) ->
    docker_container:start(CID, undefined),
    {IP, PortMaps} = register_dns(State),
    gen_server:cast(self(), monitor),
    NewState = State#container{
		restart_counter=State#container.restart_counter + 1,
		ip_address=IP,
		port_maps=PortMaps
	       },
    container_storage:save_container(NewState),
    {noreply, NewState};

handle_cast({status, Status}, State) ->
    lager:debug("Status changed ~p~n", Status),
    {noreply, State};

handle_cast(monitor, #container{id=CID}=State) ->
    docker_container:attach_stream_with_logs(CID),
    %% Me = self(),
    %% spawn(fun() ->
    %% 		  Exited = erldocker_api:wait(CID),
    %% 		  io:format("WAIT RETURN ~p~n", [Exited]),
    %% 		  Me ! Exited
    %% 	  end),
    {noreply, State};

handle_cast(stats, #container{id=CID}=State) ->
    Stats = erldocker_api:get([containers, CID, stats], [{stream, false}]),
    folsom_metrics:notify({veo_stats_calls, 1}),
    NewState = case parse_stats(Stats) of
		   {ok, Parsed} -> 
		       State#container{stats=Parsed};
		   {error, _Error} -> 
		       folsom_metrics:notify({veo_stats_failures, 1}),
		       State
	       end,
    timer:apply_after(10000, ?MODULE, handle_cast, [stats, State]),    
    {noreply, NewState};

handle_cast(Request, State) ->
    lager:warning("Unexpected message in monitor cast ~p~n", Request),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info :: timeout() | term(), State :: term()) ->
			 {noreply, NewState :: term()} |
			 {noreply, NewState :: term(), Timeout :: timeout()} |
			 {noreply, NewState :: term(), hibernate} |
			 {stop, Reason :: normal | term(), NewState :: term()}.
handle_info({_Pid, {data, _Data}}, #container{logs = _Logs} = State) when is_binary(_Data) ->
    %% lager:info("Receiving binary log ~s~n", [binary_to_list(_Data)]),
    %% THIS EATS UP A LOT OF MEMORY MAKING THE SYSTEM UNUSABLE
    io:format("Log ~s~n", [_Data]),
    %% LogLine = io_lib:format("~s", [Data]),
    %% NewLogs = lists:append(LogLine, Logs),
    %% NewState = State#state{logs=NewLogs},
    {noreply, State};

handle_info({_Pid, {data, _Data}}, #container{logs = _Logs} = State) ->
    %% lager:info("Receiving log ~p~n", [_Data]),
    %% THIS EATS UP A LOT OF MEMORY MAKING THE SYSTEM UNUSABLE
    io:format("Log ~s~n", [_Data]),
    %% NewLogs = lists:append(LogLine, Logs),
    %% NewState = State#state{logs=NewLogs},
    {noreply, State};

handle_info({_Pid, {error, {Reason, Data}}}, State) ->
    lager:error("ERROR ~s:  ~p ~p~n", [Reason, Data, State]),
    container_storage:remove_container(State#container.id),
    {noreply, State};

handle_info({hacnkey_response, _SenderRef, Data}, State) ->
    io:format("Log ~s~n", [Data]),
    {noreply, State};
handle_info({hackney_response,_,<<>>}, State) ->
    io:format("Empty ~n",[]),
    {noreply, State};
handle_info({hackney_response,_,done}, State) ->
    io:format("Gone ~n",[]),
    {noreply, State};    
handle_info({hackney_response,_,D}, State) ->
    io:format("Data ~s~n",[D]),
    {noreply, State};    

handle_info({'EXIT', _Pid, Reason}, #container{service=Service, 
					   restart_counter = Counter
					  } = State) -> 
    case _Pid == self() of
	false ->	    
	    io:format("CAUGHT EXIT PID = ~p, Self = ~p, ~p~n", [_Pid, self(), Reason]),
	    {noreply, State};
	true ->
	    case Service#service.restart of
		restart ->
		    lager:info("RESTARTING ~p, ~s, ~p~n", [Service, Reason, Counter]),
		    case Counter > Service#service.restart_count of
			true ->
			    lager:info("EXITING: restart counter reached~n", []),
			    stop(State),
			    folsom_metrics:notify({veo_failed_containers, 1}),
			    {noreply, State};
			false ->
			    lager:info("RESTARTING ~s, ~p, ~p~n", [Reason, Service, Counter]),
			    restart(State),
			    {noreply, State}
		    end;
		never ->
		    lager:info("EXITING ~n", []),
		    stop(State),
		    {noreply, State}
	    end
    end;
handle_info(check_health, #container{id=CID}=State) ->
    Inspect = docker_container:container(CID),
    case Inspect of
	{ok, S} ->
	    Status = parse_status(S),
	    lager:info("Status is ~p~n", [Status]),
	    {noreply, State#container{status=Status}};
	E ->
	    lager:warning("Unable to get status ~p~n", [E]),
	    {noreply, State}
    end;

handle_info(_Info, State) ->
    lager:info("Received ~p~n", [_Info]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason :: normal | shutdown | {shutdown, term()} | term(),
		State :: term()) -> any().
terminate(Reason, _State) ->
    lager:info("Terminating ~p~n",[Reason]),
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%% @end
%%--------------------------------------------------------------------
-spec code_change(OldVsn :: term() | {down, term()},
		  State :: term(),
		  Extra :: term()) -> {ok, NewState :: term()} |
				      {error, Reason :: term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called for changing the form and appearance
%% of gen_server status when it is returned from sys:get_status/1,2
%% or when it appears in termination error logs.
%% @end
%%--------------------------------------------------------------------
-spec format_status(Opt :: normal | terminate,
		    Status :: list()) -> Status :: term().
format_status(_Opt, Status) ->
    Status.

%%%===================================================================
%%% Internal functions
%%%==================================================================
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Adds the requested resources for the container to the allocated
%% resources for the node.
%% @end
%%--------------------------------------------------------------------    
check_assignment({ok, _}, #service{cpus=CPU, memory=Memory, disk=Disk}) ->
    node_monitor:allocate(erlang:node(), #allocation{cpu = CPU, memory=Memory, disk=Disk});
check_assignment(_, _) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Removes this container from the resources of the node
%% @end
%%--------------------------------------------------------------------    
deallocate(#service{cpus=CPU, memory=Memory, disk=Disk}) ->
    C = case CPU > 0 of
	    true -> CPU * -1;
	    false -> 0
	end,
    D = case Disk > 0 of
	    true -> Disk * -1;
	    false -> 0
	end,
    M = case Memory > 0 of
	    true -> Memory*-1;
	    false -> 0
	end,
    node_monitor:allocate(erlang:node(), #allocation{cpu = C, memory=M, disk=D}).    

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Gets the containers in this containers group.
%% @end
%%--------------------------------------------------------------------
-spec(check_group(Container::#container{}, Group :: undefined|atom()) -> [#container{}]).
check_group(Container, undefined) ->
    [Container];
check_group(Container, Group) ->
    case container_sup:get_container_group(Group) of
	[] ->
	    [Container];
	Containers ->
	    Containers
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Adds a container to the DNS
%%
%% @see dns_registry:add_service/4
%% @end
%%--------------------------------------------------------------------
-spec(register_dns(Container::#container{}) -> {tuple(), [#port{}]}).
register_dns(#container{service=#service{id=CID, name=Name}=Service}=Container) ->
    
    {IP, Ports} = case docker_container:container(CID) of 
		      {ok, Inspect} ->			  
			  #service{ports = PortList} = container_builder:parse_inspect(Inspect, Service),
			  {get_container_ip(Service, Inspect), PortList};
		      {error, Error} ->
			  lager:error("Error getting container IP and ports (retrying) ~p~n", [Error]),
			  register_dns(Container)
		  end,
    dns_registry:add_service(Name, CID, IP, Ports),
    {IP, Ports}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Removes the container from the DNS.
%%
%% @see dns_registry:remove_records/3
%% @end
%%--------------------------------------------------------------------
-spec(remove_from_dns(Container::#container{}) -> ok| {error, term()}).
remove_from_dns(#container{ip_address=IP, port_maps=Ports, service=#service{name=Name}}) ->
    dns_registry:remove_records(Name, Ports, IP).
    

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Gets host IP.
%% 
%% @end
%%--------------------------------------------------------------------
get_container_ip(#service{network_mode=_NetMode}, _Inspect) ->
    %% case NetMode of
	%% "host" ->
    lager:debug("Getting address from inet~n"),
    {ok, Addrs} = inet:getifaddrs(),
    hd([
	     Addr || {Name, Opts} <- Addrs, {addr, Addr} <- Opts,
		     size(Addr) == 4, Addr =/= {127,0,0,1}, string:str(Name,"docker") =:= 0
       ]).
    %% 	_ ->	   
    %% 	    lager:debug("Getting address from inspect~n"),
    %% 	    Settings = proplists:get_value('NetworkSettings', Inspect, {}),
    %% 	    Networks = proplists:get_value(<<"Networks">>, Settings, {}),
    %% 	    Bridge = proplists:get_value(<<"bridge">>, Networks, {}),
    %% 	    IP = proplists:get_value(<<"IPAddress">>, Bridge, {}),
    %% 	    Parts = binary:split(IP, <<".">>, [global]),
    %% 	    RIP = list_to_tuple(lists:map(fun(P) -> 
    %% 						  list_to_integer(
    %% 						    binary_to_list(P))
    %% 					  end, Parts)
    %% 			       ),
    %% 	    lager:debug("IP from inspect ~p, ~p~n",[RIP, Inspect]),
    %% 	    RIP
    %% end.
			      
	    
    
%%%===================================================================
%%% Restart containers based on their group settings
%%%===================================================================


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Restarts a container.
%% Behaves differently based on the group policy.
%%
%% No group: Restart normally
%% Policies:
%%
%% master_kills_all and this is a master: Restart all in group.
%% master_kills_all and this is not a master: Restart only this.
%% one_kills_all: Restart all in group
%% one_for_one: Restart only this.
%% @end
%%--------------------------------------------------------------------
-spec(restart(Container::#container{}) -> ok | {error, term()}).
restart(#container{pid=Pid,
	   service=#service{
			    group=undefined}}) ->
    gen_server:cast(Pid, stop),
    gen_server:cast(self(), start),
    folsom_metrics:notify({veo_restarted_containers, 1});

%% A master dies and the policy is to kill all when master dies
restart(#container{service=
		       #service{
			  group=Group, 
			  group_role=master, 
			  group_policy=master_kills_all}}=State) ->
    Containers = check_group(State, Group),    
    lists:foreach(fun(#container{pid=Pid}) ->
			  gen_server:cast(Pid, stop),
    			  gen_server:cast(Pid, start)
    		  end, Containers),
    folsom_metrics:notify({veo_restarted_containers, 1});

%% A slave dies and the policy is to kill all when master dies
restart(#container{service=
		       #service{
			  group_role=_, 
			  group_policy=master_kills_all}, pid=Pid}) ->
    gen_server:cast(Pid, stop),
    gen_server:cast(Pid, start),
    folsom_metrics:notify({veo_restarted_containers, 1});    

%% The policy is that one dead kills the group
restart(#container{service=
		       #service{
			  group=Group, 
			  group_role=_,
			  group_policy=one_kills_all}}=State) ->
    Containers = check_group(State, Group),    
    lists:foreach(fun(#container{pid=Pid}) ->
			  gen_server:cast(Pid, stop),
    			  gen_server:cast(Pid, start)
    		  end, Containers),
    folsom_metrics:notify({veo_restarted_containers, 1});

%% A single container dies in a group with a policy of one_for_one
%% Just restart that container
restart(#container{pid=Pid,
		   service=
		       #service{
			  group_policy=one_for_one}}) ->
    gen_server:cast(Pid, stop),
    gen_server:cast(Pid, start),
    folsom_metrics:notify({veo_restarted_containers, 1}).

%%%===================================================================
%%% Stop containers based on their group settings
%%%===================================================================


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Stops a container.
%% Behaves differently based on the group policy.
%%
%% No group: Just stop the container
%% Policies:
%%
%% master_kills_all and this is a master: Stop all in group.
%% master_kills_all and this is not a master: Stop only this.
%% one_kills_all: Stop all in group
%% one_for_one: Stop only this.
%% @end
%%---------------------------------------------------------------------
create(Name, Json, Image, Service) ->
    Created = erldocker_api:post([containers, create], [{name, Name}] , Json),
    lager:debug("Created container ~p~n", [Created]),
    case Created of
	{ok, [{_,Container}, {<<"Warnings">>, null}]} ->
	    SafeId = to_atom_safe(Container),
	    Res = gen_server:start_link({local, SafeId}, ?MODULE, [Service#service{id = Container}, false], []),
	    check_assignment(Res, Service),
	    folsom_metrics:notify({veo_started_containers, 1}),
	    Res;
	{ok, [{_,Container}, {<<"Warnings">>, Warnings}]} ->
	    lager:warning("Container created with warnings ~p~n", [Warnings]),
	    SafeId = to_atom_safe(to_name(Container, Name, Image)),
	    Res = gen_server:start_link({local, SafeId}, ?MODULE, [Service#service{id = Container}, false], []),
	    check_assignment(Res, Service),
	    folsom_metrics:notify({veo_started_containers, 1}),
	    Res;
	{error, {Code, Error}} ->
	    lager:error("Error creating container ~p~n", [Error]),
	    folsom_metrics:notify({veo_failed_containers, 1}),
	    {error, {Code, Error}};
	{error, Error} ->
	    folsom_metrics:notify({veo_failed_containers, 1}),
	    {error, Error}	
    end.

-spec(stop(Container::#container{}) -> ok | {error, term()}).
stop(#container{pid=Pid,
	   service=#service{id=ID,
			    group=undefined}}=State) ->
    lager:info("Stopping container with no group ~p~n", [ID]),
    gen_server:cast(Pid, stop),
    deallocate(State#container.service),
    folsom_metrics:notify({veo_stopped_containers, 1}),
    remove_from_dns(State);

stop(#container{service=
		       #service{
			  group=Group, 
			  group_role=master, 
			  group_policy=master_kills_all}}=State) ->
    lager:info("Stopping container in a group (master kills all) ~p~n", [Group]),
    Containers = check_group(State, Group),
    lager:info("Group containers ~p~n", [Containers]),
    lists:foreach(fun(#container{service=#service{id=ID}, pid=Pid}) ->
			  lager:info("Deleting group container ~p, with pid ~p~n", [ID, Pid]),
    			  gen_server:cast(Pid, stop)
    		  end, Containers),
    deallocate(State#container.service),
    remove_from_dns(State),
    folsom_metrics:notify({veo_stopped_containers, 1}),
    gen_server:cast(self(), stop);

stop(#container{pid=Pid, service=
		    #service{
		       group=Group, 
		       group_role=Role, 
		       group_policy=master_kills_all}}=State) ->
    lager:info("Stopping ~p container in a group (master kills all) ~p~n", [Role, Group]),
    deallocate(State#container.service),
    remove_from_dns(State),
    folsom_metrics:notify({veo_stopped_containers, 1}),
    gen_server:cast(Pid, stop);

stop(#container{service=
		       #service{
			  group=Group, 
			  group_role=_,
			  group_policy=one_kills_all}}=State) ->
    lager:info("Stopping container in a group (one kills all) ~p~n", [Group]),
    Containers = check_group(State, Group),
    lager:info("Group containers ~p~n", [Containers]),
    lists:foreach(fun(#container{pid=Pid}) ->
			  gen_server:cast(Pid, stop)
    		  end, Containers),
    deallocate(State#container.service),
    remove_from_dns(State),
    folsom_metrics:notify({veo_stopped_containers, 1}),
    gen_server:cast(self(), stop);

stop(#container{pid=Pid,
		service=
		    #service{
		       id=ID,
		       group_policy=one_for_one}}=State) ->
    lager:info("Stopping container in a group (one for one) ~p~n", [ID]),
    gen_server:cast(Pid, stop),
    deallocate(State#container.service),
    folsom_metrics:notify({veo_stopped_containers, 1}),
    remove_from_dns(State).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Check the status of a container.
%% Also checks if the container has a health check and returns that
%% status if applicable.
%% @end
%%--------------------------------------------------------------------
parse_status(Inspect) ->
    case proplists:get_value('State', Inspect, undefined) of
	undefined ->
	    undefined;
	State ->
	    Health = proplists:get_value(<<"Health">>, State, undefined),
	    case Health of
		undefined ->
		    proplists:get_value(<<"Status">>, State, undefined);
		_ ->
		    proplists:get_value(<<"Status">>, Health, undefined)
	    end
    end.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Creates a unique name for the container monitor.
%% 
%% @end
%%--------------------------------------------------------------------
-spec(to_name(CID::binary()|[string()], Name::binary()|[string()]|undefined, Image::binary()|string()) -> binary()).
to_name(CID, Name, Image) when is_list(CID) ->
    to_name(list_to_binary(CID), Name, Image);
to_name(CID, Name, Image) when is_list(Name) ->
    to_name(CID, list_to_binary(Name), Image);
to_name(CID, Name, Image) when is_list(Image) ->
    to_name(CID, Name, list_to_binary(Image));
to_name(CID, Name, Image) when is_binary(CID) andalso is_binary(Name) andalso is_binary(Image) ->
    Dash = <<"-">>,
    <<Image/binary, Dash/binary, Name/binary, Dash/binary, CID/binary>>;
to_name(CID, undefined, Image) when is_binary(CID) andalso is_binary(Image)->
    Dash = <<"-">>,
    <<Image/binary, Dash/binary, CID/binary>>.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Safely converts a list or binary to atom (in case the atom already
%% exits).
%% 
%% @end
%%--------------------------------------------------------------------
-spec(to_atom_safe(binary()|[string()]) -> atom()).
to_atom_safe(CID) when is_binary(CID) ->
    to_atom_safe(binary_to_list(CID));
to_atom_safe(CID) when is_list(CID) ->
    try list_to_existing_atom(CID) of
	{badarg, _} ->
	    to_atom(CID);
	A -> A
    catch
	error:_ -> to_atom(CID)
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert a list or binary to atom.
%% 
%% @end
%%--------------------------------------------------------------------
-spec(to_atom(binary()|[string()]) -> atom() | {invalid_name, term()}).
to_atom(CID) when is_binary(CID) ->
    binary_to_atom(CID, utf8);
to_atom(CID) when is_list(CID) ->
    to_atom(list_to_binary(CID));
to_atom(CID) ->
    {invalid_name, CID}.

parse_stats({error, Error}) ->
    {error, Error};
parse_stats({ok, Stats}) ->
    Read = proplists:get_value(<<"read">>, Stats, undefined),
    MemoryStats = proplists:get_value(<<"memory_stats">>, Stats),
    CPU = proplists:get_value(<<"cpu_stats">>, Stats),
    PreCPU = proplists:get_value(<<"precpu_stats">>, Stats),
    {ok, #stats{memory = get_memory_percentage(MemoryStats),
	   cpu= get_cpu_percentage(CPU, PreCPU),
	   timestamp=Read}}.

get_memory_percentage([{}]) ->
    #container_memory{};
get_memory_percentage(Memory) ->    
    Usage = proplists:get_value(<<"usage">>, Memory),
    Cache = proplists:get_value(<<"cache">>, proplists:get_value(<<"stats">>, Memory)),
    Available = proplists:get_value(<<"limit">>, Memory),
    Percentage = ((Usage-Cache)/Available) *100.0,
    #container_memory{used=Percentage, available=Available}.

get_cpu_percentage(CPU, PreCPU) ->
    CurrentUsage = proplists:get_value(<<"cpu_usage">>, CPU),
    PreviousUsage = proplists:get_value(<<"cpu_usage">>, PreCPU),
    Delta = proplists:get_value(<<"total_usage">>, CurrentUsage) - proplists:get_value(<<"total_usage">>, PreviousUsage),
    CPUCount = proplists:get_value(<<"online_cpus">>, CPU),
    SystemUsage = proplists:get_value(<<"system_cpu_usage">>, CPU),
    SystemPrevious = proplists:get_value(<<"system_cpu_usage">>, PreCPU),
    case {SystemUsage, SystemPrevious} of
	{undefined, _} ->
	    #container_cpu{};
	{_, undefined} ->
	    #container_cpu{};
	_ ->
	    SystemDelta =  SystemUsage - SystemPrevious,    
	    Percentage = (Delta / SystemDelta) * CPUCount * 100.0,
	    #container_cpu{count=CPUCount, used=Percentage}
    end.
