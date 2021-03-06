-record(port, {
	       host_port :: integer(),
	       container_port :: integer(),
	       name = undefined :: undefined | string() | binary(),
	       protocol = tcp :: tcp | upd,
	       random = false :: boolean()
	      }).
-record(healthcheck, {
		      cmd = undefined :: undefined | inherit| string(),
		      start_period = 0 :: integer(),
		      interval = 0 :: integer(),
		      timeout = 0 :: integer(),
		      retries = 0 :: integer(),
		      shell = false :: boolean()
		     }).
-record(service, {
		  id,
		  name :: string(),
		  image :: string(),
		  restart = never :: restart | never,
		  restart_count = 0 :: integer(),
		  privileged = false :: boolean(),
		  network_mode = <<"default">>,
		  pid_mode,
		  roles = [],
		  hosts = [],
		  cpus = 0.0 :: float(),
		  memory = 0.0 :: float(),
		  disk = 0.0 :: float(),
		  labels = [],
		  environment = [],
		  volumes = [],
		  ports = [] :: [#{} | #port{}],
		  args = [],
		  auto_remove = false :: boolean(),
		  group = undefined :: atom(),
		  group_role = undefined :: master|slave|undefined,
		  group_policy = undefined :: master_kills_all|one_kills_all|one_for_one|undefined,
		  healthcheck = undefined :: undefined | #healthcheck{}
		 }).
