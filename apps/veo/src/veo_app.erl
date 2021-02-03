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
    create_metrics(),
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
create_metrics() ->
    folsom_metrics:new_meter(veo_stats_calls),
    folsom_metrics:new_meter(veo_stats_failures),
    folsom_metrics:new_meter(veo_rest_success),
    folsom_metrics:new_meter(veo_rest_failures),
    folsom_metrics:new_meter(veo_rest_errors),
    folsom_metrics:new_meter(veo_started_containers),
    folsom_metrics:new_meter(veo_restarted_containers),
    folsom_metrics:new_meter(veo_stopped_containers),
    folsom_metrics:new_meter(veo_failed_containers).

		     
