#!/bin/sh
epmd -daemon
dockerd -H unix:///var/run/docker.sock -H tcp://0.0.0.0 &&
./_build/default/rel/veo/bin/veo start
