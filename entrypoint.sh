#!/usr/bin/env bash
# Entry point to launch supervidord if no args are present
# or run any other command
# See https://github.com/fr3nd/docker-supervisor/blob/master/entrypoint.sh
set -e

# Redirects SIGTERM from the entrypoint to the wrapper.
# (Mesos sends a SIGTERM to kill containers and the wrapper needs to receive
# it to perform cleanup operations). See:
# https://unix.stackexchange.com/questions/146756/forward-sigterm-to-child-in-bash/146770#146770

epmd -daemon

_term() {
  echo "Caught SIGTERM signal!"
  kill -TERM "$child" 2>/dev/null
  wait "$child"
}

trap _term SIGTERM

if [ -z "$@" ]; then
  /usr/bin/supervisord -c /etc/supervisor/supervisord.conf --nodaemon &
else
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin $@ &
fi

child=$!
wait "$child"
