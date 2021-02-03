-include("../include/service.hrl").
%% @headerfile
-record(container_memory,
	{
	 used = 0.0,
	 available = 0.0,
	 total = 0.0
	}
       ).
-record(container_cpu,
	{count = 0,
	 used = 0.0,
	 available = 0.0
	}).

-record(stats, {
		timestamp,
		cpu = #container_cpu{},
		memory = #container_memory{}
	       }).

-record(container, {
		    id:: binary(),
		    logs = [],
		    restart_counter = -1:: integer(),
		    service = #service{} :: #service{},
		    pid:: pid(),
		    status,
		    ip_address,
		    port_maps,
		    node,
		    stats = #stats{} :: #stats{}
		   }).
