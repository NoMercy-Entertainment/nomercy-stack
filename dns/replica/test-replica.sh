#!/usr/bin/env bash
# Compares a replica name server with the reference one (ns1-style answers).
#
#   bash dns/replica/test-replica.sh REF_IP REPLICA_IP     compare two running servers
#   bash dns/replica/test-replica.sh --local               build a throw-away pair and compare them
#
# Optional for the first form: PLANT_URL=http://ns1-host:8081/txt PLANT_TOKEN=... also plants a TXT.
# Needs Docker. Uses made-up ids and documentation addresses only.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
DNS_DIR="$(dirname "$DIR")"

if [ "${1:-}" != "--local" ]; then
    [ $# -eq 2 ] || { echo "usage: $0 REF_IP REPLICA_IP | --local"; exit 2; }
    MSYS_NO_PATHCONV=1 docker run --rm -i -e PLANT_URL="${PLANT_URL:-}" -e PLANT_TOKEN="${PLANT_TOKEN:-}" \
        -v "$DIR/compare.sh:/compare.sh:ro" alpine:3.20 sh /compare.sh "$1" "$2"
    exit $?
fi

PROJECT="ns2test$$"
NET="${PROJECT}_default"
WORK="${NS2_TEST_TMP:-$(mktemp -d)}"
TOKEN="local-test-token-$$"
IMAGE="$(grep -m1 'image: coredns/' "$DNS_DIR/dns-compose.yml" | awk '{print $2}')"

cleanup() {
    docker rm -f upstream ref-ns1 >/dev/null 2>&1 || true
    (cd "$DIR" && DNS_BIND_IP=127.0.0.1 TXT_UPDATER_TOKEN=x docker compose -p "$PROJECT" -f replica-compose.yml down -v >/dev/null 2>&1) || true
    rm -rf "$DIR/zones"
}
trap cleanup EXIT

# Upstream zone (what ns1 serves) and the replica's starting copy.
mkdir -p "$WORK/up" "$DIR/zones"
cp "$DNS_DIR/zones/dynamic.db" "$WORK/up/dynamic.db"
cp "$DNS_DIR/zones/dynamic.db" "$DIR/zones/dynamic.db"
chmod 666 "$WORK/up/dynamic.db" "$DIR/zones/dynamic.db"

# Replica: only coredns + zone-sync; the ssh tunnel is replaced by a direct URL to the throw-away upstream.
(cd "$DIR" && DNS_BIND_IP=127.0.0.1 DNS_PORT=5354 TXT_UPDATER_TOKEN="$TOKEN" ZONE_URL=http://upstream:8081/zone \
    docker compose -p "$PROJECT" -f replica-compose.yml up -d --no-deps coredns zone-sync)

docker build -q -t ns2-test-txt-updater "$DNS_DIR/txt-updater" >/dev/null
MSYS_NO_PATHCONV=1 docker run -d --name upstream --network "$NET" -e TXT_UPDATER_TOKEN="$TOKEN" \
    -e ZONE_PATH=/zones/dynamic.db -v "$WORK/up:/zones" ns2-test-txt-updater >/dev/null
MSYS_NO_PATHCONV=1 docker run -d --name ref-ns1 --network "$NET" \
    -v "$DNS_DIR/Corefile:/Corefile:ro" -v "$WORK/up:/etc/coredns/zones:ro" "$IMAGE" -conf /Corefile >/dev/null

sleep 8
MSYS_NO_PATHCONV=1 docker run --rm -i --network "$NET" -e PLANT_URL=http://upstream:8081/txt -e PLANT_TOKEN="$TOKEN" \
    -v "$DIR/compare.sh:/compare.sh:ro" alpine:3.20 sh /compare.sh ref-ns1 coredns-replica
