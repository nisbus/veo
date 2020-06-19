%%%-------------------------------------------------------------------
%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2019, nisbus
%%% @doc
%%% Manages nodes across a cluster.
%%%
%%% Takes care of registering nodes and their resources.
%%% When scheduling a task call the where function to get a list of
%%% nodes capable of hosting the task.
%%%
%%% @end
%%% Created :  6 Dec 2019 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(node_monitor).

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3, format_status/2]).

-export([get_resources/0, available/0, where/6, allocate/2, free/0, assign_role/2]).
-define(SERVER, ?MODULE).
-include("../include/gproc.hrl").
-include("../include/node.hrl").
-include("../include/container.hrl").

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Assigns a role to a node
%% @end
%%--------------------------------------------------------------------
-spec(assign_role(Node::atom, Role::binary()|string()) -> ok | {error, no_node}).
assign_role(Node, Role) ->
    case connect_node(Node) of
	false ->
	    {error, no_node};
	true ->
	    gen_server:cast(global:whereis_name(create_call_name(erlang:node())), {role, Role})
    end.
%%--------------------------------------------------------------------
%% @doc
%% Get a node for running an application based on the applications 
%% required resources
%% @end
%%--------------------------------------------------------------------
%-spec(where(CPU::float(), Memory::float(), Disk::float(), Hosts::[string()], Roles::[string()], Group::undefined|atom()) -> [tuple()]).
where(CPU, Memory, Disk, Hosts, Roles, Group) ->
    Remote = erlang:nodes(),
    lager:debug("checking resources for remote nodes ~p~n",[Remote]),
    LocalResources = node_monitor:free(),
    Nodes = case Remote of 
		[] ->
		    [LocalResources];
		_ ->
		    RemoteResources = lists:foldl(fun(Node, Acc) ->							
							  Resource = rpc:call(Node, ?MODULE, free, []),
							  [Resource|Acc]
						   end, [], Remote),
		    [LocalResources|RemoteResources]
	    end,
    lager:debug("Nodes ~p~n", [Nodes]),
    Available = lists:foldl(fun({N, AC, AM, AD, {_, R}}=A, Acc) ->			
				    case has_resources(CPU, AC, Memory, AM, Disk, AD) of 
					true ->
					    lager:debug("match role and host ~p, ~p~n", [R, Roles]),
					    case matches_role_and_hosts(N, R, Hosts, Roles) of
						true ->
						    [A | Acc];
						false ->
						    Acc
					    end;
					false ->
					    Acc
				    end
			    end, [], Nodes),
    lager:debug("Available ~p~n", [Available]),
    Result = case Group of 
		 undefined -> Available;
		 _ ->
		     All = lists:foldl(fun([N, _, _, _, _]=Node, Acc) ->
					       case rpc:call(N, container_sup, list_containers, []) of
						   {ok, NodeContainers} ->
						       lists:append(Acc,[{Node, NodeContainers}]);
						   {error, Error} ->
						       lager:warning("Error getting containers from node ~p ~p~n", [N, Error]),
						       Acc;
						   [] ->
						       Acc;
						   Containers ->
						       lists:append(Acc, [{Node, Containers}])
					       end
				       end, [], Nodes),
		     lager:debug("Filtering ~p~n", [All]),
		     case lists:filter(fun({_N,Containers}) ->
					       lists:any(fun(#container{service=#service{group=ContainerGroup}}) ->
								 ContainerGroup =:= Group
							 end, Containers)
				       end, All) of
			 [] -> Available;
			 [{Found,_}] -> [Found]
		     end
	     end,
    lager:debug("Results ~p~n", [Result]),
    case Result of
	[] ->
	    lager:info("No node found matching constraints~n"),
	    [];
	[H|[]] ->
	    lager:debug("Only one result ~p~n", [H]),
	    [H];
	_ ->
	    lager:debug("Multiple results ~p~n", [Result]),
	    lists:sort(fun({_, C, M, D, _},{_, C0, M0, D0, _}) ->
			       C > C0 orelse M > M0 orelse D > D0
		       end, Result)
    end.

matches_role_and_hosts(_, _, [], []) ->
    true;
matches_role_and_hosts(Node, _, Hosts, []) when is_list(Hosts) ->
    case lists:filter(fun(X) ->
			 Node =:= X
		 end, Hosts) of
	[] ->
	    false;
	_ ->
	    true
    end;
matches_role_and_hosts(_, Role, _, Roles) when is_list(Roles) ->
    case lists:filter(fun(X) ->
			 Role =:= X
		 end, Roles) of
	[] ->
	    false;
	_ ->
	    true
    end.
    




%%--------------------------------------------------------------------
%% @doc
%% Get a nodes resource report
%% @end
%%--------------------------------------------------------------------
-spec(get_resources() -> #node_state{}).
get_resources() ->
    gen_server:call(global:whereis_name(create_call_name(erlang:node())), resources).

%%--------------------------------------------------------------------
%% @doc
%% Get a nodes short resource report
%%
%% Returns a list of [node, cpu, mem, disk, {node, role}] for a node.
%% @end
%%--------------------------------------------------------------------
-spec(available() -> {atom(), float(), float(), float(), {atom(), string()}}).
available() ->
    #node_state{memory=#memory{available=Mem}, cpu=#cpu{count=CPU}, disk=#disk{available=Disk}, role=Role} = get_resources(),
    {erlang:node(), CPU, Mem, Disk, Role}.
    
%%--------------------------------------------------------------------
%% @doc
%% Returns free resources for a node
%% @end
%%--------------------------------------------------------------------
-spec(free() -> {atom(), float(), float(), float(), {atom(), string()}}).
free() ->
    #node_state{memory=#memory{available=Mem}, 
		cpu=#cpu{count=CPU}, 
		disk=#disk{available=Disk},
		role=Role,
		allocated=#allocation{
			    cpu=AllocCPU,
			    disk=AllocDisk,
			    memory=AllocMem}
	       } = get_resources(),
    case Role of
	{_Name, _Role} ->
	    {erlang:node(), CPU-AllocCPU, Mem-AllocMem, Disk-AllocDisk, Role};
	_ -> 
	    {erlang:node(), CPU-AllocCPU, Mem-AllocMem, Disk-AllocDisk, {erlang:node(),""}}
    end.


%%--------------------------------------------------------------------
%% @doc
%% Allocates resources to a node.
%% This will subtract from the resources of the node and affect 
%% how much free resources are left in a node
%% @end
%%--------------------------------------------------------------------
-spec(allocate(Node:: atom(), Allocation::#allocation{}) -> ok).
allocate(Node, Allocation) ->
    Where = global:whereis_name(create_call_name(Node)),
    gen_server:cast(Where, {allocate, Allocation}).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid :: pid()} |
		      {error, Error :: {already_started, pid()}} |
		      {error, Error :: term()} |
		      ignore.
start_link() ->
    Node = create_call_name(erlang:node()),
    gen_server:start_link({global, Node}, ?MODULE, [], []).


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
init([]) ->    
    process_flag(trap_exit, true),
    net_kernel:monitor_nodes(true),
    self() ! refresh,
    timer:send_interval(10000, refresh),
%    Node = create_call_name(erlang:node()),
    Role = settings:get_role(erlang:node()),
    
    {ok, #node_state{
	    node=erlang:node(),
	    role=Role,
	    connected=[]
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
handle_call(resources, _From, State) ->
    {reply, State, State};

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
handle_cast(print_resources, #node_state
	    {
	      memory=#memory{used=UsedMem, available=FreeMem, total=TotalMem},
	      disk=#disk{used=UsedDisk, available=FreeDisk, total=TotalDisk},
	      cpu=#cpu{count=NumCpu, used=CpuUsed, available=CpuAvail}
	    } = State) ->
    lager:debug("MEMORY: Total ~p, Used ~p, Available ~p~n", [TotalMem, UsedMem, FreeMem]),
    lager:debug("DISK: Total ~p GB, Used ~p GB, Available ~p GB~n", [(TotalDisk/1024)/1024, (UsedDisk/1024)/1024, (FreeDisk/1024)/1024]),
    lager:debug("CPU: Count ~p, Used ~p%, Available ~p%~n", [NumCpu, CpuUsed, CpuAvail]),   
    {noreply, State};

handle_cast({allocate, #allocation{cpu=CPU, memory=Memory, disk=Disk}}, 
	    #node_state{allocated=#allocation{
				     cpu=ACPU, memory=AMem, disk=ADisk
				    }
		       } = State) ->
    NewAllocation = #allocation{
		       cpu = ACPU+CPU,
		       memory = AMem+Memory,
		       disk = ADisk +Disk
		      },
    {noreply, State#node_state{
		allocated=NewAllocation
	       }
    };


handle_cast(_Request, State) ->
    lager:warning("Unhandled cast ~p - ~p~n", [_Request, State]),
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
handle_info(refresh, State) ->
    Memory = memsup:get_system_memory_data(),
    TotalMemory = proplists:get_value(total_memory, Memory),
    FreeMemory  = proplists:get_value(free_memory, Memory),
    UsedMemory = TotalMemory - FreeMemory,
    Disk = disksup:get_disk_data(),    
    Root = lists:filter(fun(D) ->
				case D of
				    {"/", _Size, _UsedPercent} ->
					true;
				    _ -> 
					false
				end
			end, Disk),
    case Root of
	[] -> 
	    Size = 0,
	    Available=0,
	    Used = 0;     	
	[{_, Size, UsedPercent}] ->
	    Used = Size * (UsedPercent/100),
	    Available = Size - Used
    end,	
    {C, User, System,_}= cpu_sup:util([detailed]),
    CpuUse = proplists:get_value(user, User),
    CpuAvail = proplists:get_value(idle, System), 
    NewState = State#node_state{
		 memory = #memory{used=UsedMemory, available=FreeMemory, total=TotalMemory},
		 disk=#disk{used=Used, total = Size, available=Available},
		 cpu=#cpu{count=length(C), used= CpuUse, available=CpuAvail},
		 connected = nodes()
	      },
    {noreply, NewState};

handle_info({nodedown, Node}, State) ->
    Containers = container_storage:containers_for_node(Node),
    case Containers of
	[] ->
	    lager:debug("Node ~p went down with no containers", [Node]);
	_ ->
	    lager:debug("Node ~p went down, rescheduling containers"),
	    spawn(fun() ->
			  StartResults = lists:map(fun(#container{service=Service}) ->
							   case Service#service.restart of
							       restart ->
								   container_sup:add_service(Service);
							       _ ->
								   {"No restart", Service#service.name}
							   end
						   end, Containers),
			  lager:debug("Rescheduled containers ~p~n", [StartResults])
		  end)
    end,
    {noreply, State};

handle_info({nodeup, Node}, State) ->
    lager:debug("New node detected ~p~n",[Node]),
    {noreply, State};

handle_info(_Info, State) ->
    lager:debug("Received unsupported message ~p~n", [_Info]),
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
terminate(_Reason, _State) ->
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
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Tries to connect to a remote node
%% @end
%%--------------------------------------------------------------------
connect_node(Node) ->
    case net_adm:ping(Node) of
	pong ->
	    true;
	pang ->
	    false
    end.

create_call_name(Node) ->
    list_to_atom(atom_to_list(Node)++atom_to_list(?MODULE)).

has_resources(RequestedCPU, HasCPU, RequestedMem, HasMem, RequestedDisk, HasDisk) 
  when RequestedCPU =< HasCPU andalso 
       RequestedMem < HasMem andalso 
       RequestedDisk < HasDisk ->
    lager:debug("Match found: RequestedCPU = ~p, HasCpu = ~p, RequestedMem = ~p, HasMem ~p, RequestedDisk = ~p, HasDisk ~p~n",
	      [RequestedCPU, HasCPU, RequestedMem, HasMem, RequestedDisk, HasDisk]),
    true;
has_resources(RequestedCPU, HasCPU, RequestedMem, HasMem, RequestedDisk, HasDisk) ->
    lager:info("No match found: RequestedCPU = ~p, HasCpu = ~p, RequestedMem = ~p, HasMem ~p, RequestedDisk = ~p, HasDisk ~p~n", 
	      [RequestedCPU, HasCPU, RequestedMem, HasMem, RequestedDisk, HasDisk]),
    false.
