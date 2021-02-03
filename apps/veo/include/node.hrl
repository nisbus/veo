-include("../include/resources.hrl").
-record(allocation,
	{
	 cpu = 0,
	 disk = 0,
	 memory = 0
	}).
-record(node_state, 
	{
	 node,
	 roles = [],
	 memory = #memory{},
	 cpu = #cpu{},
	 disk = #disk{},
	 allocated = #allocation{},
	 connected = []
	}).
