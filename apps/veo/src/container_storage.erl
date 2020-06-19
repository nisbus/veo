%%%-------------------------------------------------------------------
%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2020, nisbus
%%% @doc
%%% Container storage for mnesia
%%% Manages the containers and their nodes in mnesia.
%%% All nodes share this state for containers.
%%% 
%%% @end
%%% Created :  19 Jun 2020 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(container_storage).
-include("../include/container.hrl").
-export([
	 create_container_table/0,
	 save_container/1,
	 ensure_mnesia_started/0,
	 containers_for_node/1,
	 containers_by_service_name/1,
	 container_by_id/1,
	 remove_container/1]).
-ifdef(EUNIT).
-define(COPIES, ram_copies).
-else.
-define(COPIES, disc_copies).
-endif.

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Creates the container table or copies it from other nodes if they
%% are connected.
%% @end
%%--------------------------------------------------------------------
-spec(create_container_table() -> ok | {error, Reason :: term()} | {timeout, [term()]}).
create_container_table() ->
    ok = ensure_mnesia_started(),
    Connected = nodes(),
    case Connected of
	[] ->
	    case mnesia:create_table(containers,
				     [{attributes, record_info(fields, container)},
				      {record_name, container},

				      {?COPIES, [node()]},
				      {type, bag}
				     ]) of
		{aborted, {already_exists, containers}} ->
		    ok;
		{atomic, ok} ->
		    ok;
		Error ->
		    Error
	    end;
	_ ->	    
	    mnesia:change_config(extra_db_nodes, Connected),
	    mnesia:wait_for_tables([containers], 5000)
    end.

%%--------------------------------------------------------------------
%% @doc
%% Writes a container record to the storage
%% @end
%%--------------------------------------------------------------------
-spec(save_container(Container::#container{}) -> ok|{error,term()}).
save_container(#container{} = Container) ->
    Write = fun() ->
		    mnesia:write(containers, Container, write) 
	    end,
    case mnesia:activity(transaction, Write) of
	ok ->
	    ok;
	Error ->
	    {error, Error}
    end.

%%--------------------------------------------------------------------
%% @doc
%% Gets all containers for a given node
%% @end
%%--------------------------------------------------------------------
-spec(containers_for_node(Node::atom()) -> ok|{error,term()}).    
containers_for_node(Node) ->
    Match = fun() ->
		    mnesia:match_object(containers, #container{_ = '_', node=Node}, read)
	    end,
    mnesia:activity(transaction, Match).

%%--------------------------------------------------------------------
%% @doc
%% Gets a container from it's ID
%% @end
%%--------------------------------------------------------------------
-spec(container_by_id(ID::binary()) -> ok|{error,term()}).    		       
container_by_id(ID) ->
    Match = fun() ->
		    mnesia:match_object(containers, #container{_ = '_', id=ID}, read)
	    end,
    mnesia:activity(transaction, Match).

%%--------------------------------------------------------------------
%% @doc
%% Gets a container by the service name
%% @end
%%--------------------------------------------------------------------
-spec(containers_by_service_name(Name::string()) -> ok|{error,term()}).    		       
containers_by_service_name(Name) ->
    Match = fun() ->
		    mnesia:match_object(containers, #container{_ = '_', service=#service{name=Name}}, read)
	    end,
    mnesia:activity(transaction, Match).

%%--------------------------------------------------------------------
%% @doc
%% Remove a container from the storage
%% @end
%%--------------------------------------------------------------------    
-spec(remove_container(ContainerID::binary()) -> ok|{error,term()}).
remove_container(ContainerID) ->    
    Delete = fun() ->
		    mnesia:delete({containers, ContainerID})
	    end,
    mnesia:activity(transaction, Delete).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Checks if mnesia is started, if not if starts mnesia.
%% @end
%%--------------------------------------------------------------------    
-spec ensure_mnesia_started() -> ok | {error, any()}.
ensure_mnesia_started() ->
  case application:start(mnesia) of
    ok ->
      ok;
    {error,{already_started, mnesia}} ->
      ok;
    {error, Reason} ->
      {error, Reason}
  end.
