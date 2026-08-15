#!/bin/sh
# entrypoint-dind.sh
# Starts a private dockerd inside the sandbox container (meant to run under
# the Sysbox runtime), then hands off to the original open-terminal
# entrypoint. No host docker.sock is mounted or expected.
set -e

# Clean up a stale pidfile left over from a previous crashed/restarted
# instance of this container. Without this, dockerd refuses to start with
# "failed to start daemon...ensure docker is not running or delete
# /var/run/docker.pid" even though no dockerd process is actually alive
# in the current PID namespace.
sudo rm -f /var/run/docker.pid

if sudo docker version >/dev/null 2>&1; then
  echo "[entrypoint-dind] dockerd already running, skipping start"
else
  echo "[entrypoint-dind] starting private dockerd..."
  sudo dockerd --host=unix:///var/run/docker.sock &

  # Wait for the daemon socket to become available (max ~30s)
  for i in $(seq 1 30); do
    if sudo docker version >/dev/null 2>&1; then
      echo "[entrypoint-dind] dockerd is ready"
      break
    fi
    sleep 1
  done

  if ! sudo docker version >/dev/null 2>&1; then
    echo "[entrypoint-dind] ERROR: dockerd did not become ready in time" >&2
    exit 1
  fi
fi

echo "[entrypoint-dind] handing off to open-terminal entrypoint..."
exec /app/entrypoint.sh run
