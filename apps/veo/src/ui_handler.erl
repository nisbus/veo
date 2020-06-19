%%% @hidden
%%% @author nisbus <nisbus@gmail.com>
%%% @copyright (C) 2020, nisbus
%%% @doc
%%% A specific handler to serve the UI
%%%
%%% @end
%%% Created :  19 Jun 2020 by nisbus <nisbus@gmail.com>
%%%-------------------------------------------------------------------
-module(ui_handler).
-behaviour(cowboy_rest).
-export([
	 init/2,
	 allowed_methods/2,
	 content_types_accepted/2,
	 content_types_provided/2,
	 resource_exists/2]).

init(Req0, State) ->
    Containers = container_sup:list_containers(),

    C = lists:map(fun(X) ->
		      proplists:get_value(<<"name">>, X)
	      end, Containers),
    {state,
     {memory, UseMem, AvailMem, TotalMem}, 
     {cpu, CpuCount, CpuUse, CpuAvail}, 
     {disk, UseDisk, AvailDisk, TotalDisk}
    } = node_monitor:get_resources(),
    C0 = [{<<"containers">>, C}, 
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
	 ],
    Response = jsx:encode(C0),
    Req = cowboy_req:reply(200,
			   #{<<"content-type">> => <<"application/json">>},
			   Response,
			   Req0),
    {ok, Req, State}.

content_types_accepted(Req, State) ->
    {[{<<"application/json">>, handle_get}], Req, State}.

content_types_provided(Req, State) ->
    {[{<<"application/json">>, handle_get}], Req, State}.    

allowed_methods(Req, State) ->
    {[<<"GET">>, <<"OPTIONS">>], Req, State}.

resource_exists(Req, State) ->
    {true, Req, State}.
