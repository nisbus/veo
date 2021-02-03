-record(memory,
	{
	 used = 0.0,
	 available = 0.0,
	 total = 0.0
	}
       ).
-record(disk, 
	{
	 used = 0.0,
	 available = 0.0,
	 total = 0.0
	}
       ).
-record(cpu,
	{count = 0,
	 used = 0.0,
	 available = 0.0
	}).
