#!/bin/bash
# infra/nomercy-stack/scripts/provision-docker-daemon-logging.sh
#
# Installs the repo's docker/daemon.json as /etc/docker/daemon.json so the
# json-file log driver is capped (max-size 20m x max-file 5 = 100MB/container)
# instead of Docker's unbounded default. This is the global backstop: it
# covers every container on the host, including ones outside this compose
# stack (e.g. the coredns/txt-updater DNS containers).
#
# Idempotent: only writes + restarts docker if the installed file differs
# from the repo's copy. Restarting the docker daemon briefly stops every
# container on the host; compose services with `restart: unless-stopped`
# come back on their own.
#
# Run on the target host as root:
#   /opt/nomercy-stack/scripts/provision-docker-daemon-logging.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/docker/daemon.json"
DEST="/etc/docker/daemon.json"

if [ ! -f "$SRC" ]; then
    echo "ERROR: $SRC not found" >&2
    exit 1
fi

if [ -f "$DEST" ] && cmp -s "$SRC" "$DEST"; then
    echo "OK: $DEST already matches $SRC, nothing to do"
    exit 0
fi

install -m 0644 "$SRC" "$DEST"
echo "Installed $SRC -> $DEST"

systemctl restart docker
echo "Restarted docker.service"

echo "Waiting for docker to come back..."
for i in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
        echo "docker is up"
        break
    fi
    sleep 1
done

docker info >/dev/null 2>&1 || { echo "ERROR: docker did not come back up" >&2; exit 1; }
