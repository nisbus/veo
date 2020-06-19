-include("../include/service.hrl").
%% @headerfile
-record(container, {
		    id:: binary(),
		    logs = [],
		    restart_counter = -1:: integer(),
		    service = #service{} :: #service{},
		    pid:: pid(),
		    status,
		    ip_address,
		    port_maps,
		    node
		   }).
