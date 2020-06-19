# VEO
  
VEO is a docker container scheduler with built in DNS.  
  
This is a masterless cluster which syncs via Erlang OTP node connections and syncs data using
Mnesia.
  
## documentation   
  
https://nisbus.github.io/veo/  
  
## Getting started  
   
The makefile is the best way to get started with VEO.  
  
`make start` : Starts a single instance of VEO on your local machine.  
  
`make multiple` : Starts two instances of VEO in separate docker containers.  
  
`make three` : Starts three instances of VEO in separate docker containers.  
  
The default cluster.yml (in apps/veo/priv) defines two nodes (uno and dos) which both have the role of master.  
  
It also defines two services (using the nginx container) one in host network mode and other in bridge mode.  
  
If you use start or three with the makefile you should edit the cluster.yml to either remove one host or add the third.  
  
  
## Getting the nodes ready
  
This guide assumes you started with make multiple so you now have two containers running VEO (uno and dos).  
  
Start two separate shells and exec into the containers:  
  
```bash
docker exec -it uno bash
```  
  
```bash
docker exec -it dos bash
```  
  
Now you need to get the nginx image into both containers via docker, so in both run:  
  
```bash
docker pull nginx
```
  
Change the resolv.conf to point to localhost:   
```
echo "nameserver 127.0.0.1" > /etc/resolv.conf
```  
  
You are now ready to attach to the shell of VEO in each container: 
```bash
./_build/default/rel/veo/bin/veo attach
```
  
### Starting containers  
  
inside the shell type the following:   
```erlang
[H|[T]] = settings:get_applications().
```  
  
You now have the parsed definitions of the two nginx containers specified in the cluster.yml.  
   
To start a container type   
```erlang
container_sup:add_service(T).
```  
  
You will see one of the nodes starting an nginx container in host mode.  

### Verifying the cluster state and DNS  
  
Now that you have a container running we can verify that it is actually there and registered with the DNS in both nodes.  
  
Exit the attached shells in both nodes (`CTRL+d`) * NOTE: CTRL+c will stop the node) *  
  
In the shell of both of the nodes type   
```bash
dig ngnix.veo'
```  
  
This should return an A record with the IP of the node that is running the nginx service.  
  
The default configuration file specifies two ports for the nginx service, one is 500 and called port1 and the other one is randomly assigned and bound to nginx port 80 (called website).  
  
You can verify this as well with the DNS:  
  
```bash
dig _website._tcp.nginx.veo SRV
```  
will show you the port assigned to the nginx container.
  
```bash
curl website.nginx.veo:<PORT FROM SRV QUERY>
```  
Should show `Welcome to ngnix!'.
  
  
# Have FUN!  
  
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
* Add commands for the REST API.  



