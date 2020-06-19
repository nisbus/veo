-module(container_builder_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/container.hrl").
%-export([service_parse_test/0]).

%% service_parse_test() ->
%%     application:start(yamerl),
%%     application:start(jsx),

%%     Services = settings:get_applications("/home/nisbus/code/volta/erlang/scheduler/volta_scheduler/apps/volta_scheduler/priv/cluster.yml"),
%%     Containers = lists:foldl(fun(Service, Acc) ->
%% 				     lists:append(Acc,[container_builder:build(Service)])
%% 			     end,[], Services),
%%     [First|_] = Containers, 
%%     ?assert(is_binary(First)).

%% inspect_parse_test() ->
%%     Service = #service{ports=[
%% 			      #port{host_port=500, container_port=90, name="port1", random=true},
%% 			      #port{host_port=0, container_port=80, name="website", random=true}
%% 			     ]
%% 	    },
%%     HostMode = container_builder:parse_inspect(inspect_host_mode_with_ports(),Service),
%%     ?assert(is_record(HostMode, service)),
%%     BridgeMode = container_builder:parse_inspect(inspect_bridge_mode_with_ports(), #service{ports=[
%% 												   #port{host_port=500, container_port=90, name="port1", random=true},
%% 												   #port{host_port=0, container_port=80, name="website", random=true}
%% 												  ]
%% 											   }
%% 						),
%%     ?assert(is_record(BridgeMode, service)).







inspect_host_mode_with_ports() ->
[{'Id',<<"6ce836b60dd7b68bce8b23f023c9206a0decb358af7634827f286a1756387377">>},
     {'Created',<<"2020-05-02T10:54:58.924927426Z">>},
     {'Path',<<"nginx">>},
     {'Args',[<<"-g">>,<<"daemon off;">>]},
     {'State',[{<<"Status">>,<<"running">>},
               {<<"Running">>,true},
               {<<"Paused">>,false},
               {<<"Restarting">>,false},
               {<<"OOMKilled">>,false},
               {<<"Dead">>,false},
               {<<"Pid">>,1230},
               {<<"ExitCode">>,0},
               {<<"Error">>,<<>>},
               {<<"StartedAt">>,<<"2020-05-02T10:54:59.706511632Z">>},
               {<<"FinishedAt">>,<<"0001-01-01T00:00:00Z">>}]},
     {'Image',<<"sha256:602e111c06b6934013578ad80554a074049c59441d9bcd963cb4a7feccede7a5">>},
     {'ResolvConfPath',<<"/var/lib/docker/containers/6ce836b60dd7b68bce8b23f023c9206a0decb358af7634827f286a1756387377/resolv.conf">>},
     {'HostnamePath',<<"/var/lib/docker/containers/6ce836b60dd7b68bce8b23f023c9206a0decb358af7634827f286a1756387377/hostname">>},
     {'HostsPath',<<"/var/lib/docker/containers/6ce836b60dd7b68bce8b23f023c9206a0decb358af7634827f286a1756387377/hosts">>},
     {'LogPath',<<"/var/lib/docker/containers/6ce836b60dd7b68bce8b23f023c9206a0decb358af7634827f286a1756387377/6ce836b60dd7b68bce8b23f023c9206a0decb358af7634827f286a1756387377-json.log">>},
     {'Name',<<"/nginx">>},
     {'RestartCount',0},
     {'Driver',<<"vfs">>},
     {'Platform',<<"linux">>},
     {'MountLabel',<<>>},
     {'ProcessLabel',<<>>},
     {'AppArmorProfile',<<>>},
     {'ExecIDs',null},
     {'HostConfig',[{<<"Binds">>,null},
                    {<<"ContainerIDFile">>,<<>>},
                    {<<"LogConfig">>,
                     [{<<"Type">>,<<"json-file">>},{<<"Config">>,[{}]}]},
                    {<<"NetworkMode">>,<<"host">>},
                    {<<"PortBindings">>,
                     [{<<"80/tcp">>,
                       [[{<<"HostIp">>,<<>>},{<<"HostPort">>,<<"43271">>}]]},
                      {<<"90/tcp">>,
                       [[{<<"HostIp">>,<<>>},{<<"HostPort">>,<<"500">>}]]}]},
                    {<<"RestartPolicy">>,
                     [{<<"Name">>,<<>>},{<<"MaximumRetryCount">>,0}]},
                    {<<"AutoRemove">>,false},
                    {<<"VolumeDriver">>,<<>>},
                    {<<"VolumesFrom">>,null},
                    {<<"CapAdd">>,null},
                    {<<"CapDrop">>,null},
                    {<<"Capabilities">>,null}, 
                    {<<"Dns">>,null},
                    {<<"DnsOptions">>,null},
                    {<<"DnsSearch">>,null},
                    {<<"ExtraHosts">>,null},
                    {<<"GroupAdd">>,null},
                    {<<"IpcMode">>,<<"private">>},
                    {<<"Cgroup">>,<<>>},
                    {<<"Links">>,null},
                    {<<"OomScoreAdj">>,0},
                    {<<"PidMode">>,<<>>},
                    {<<"Privileged">>,false},
                    {<<"PublishAllPorts">>,false},
                    {<<"ReadonlyRootfs">>,false},
                    {<<"SecurityOpt">>,null},
                    {<<"UTSMode">>,<<>>},
                    {<<"UsernsMode">>,<<>>},
                    {<<"ShmSize">>,67108864},
                    {<<"Runtime">>,<<"runc">>},
                    {<<"ConsoleSize">>,[0,0]},
                    {<<"Isolation">>,<<>>},
                    {<<"CpuShares">>,0},
                    {<<"Memory">>,10000000},
                    {<<"NanoCpus">>,0},
                    {<<"CgroupParent">>,<<>>},
                    {<<"BlkioWeight">>,0},
                    {<<"BlkioWeightDevice">>,null},
                    {<<"BlkioDeviceReadBps">>,null},
                    {<<"BlkioDeviceWriteBps">>,null},
                    {<<"BlkioDeviceReadIOps">>,null},
                    {<<"BlkioDeviceWriteIOps">>,null},
                    {<<"CpuPeriod">>,0},
                    {<<"CpuQuota">>,0},
                    {<<"CpuRealtimePeriod">>,0},
                    {<<"CpuRealtimeRuntime">>,0},
                    {<<"CpusetCpus">>,<<>>},
                    {<<"CpusetMems">>,<<>>},
                    {<<"Devices">>,null},
                    {<<"DeviceCgroupRules">>,null},
                    {<<"DeviceRequests">>,null},
                    {<<"KernelMemory">>,0},
                    {<<"KernelMemoryTCP">>,0},
                    {<<"MemoryReservation">>,0},
                    {<<"MemorySwap">>,-1},
                    {<<"MemorySwappiness">>,null},
                    {<<"OomKillDisable">>,false},
                    {<<"PidsLimit">>,null},
                    {<<"Ulimits">>,null},
                    {<<"CpuCount">>,1},
                    {<<"CpuPercent">>,0},
                    {<<"IOMaximumIOps">>,0},
                    {<<"IOMaximumBandwidth">>,0},
                    {<<"MaskedPaths">>,
                     [<<"/proc/asound">>,<<"/proc/acpi">>,<<"/proc/kcore">>,
                      <<"/proc/keys">>,<<"/proc/latency_stats">>,
                      <<"/proc/timer_list">>,<<"/proc/timer_stats">>,
                      <<"/proc/sched_debug">>,<<"/proc/scsi">>,
                      <<"/sys/firmware">>]},
                    {<<"ReadonlyPaths">>,
                     [<<"/proc/bus">>,<<"/proc/fs">>,<<"/proc/irq">>,
                      <<"/proc/sys">>,<<"/proc/sysrq-trigger">>]}]},
     {'GraphDriver',[{<<"Data">>,null},{<<"Name">>,<<"vfs">>}]},
     {'Mounts',[]},
     {'Config',[{<<"Hostname">>,<<"uno">>},
                {<<"Domainname">>,<<>>},
                {<<"User">>,<<>>},
                {<<"AttachStdin">>,false},
                {<<"AttachStdout">>,false},
                {<<"AttachStderr">>,false},
                {<<"ExposedPorts">>,[{<<"80/tcp">>,[{}]}]},
                {<<"Tty">>,false},
                {<<"OpenStdin">>,false},
                {<<"StdinOnce">>,false},
                {<<"Env">>,
                 [<<"PORT0=80">>,<<"NAMES=uno_dos">>,
                  <<"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin">>,
                  <<"NGINX_VERSION=1.17.10">>,<<"NJS_VERSION=0.3.9">>,
                  <<"PKG_RELEASE=1~buster">>]},
                {<<"Cmd">>,[<<"nginx">>,<<"-g">>,<<"daemon off;">>]},
                {<<"Image">>,<<"nginx:latest">>},
                {<<"Volumes">>,null},
                {<<"WorkingDir">>,<<>>},
                {<<"Entrypoint">>,null},
                {<<"OnBuild">>,null},
                {<<"Labels">>,
                 [{<<"LABEL">>,<<"SomeLabel">>},
                  {<<"maintainer">>,
                   <<"NGINX Docker Maintainers <docker-maint@nginx.com>">>}]},
                {<<"StopSignal">>,<<"SIGTERM">>}]},
     {'NetworkSettings',[{<<"Bridge">>,<<>>},
                         {<<"SandboxID">>,
                          <<"ee7838b3092cd75e95899981d11dae8d05ff8445ab5452f159a4b6766a418ba8">>},
                         {<<"HairpinMode">>,false},
                         {<<"LinkLocalIPv6Address">>,<<>>},
                         {<<"LinkLocalIPv6PrefixLen">>,0},
                         {<<"Ports">>,[{}]},
                         {<<"SandboxKey">>,
                          <<"/var/run/docker/netns/default">>},
                         {<<"SecondaryIPAddresses">>,null},
                         {<<"SecondaryIPv6Addresses">>,null},
                         {<<"EndpointID">>,<<>>},
                         {<<"Gateway">>,<<>>},
                         {<<"GlobalIPv6Address">>,<<>>},
                         {<<"GlobalIPv6PrefixLen">>,0},
                         {<<"IPAddress">>,<<>>},
                         {<<"IPPrefixLen">>,0},
                         {<<"IPv6Gateway">>,<<>>},
                         {<<"MacAddress">>,<<>>},
                         {<<"Networks">>,
                          [{<<"host">>,
                            [{<<"IPAMConfig">>,null},
                             {<<"Links">>,null},
                             {<<"Aliases">>,null},
                             {<<"NetworkID">>,
                              <<"57b8ad256f008b3a6d167281e0592279d47a84668d2d593fc5438bbdd35a2b72">>},
                             {<<"EndpointID">>,
                              <<"466f2394e78afd57ed3560789ac68f3c7a60366ee7adce76aa39bcc4de3e6f79">>},
                             {<<"Gateway">>,<<>>},
                             {<<"IPAddress">>,<<>>},
                             {<<"IPPrefixLen">>,0},
                             {<<"IPv6Gateway">>,<<>>},
                             {<<"GlobalIPv6Address">>,<<>>},
                             {<<"GlobalIPv6PrefixLen">>,0},
                             {<<"MacAddress">>,<<>>},
                             {<<"DriverOpts">>,null}]}]}]}].

inspect_bridge_mode_with_ports() ->
    [{'Id',<<"3329cf71242d62e91a363875cdd25201a9f70179624ce61e601fa4d5f18d3c96">>},
     {'Created',<<"2020-05-02T10:58:27.361162918Z">>},
     {'Path',<<"nginx">>},
     {'Args',[<<"-g">>,<<"daemon off;">>]},
     {'State',[{<<"Status">>,<<"running">>},
               {<<"Running">>,true},
               {<<"Paused">>,false},
               {<<"Restarting">>,false},
               {<<"OOMKilled">>,false},
               {<<"Dead">>,false},
               {<<"Pid">>,1085},
               {<<"ExitCode">>,0},
               {<<"Error">>,<<>>},
               {<<"StartedAt">>,<<"2020-05-02T10:58:28.28581563Z">>},
               {<<"FinishedAt">>,<<"0001-01-01T00:00:00Z">>}]},
     {'Image',<<"sha256:602e111c06b6934013578ad80554a074049c59441d9bcd963cb4a7feccede7a5">>},
     {'ResolvConfPath',<<"/var/lib/docker/containers/3329cf71242d62e91a363875cdd25201a9f70179624ce61e601fa4d5f18d3c96/resolv.conf">>},
     {'HostnamePath',<<"/var/lib/docker/containers/3329cf71242d62e91a363875cdd25201a9f70179624ce61e601fa4d5f18d3c96/hostname">>},
     {'HostsPath',<<"/var/lib/docker/containers/3329cf71242d62e91a363875cdd25201a9f70179624ce61e601fa4d5f18d3c96/hosts">>},
     {'LogPath',<<"/var/lib/docker/containers/3329cf71242d62e91a363875cdd25201a9f70179624ce61e601fa4d5f18d3c96/3329cf71242d62e91a363875cdd25201a9f70179624ce61e601fa4d5f18d3c96-json.log">>},
     {'Name',<<"/nginx">>},
     {'RestartCount',0},
     {'Driver',<<"vfs">>},
     {'Platform',<<"linux">>},
     {'MountLabel',<<>>},
     {'ProcessLabel',<<>>},
     {'AppArmorProfile',<<>>},
     {'ExecIDs',null},
     {'HostConfig',[{<<"Binds">>,null},
                    {<<"ContainerIDFile">>,<<>>},
                    {<<"LogConfig">>,
                     [{<<"Type">>,<<"json-file">>},{<<"Config">>,[{}]}]},
                    {<<"NetworkMode">>,<<"default">>},
                    {<<"PortBindings">>,
                     [{<<"80/tcp">>,
                       [[{<<"HostIp">>,<<>>},{<<"HostPort">>,<<"37401">>}]]},
                      {<<"90/tcp">>,
                       [[{<<"HostIp">>,<<>>},{<<"HostPort">>,<<"500">>}]]}]},
                    {<<"RestartPolicy">>,
                     [{<<"Name">>,<<>>},{<<"MaximumRetryCount">>,0}]},
                    {<<"AutoRemove">>,false},
                    {<<"VolumeDriver">>,<<>>},
                    {<<"VolumesFrom">>,null},
                    {<<"CapAdd">>,null},
                    {<<"CapDrop">>,null},
                    {<<"Capabilities">>,null},
                    {<<"Dns">>,null},
                    {<<"DnsOptions">>,null},
                    {<<"DnsSearch">>,null},
                    {<<"ExtraHosts">>,null},
                    {<<"GroupAdd">>,null},
                    {<<"IpcMode">>,<<"private">>},
                    {<<"Cgroup">>,<<>>},
                    {<<"Links">>,null},
                    {<<"OomScoreAdj">>,0},
                    {<<"PidMode">>,<<>>},
                    {<<"Privileged">>,true},
                    {<<"PublishAllPorts">>,false},
                    {<<"ReadonlyRootfs">>,false},
                    {<<"SecurityOpt">>,[<<"label=disable">>]},
                    {<<"UTSMode">>,<<>>},
                    {<<"UsernsMode">>,<<>>},
                    {<<"ShmSize">>,67108864},
                    {<<"Runtime">>,<<"runc">>},
                    {<<"ConsoleSize">>,[0,0]},
                    {<<"Isolation">>,<<>>},
                    {<<"CpuShares">>,0},
                    {<<"Memory">>,0},
                    {<<"NanoCpus">>,0},
                    {<<"CgroupParent">>,<<>>},
                    {<<"BlkioWeight">>,0},
                    {<<"BlkioWeightDevice">>,null},
                    {<<"BlkioDeviceReadBps">>,null},
                    {<<"BlkioDeviceWriteBps">>,null},
                    {<<"BlkioDeviceReadIOps">>,null},
                    {<<"BlkioDeviceWriteIOps">>,null},
                    {<<"CpuPeriod">>,0},
                    {<<"CpuQuota">>,0},
                    {<<"CpuRealtimePeriod">>,0},
                    {<<"CpuRealtimeRuntime">>,0},
                    {<<"CpusetCpus">>,<<>>},
                    {<<"CpusetMems">>,<<>>},
                    {<<"Devices">>,null},
                    {<<"DeviceCgroupRules">>,null},
                    {<<"DeviceRequests">>,null},
                    {<<"KernelMemory">>,0},
                    {<<"KernelMemoryTCP">>,0},
                    {<<"MemoryReservation">>,0},
                    {<<"MemorySwap">>,0},
                    {<<"MemorySwappiness">>,null},
                    {<<"OomKillDisable">>,false},
                    {<<"PidsLimit">>,null},
                    {<<"Ulimits">>,null},
                    {<<"CpuCount">>,0},
                    {<<"CpuPercent">>,0},
                    {<<"IOMaximumIOps">>,0},
                    {<<"IOMaximumBandwidth">>,0},
                    {<<"MaskedPaths">>,null},
                    {<<"ReadonlyPaths">>,null}]},
     {'GraphDriver',[{<<"Data">>,null},{<<"Name">>,<<"vfs">>}]},
     {'Mounts',[]},
     {'Config',[{<<"Hostname">>,<<"3329cf71242d">>},
                {<<"Domainname">>,<<>>},
                {<<"User">>,<<>>},
                {<<"AttachStdin">>,false},
                {<<"AttachStdout">>,false},
                {<<"AttachStderr">>,false},
                {<<"ExposedPorts">>,[{<<"80/tcp">>,[{}]}]},
                {<<"Tty">>,false},
                {<<"OpenStdin">>,false},
                {<<"StdinOnce">>,false},
                {<<"Env">>,
                 [<<"PORT0=80">>,<<"NAMES=uno_dos">>,
                  <<"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin">>,
                  <<"NGINX_VERSION=1.17.10">>,<<"NJS_VERSION=0.3.9">>,
                  <<"PKG_RELEASE=1~buster">>]},
                {<<"Cmd">>,[<<"nginx">>,<<"-g">>,<<"daemon off;">>]},
                {<<"Image">>,<<"nginx:latest">>},
                {<<"Volumes">>,null},
                {<<"WorkingDir">>,<<>>},
                {<<"Entrypoint">>,null},
                {<<"OnBuild">>,null},
                {<<"Labels">>,
                 [{<<"LABEL">>,<<"SomeLabel">>},
                  {<<"maintainer">>,
                   <<"NGINX Docker Maintainers <docker-maint@nginx.com>">>}]},
                {<<"StopSignal">>,<<"SIGTERM">>}]},
     {'NetworkSettings',[{<<"Bridge">>,<<>>},
                         {<<"SandboxID">>,
                          <<"ed4843878de6759b9fc0156dfeca46c5cec66dd3e533966915243df32a296a81">>},
                         {<<"HairpinMode">>,false},
                         {<<"LinkLocalIPv6Address">>,<<>>},
                         {<<"LinkLocalIPv6PrefixLen">>,0},
                         {<<"Ports">>,
                          [{<<"80/tcp">>,
                            [[{<<"HostIp">>,<<"0.0.0.0">>},
                              {<<"HostPort">>,<<"37401">>}]]}]},
                         {<<"SandboxKey">>,
                          <<"/var/run/docker/netns/ed4843878de6">>},
                         {<<"SecondaryIPAddresses">>,null},
                         {<<"SecondaryIPv6Addresses">>,null},
                         {<<"EndpointID">>,
                          <<"f879793cab15c5a38a69b90ad730750ed071d3fea3d741abc03e164e968e3cf3">>},
                         {<<"Gateway">>,<<"172.17.0.1">>},
                         {<<"GlobalIPv6Address">>,<<>>},
                         {<<"GlobalIPv6PrefixLen">>,0},
                         {<<"IPAddress">>,<<"172.17.0.2">>},
                         {<<"IPPrefixLen">>,16},
                         {<<"IPv6Gateway">>,<<>>},
                         {<<"MacAddress">>,<<"02:42:ac:11:00:02">>},
                         {<<"Networks">>,
                          [{<<"bridge">>,
                            [{<<"IPAMConfig">>,null},
                             {<<"Links">>,null},
                             {<<"Aliases">>,null},
                             {<<"NetworkID">>,
                              <<"be4bd2719c0f528311327e3027a12f555acb9945348f9a69c3f461b1d886122f">>},
                             {<<"EndpointID">>,
                              <<"f879793cab15c5a38a69b90ad730750ed071d3fea3d741abc03e164e968e3cf3">>},
                             {<<"Gateway">>,<<"172.17.0.1">>},
                             {<<"IPAddress">>,<<"172.17.0.2">>}, 
                             {<<"IPPrefixLen">>,16},
                             {<<"IPv6Gateway">>,<<>>},
                             {<<"GlobalIPv6Address">>,<<>>},
                             {<<"GlobalIPv6PrefixLen">>,0},
                             {<<"MacAddress">>,<<"02:42:ac:11:00:02">>},
                             {<<"DriverOpts">>,null}]}]}]}].
