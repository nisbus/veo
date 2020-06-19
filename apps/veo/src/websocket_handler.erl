%%% @hidden
%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2020, nisbus
%%% @doc
%%% Handler for streaming via websockets.
%%% Currently streams nodes resources and containers for the UI only
%%%
%%% @end
%%% Created :  19 Jun 2020 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(websocket_handler).
-export([init/2]).
-export([websocket_init/1]).
-export([websocket_handle/2]).
-export([websocket_info/2]).


-include("../include/gproc.hrl").
-include("../include/container.hrl").
-include("../include/node.hrl").
-define(SERVER, ?MODULE).

-record(client_state, {
	  ping_timer      :: reference(),

	  %% mailbox_size_timer is fired periodically and
	  %% causes the ws_handler process to terminate
	  %% if it's mailbox is excessively large.
	  mailbox_size_timer :: reference() | undefined,

	  no_of_messages=0 :: integer()
	 }).

init(Req, Opts) ->
    {cowboy_websocket, Req, Opts}.

websocket_init(_State) ->
    Interval = 25000,
    gproc:reg(?INFO_SUBSCRIPTION()),     
    timer:send_interval(1000, info_changed),
    {ok, #client_state{ping_timer = create_ping_timer(Interval)}}.

%% Doc
%% Handler for incoming messages
websocket_handle({text, Msg}, State) ->
    lager:info("Received request ~p~n",[Msg]),
    {reply, {text, Msg}, State};

websocket_handle(pong, State) ->
    {ok, State};
websocket_handle(_Data, State) ->
    lager:info("received handle ~p~n",[_Data]),
    {ok, State}.


websocket_info(info_changed, #client_state{no_of_messages = N} = State) ->
    Containers = container_sup:cloud_containers(),
    {Resources,_} = rpc:multicall(node_monitor,get_resources,[]),
    C0 = lists:map(fun(R) ->
			   case is_record(R, node_state) of
			       true ->
				   NodeName = R#node_state.node,
				   NodeContainers = lists:filter(fun(#container{node=CN}) ->
									 CN =:= NodeName
								 end, Containers),
				   node_state_to_json(R, NodeContainers);
			       false ->
				   node_state_to_json(undefined, [])
			   end
		   end, Resources),		     		      
    Response = jsx:encode(C0),
    {reply, {text, Response}, State#client_state{no_of_messages = N+1}};

%% Ping the client.
websocket_info({timeout, TimerRef, {ping, IntervalMs}}, #client_state{ping_timer = TimerRef} = State) ->
    {reply, ping, State#client_state{ping_timer = create_ping_timer(IntervalMs)}};

websocket_info({timeout, _Ref, Msg}, State) ->
    {reply, {text, Msg}, State};

websocket_info(_Info, State) ->
    lager:debug("received info ~p~n",[_Info]),
    {ok, State}.

-spec create_ping_timer(integer()) -> reference().
create_ping_timer(IntervalMs) ->
    erlang:start_timer(IntervalMs, self(), {ping, IntervalMs}).

node_state_to_json(undefined,[]) ->
    [{<<"node">>, <<"unreachable">>},
     {<<"containers">>, []}, 
     {<<"resources">>, 
      [
       {<<"memory">>, 
	[
	 {<<"total">>, 0.0},
	 {<<"used">>, 0.0},
	 {<<"available">>, 0.0}
	]
       },
       {<<"cpu">>,
	[
	 {<<"count">>, 0.0},
	 {<<"used">>, 0.0},
	 {<<"available">>, 0.0}
	]
       },
       {<<"disk">>,
	[
	 {<<"total">>, 0.0},
	 {<<"used">>, 0.0},
	 {<<"available">>, 0.0}
	]
       }
      ]
     }
    ];
    
node_state_to_json(#node_state{memory=#memory{
					used=UseMem, available=AvailMem, total=TotalMem}, 
			      cpu=#cpu{count=CpuCount, used=CpuUse, available=CpuAvail}, 
			      disk=#disk{used=UseDisk, available=AvailDisk, total=TotalDisk},
			      node=N}, Containers) ->
    C = lists:map(fun(#container{service=#service{name=CN}}) ->
			  list_to_binary(CN)
		  end, Containers),
    [{<<"node">>, N},
     {<<"containers">>, C}, 
     {<<"resources">>, 
      [
       {<<"memory">>, 
	[
	 {<<"total">>, TotalMem},
	 {<<"used">>, UseMem},
	 {<<"available">>, AvailMem}
	]
       },
       {<<"cpu">>,
	[
	 {<<"count">>, CpuCount},
	 {<<"used">>, CpuUse},
	 {<<"available">>, CpuAvail}
	]
       },
       {<<"disk">>,
	[
	 {<<"total">>, TotalDisk},
	 {<<"used">>, UseDisk},
	 {<<"available">>, AvailDisk}
	]
       }
      ]
     }
    ].
