%%%-------------------------------------------------------------------
%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2019, nisbus
%%% @doc
%%% Container supervisor.
%%% This supervisor manages all running containers.
%%% 
%%% @end
%%% Created :  6 Dec 2019 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(container_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).
-export([add_service/1, 
	 count/0, 
	 list_containers/0, 
	 get_containers/0, 
	 get_container_group/1, 
	 cloud_containers/0]).
%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).
-include("../include/container.hrl").

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> {ok, Pid :: pid()} |
		      {error, {already_started, Pid :: pid()}} |
		      {error, {shutdown, term()}} |
		      {error, term()} |
		      ignore.
start_link() ->
    Name = list_to_atom(atom_to_list(erlang:node())++atom_to_list(?MODULE)),
    supervisor:start_link({global, Name}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart intensity, and child
%% specifications.
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) ->
		  {ok, {SupFlags :: supervisor:sup_flags(),
			[ChildSpec :: supervisor:child_spec()]}} |
		  ignore.
init([]) ->
    cleanup(),
    Spec = {container_monitor, 
	    {container_monitor, start_link, []},
	    temporary, brutal_kill, worker, [container_monitor]},
    {ok, {{simple_one_for_one, 0, 1}, [Spec]}};

init([Service]) when is_record(Service, service) ->
    Spec = {container_monitor, 
	    {container_monitor, start_link, [Service]},
	    temporary, brutal_kill, worker, [container_monitor]},
    {ok, {{simple_one_for_one, 0, 1}, [Spec]}};

init([CID]) when is_list(CID) ->
    Spec = {container_monitor, 
	    {container_monitor, start_link, [CID]},
	    temporary, brutal_kill, worker, [container_monitor]},
    {ok, {{simple_one_for_one, 0, 1}, [Spec]}}.


%%------------------------------------------------------------------------------
%% @doc
%% Add a service to the scheduler.
%% The scheduler will find the appropriate node/s to run the service.
%% 
%% @end
%%------------------------------------------------------------------------------    
-spec(add_service(Service::#service{}) -> {ok, started} | {error, term()}).
add_service(#service
	    {
	      group=Group,
	      roles=Roles,
	      hosts=Hosts,
	      cpus=CPU,
	      memory=Memory,
	      disk=Disk
	    } = Service) ->
    Available = node_monitor:where(CPU, Memory, Disk, Hosts, Roles, Group),
    case Available of 
	[] ->
	    {error, no_suitable_node};
	[{N, _, _, _, _}|_] ->
	    Where = list_to_atom(atom_to_list(N)++atom_to_list(?MODULE)),
	    Supervisor = global:whereis_name(Where),
	    lager:debug("Starting child on ~p, PID=~p~n", [N, Supervisor]),
	    Result = supervisor:start_child(Supervisor, [Service]),
	    lager:debug("Started ~p~n", [Result]),
	    Result
    end;
add_service(Service) ->
    lager:debug("Received service ~p~n", [Service]),
    Match = is_record(Service, service),
    io:format(user, "Is record ~p~n~p", [Match, Service]).
    


%%------------------------------------------------------------------------------
%% @doc
%% Get the number of containers on this node.
%%
%% @end
%%------------------------------------------------------------------------------    
-spec count() -> integer().
count() ->
    Where = list_to_atom(atom_to_list(erlang:node())++atom_to_list(?MODULE)),
    Supervisor = global:whereis_name(Where),
    Res = supervisor:count_children(Supervisor),
    Workers = proplists:get_value(workers, Res),
    Workers.

%%------------------------------------------------------------------------------
%% @doc
%% Get the containers on this node.
%%%
%% @end
%%------------------------------------------------------------------------------    
-spec(list_containers() -> [#container{}]).
list_containers() ->
    Where = list_to_atom(atom_to_list(erlang:node())++atom_to_list(?MODULE)),
    Supervisor = global:whereis_name(Where),
    Children = supervisor:which_children(Supervisor),
    lists:foldl(fun(Elem, Acc) ->
			{_ID, Pid, _, _} = Elem,
			try gen_server:call(Pid, info) of
			    #container{}=Container
			    ->
				[Container|Acc];
			    _ ->
				Acc
			catch
			    exit:{timeout, Info} ->
				lager:warning("caught timeout ~p ~p~n", [Elem, Info]),
				Acc;
			    exit:{killed, Info} ->
				lager:warning("killed ~p ~p~n", [Elem, Info]),
				Acc
			end		
		end, [], Children).
    
%%------------------------------------------------------------------------------
%% @doc
%% Get containers from all nodes.
%%
%% @end
%%------------------------------------------------------------------------------    
-spec(cloud_containers() -> [#container{}]).
cloud_containers() ->
    {C,_} = rpc:multicall(container_sup, list_containers, []),
    lists:flatten(C).
    
%%------------------------------------------------------------------------------
%% @doc
%% Get containers from a given group
%%
%% @end
%%------------------------------------------------------------------------------    
-spec(get_container_group(Group::atom) -> [#container{}]).
get_container_group(Group) ->
    Containers = list_containers(),
    lists:filter(fun(#container{service=#service{group=G}}) ->
			 G =:= Group
		 end, Containers).

%%------------------------------------------------------------------------------
%% @doc
%% Get containers from docker daemon.
%%
%% @end
%%------------------------------------------------------------------------------
-spec(get_containers() -> {ok, [term()]} | {error, term()}).
get_containers() ->
    docker_container:containers().

%%------------------------------------------------------------------------------
%% @doc
%% In case the node was stopped or crashed, the running docker containers
%% should be cleaned up when the node comes back up.
%%
%% @end
%%------------------------------------------------------------------------------
-spec(cleanup() -> ok | [term()] | any()).
cleanup() ->
    Running = get_containers(),
    case Running of 
	{ok,[]} ->
	    Containers = container_storage:containers_for_node(erlang:node()),
	    case Containers of
		[] ->
		    lager:debug("Cleanup, nothing to do");
		_ ->
		    lists:foreach(fun(#container{id=CID}) ->					  
					  docker_container:stop(CID),
					  docker_container:delete(CID),
					  container_storage:remove_container(CID)
				  end, Containers)
	    end;
	{ok, L} ->
	    lists:foreach(fun(C) ->
				  CID = proplists:get_value('Id', C, undefined),
				  case CID of 
				      undefined ->
					  lager:warning("Unable to get Id for container~n");
				      _ ->
					  docker_container:stop(CID),
					  docker_container:delete(CID),
					  container_storage:remove_container(CID)
				  end
			  end, L);
	_ ->
	    lager:warning("Unexpected result from running containers ~p~n",[Running])
    end.
					      
	    
		
%%%===================================================================
%%% Internal functions
%%%===================================================================
