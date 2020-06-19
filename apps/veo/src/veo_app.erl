%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2020, nisbus
%%% @doc
%%% The entry point for VEO.
%%%
%%% @end
%%% Created :  19 Jun 2020 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------

-module(veo_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).
-define(WAIT_FOR_RESOURCES, 2500).
%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% @doc
%% Starts VEO
%% @end
%%--------------------------------------------------------------------
start(_StartType, _StartArgs) ->
    node_monitor:start_link(),
    container_storage:create_container_table(),
    veo_sup:start_link().
    


%%--------------------------------------------------------------------
%% @doc
%% Stops VEO
%% @end
%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================

		     
