#!/usr/bin/env bash
# Runs the real CoreDNS image with this Corefile and checks the synthesized answers.
# Usage: bash dns/test-synthesis.sh   (needs Docker; exits 1 on the first wrong answer)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE="$(grep -m1 'image: coredns/' "$DIR/dns-compose.yml" | awk '{print $2}')"
NET="coredns-test-$$"
NAME="coredns-test-$$"
ID="00000000-0000-4000-8000-000000000001"

cleanup() {
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    docker network rm "$NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$NET" >/dev/null
MSYS_NO_PATHCONV=1 docker run -d --name "$NAME" --network "$NET" \
    -v "$DIR/Corefile:/Corefile:ro" -v "$DIR/zones:/etc/coredns/zones:ro" \
    "$IMAGE" -conf /Corefile >/dev/null

# Each line: TYPE NAME EXPECTED (EXPECTED is the answer, or NODATA for NOERROR with no answer).
# SERVFAIL: a short form with more than 8 groups matches the pattern but is no IPv6 address.
CASES="
A    1-2-3-4.$ID.srv.nomercy.tv                                  1.2.3.4
A    192-168-1-10.$ID.srv.nomercy.tv                             192.168.1.10
AAAA 2001-db8-1-2-3-4-5-6.$ID.srv.nomercy.tv  2001:db8:1:2:3:4:5:6
AAAA 2001-0db8-0000-0000-0000-0000-0000-0001.$ID.srv.nomercy.tv  2001:db8::1
AAAA 2001-db8--1.$ID.srv.nomercy.tv                              2001:db8::1
AAAA 2001-db8-1--e8cd.$ID.srv.nomercy.tv                     2001:db8:1::e8cd
AAAA 2a02-a46-1--5-6-7.$ID.srv.nomercy.tv                         2a02:a46:1::5:6:7
AAAA 2001-db8--.$ID.srv.nomercy.tv                                2001:db8::
AAAA 1-2-3-4-5-6-7-8-9.$ID.srv.nomercy.tv                         NODATA
AAAA 1-2-3-4-5-6-7--8.$ID.srv.nomercy.tv                          SERVFAIL
AAAA 1-2-3-4.$ID.srv.nomercy.tv                                  NODATA
A    2001-db8-1-2-3-4-5-6.$ID.srv.nomercy.tv  NODATA
AAAA $ID.srv.nomercy.tv                                          NODATA
A    $ID.srv.nomercy.tv                                          NODATA
"

MSYS_NO_PATHCONV=1 docker run --rm -i --network "$NET" -e TARGET="$NAME" alpine:latest sh -s <<EOF
set -e
apk add -q --no-progress bind-tools >/dev/null
echo "$CASES" | while read -r type name want; do
    [ -z "\$type" ] && continue
    out=\$(dig +tries=3 +time=2 @"\$TARGET" "\$name" "\$type")
    status=\$(echo "\$out" | grep -o 'status: [A-Z]*' | cut -d' ' -f2)
    got=\$(dig +short +tries=3 +time=2 @"\$TARGET" "\$name" "\$type" | head -1)
    if [ "\$want" = SERVFAIL ]; then
        [ "\$status" = SERVFAIL ] && ok=1 || ok=0
    elif [ "\$want" = NODATA ]; then
        [ "\$status" = NOERROR ] && [ -z "\$got" ] && ok=1 || ok=0
    else
        [ "\$got" = "\$want" ] && ok=1 || ok=0
    fi
    if [ \$ok = 1 ]; then echo "PASS \$type \$name -> \${got:-NODATA}"; else echo "FAIL \$type \$name: want \$want, got '\$got' (\$status)"; echo x >> /tmp/failed; fi
done
[ ! -f /tmp/failed ]
EOF
echo "all synthesis cases pass"
