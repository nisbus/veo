%%% @hidden
%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2020, nisbus
%%% @doc
%%% The main supervisor.
%%% Starts the web server and the container supervisor.
%%%
%%% @end
%%% Created :  19 Jun 2020 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(veo_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).
-define(CHILD(I, Type, Args), {I, {I, start_link, Args}, permanent, infinity, Type, [I]}).
%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    Dispatch = cowboy_router:compile([
    				      {'_', 
    				       [
    					{"/", cowboy_static, {priv_file, veo, "veo-ui/dist/veo-ui/index.html"}},
    					{"/data", ui_handler,[]},
					{"/api/container/:container", rest_api_handler, [container]},
					{"/api/container", rest_api_handler, [container]},
					{"/api/containers", rest_api_handler, [containers]},
					{"/api/containers/:node", rest_api_handler, [containers]},
					{"/api/containers/stop/:container", rest_api_handler, [stop]},
					{"/api/nodes/:node", rest_api_handler, [nodes]},
					{"/api/nodes", rest_api_handler, [nodes]},
					{"/api/resources", rest_api_handler, [resources]},
					{"/api/metrics", rest_api_handler, [metrics]},
    					{"/websocket", websocket_handler, []},
    					{"/[...]", cowboy_static, {priv_dir, veo, "veo-ui/dist/veo-ui"}}
    				       ]}]),
    {ok, _} = cowboy:start_clear(veo_http_listener,
        [{port, 8086}],
        #{env => #{dispatch => Dispatch}}
    ),
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: #{id => Id, start => {M, F, A}}
%% Optional keys are restart, shutdown, type, modules.
%% Before OTP 18 tuples must be used to specify a child. e.g.
%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    {ok, {{one_for_all, 0, 1}, [?CHILD(container_sup, supervisor, [])
			       ]}}.
%			       ,?CHILD(container_sync, worker, [])

%%====================================================================
%% Internal functions
%%====================================================================
