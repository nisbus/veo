# VEO

An OTP application

See the doc folder for an overview.

Build
-----

    $ rebar3 compile


OVERVIEW
--------

VEO is a Docker scheduler for running docker containers in a multi node environment.  
  
Getting started
---------------

### Local testing  
  
You can start a scheduler locally with `rebar3 shell --name=uno@uno`  
This will drop you into an Erlang shell connected to the local node.  
You can test reading the yaml config file into the shell to get some service definitions:  
`Apps = settings:get_applications().`  
To view the list just type `Apps.` and press enter.  
To get the first instance from the list you can use:  
`[First|Rest] = Apps.`  
This will leave you with a single service definition in the First variable.  
The Rest variable will container the rest of the list (you can repeat this with [Second|Rest2] = Rest. etc).  
if you know the length of the list you can also just do:  
`[F,S,T] = Apps.` (for a list of 3) so you have each service in a variable.  
Now try starting a service:  
`container_sup:add_service(First).`  
This will try and start a container and you will see the log output in the console as well.  

### Multiple nodes  
  
To run the test environment use `make multiple` from the root directory.  
This will start two containers running the scheduler and they will be connected to each other.  
  
exec into each one using `docker exec -it uno bash` and `docker exec -it dos bash`.  
inside the containers pull down the nginx imgage `docker pull nginx`.  
  
Attach to the running schedulers using `./_build/default/rel/veo/bin/veo attach`.  
  
copy and paste the following into the running shell:  
  
`cd(code:priv_dir(veo)). cd("../include"). rr("service.hrl"). SM=#service{image="nginx", group="web", group_role=master, group_policy=master_kills_all}. SL=SM#service{group_role=slave}. H = SM#service{healthcheck=#healthcheck{cmd="curl --fail http://localhost:80 || exit 1"}}.`  
  
You are now ready to start some containers.  
  
`container_sup:add_service(SM).` This starts an nginx container which is in the group "web" and has the group_role master.  
`container_sup:add_service(SL).` This starts an nginx container which is in the group "web" and has the group_role slave.  
  
Both containers will be started in the node the master started on because they share the same group.  
Both also have the group_policy=master_kills_all.  
This means that if the master container dies, the scheduler will kill all containers in the same group.  
  
You can try this by doing `docker kill <master_id>` from the shell of the node that has the containers.  
  
Start the third container which also has healthcheck enabled.  
`container_sup:add_service(H)` This starts a new nginx container which is not in any group but has a healthcheck enabled.  
Notice that the node that has the container will print out the status of the container every 5 seconds.  

You are now ready to play with different kinds of services using the service record.  
  
> `#service{image=SomeImage, restart=never/restart, restart_count=integer, privileged=false/true, network_mode=<<"host">>/<<"default">>, pid_mode=undefined/<<"host">>, cpus=integer, memory=integer, disk=integer}`.  
  
You can see all of the properties of a service in the apps/veo/include/service.hrl file.  


Config file (WIP)
-----------------
In the apps/veo/include/priv folder you will find a cluster.yml defining the cluster.  
This file is copied into each container (to have different files per node you would have to map them to the containers).  
  
The structure of the file is very similar to a docker-compose file.  
  
It starts with a list of nodes in the cluster.  
Each node element is of the format:  
  
  ```
  -node: name@hostname
   role: free text
  ```  
  
The role can be used to restrict services to only run on specific role nodes.  
  
After the node definitions there are the services.  
  
Services have the same format for the most part as docker-compose.  
Additional properties are:  
  
* roles: A list of roles the service is allowed to run on (not defined = any node).
* hosts: A list of nodes the service is constrained to.  
* group: A free text group for the service (Services in the same group will always be sent to the same node).  
* group_role: Either master or slave, the group policy dictiates what this means.  
* group_policy:  One of master_kills_all/one_kills_all/one_for_one.  
                 master_kills_all: If a service with a group_role of master dies, all services in the group are killed/restarted.  
				 one_kills_all: If any service within a group dies, all services in the group are killed/restarted.  
				 one_for_one: If any service within a group dies, only that service is killed/restarted.  
* restart: One of never/restart. never means the service is never restarted while restart will continue to try and keep the service alive.
* restart_count: if the restart = restart, the service is restarted up until the restart count is reached. After that it is killed.
  
You can test the config file by changing the services in the default one.  
If you only have one service get the definition into the shell of the attached application:  
`[S] = settings:get_applications().`  
  
S is now the service record you can try and start like before:  
`container_sup:add_service(S).`  
  
In case you have more than one service in your cluster.yml you need to filter the list to get the service you want, see lists:filter in the Erlang documentation.  
  
  
TODO
----
  
Testing of various options is not done yet. 
  
* HealthChecks

These need to be tested for parsing correctly to a docker acceptable JSON.  
  
* Define actions to take on unhealthy containers (kill/restart/leave).  

### Websockets
Activate and define the websocket subscriptions for different state changes.  
  
* Subscribe to state changes for a specific container
* Subscribe to state changes for all containers (multi-node??).
* Subscribe to events (service started, ready, restarted, killed) per container/node/cluster.
  
### REST API
Define the API to interact with the cluster.  
* Add service  
* Delete service  
* Add node  
* Remove node  
* Get container info (all/single)  
  

### UI
Connect the UI to the websockets connection and display the status of the cluster.  
* Resources (per node and total).
* Containers (location, status).
* Add commands for the REST API.  



