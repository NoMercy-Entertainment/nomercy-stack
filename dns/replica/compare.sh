#!/bin/sh
# Runs inside an alpine container (see test-replica.sh).
# Usage: compare.sh REF_SERVER REPLICA_SERVER
# Optional env: PLANT_URL + PLANT_TOKEN plant a TXT through ns1's txt-updater and wait for it on the replica.
set -u
REF="$1"
REPLICA="$2"
ID="00000000-0000-4000-8000-000000000001"
FAIL=0

# status<TAB>answer lines<TAB>authority lines, sorted, so two servers can be compared as text.
shape() {
    server="$1"; name="$2"; type="$3"
    status=$(dig +tries=3 +time=2 @"$server" "$name" "$type" | grep -o 'status: [A-Z]*' | cut -d' ' -f2)
    sections=$(dig +tries=3 +time=2 +noall +answer +authority @"$server" "$name" "$type" | sort)
    printf '%s\n%s\n' "$status" "$sections"
}

check_same() {
    type="$1"; name="$2"
    a=$(shape "$REF" "$name" "$type")
    b=$(shape "$REPLICA" "$name" "$type")
    if [ "$a" = "$b" ]; then
        echo "PASS same $type $name -> $(echo "$b" | sed -n 1p) $(echo "$b" | sed -n 2p | awk '{print $NF}')"
    else
        echo "FAIL differ $type $name"; echo "  ref:     $a"; echo "  replica: $b"; FAIL=1
    fi
}

apk add -q --no-progress bind-tools curl >/dev/null

check_same A    "192-0-2-10.$ID.srv.nomercy.tv"
check_same A    "192-168-1-10.$ID.srv.nomercy.tv"
check_same AAAA "2001-db8-1-2-3-4-5-6.$ID.srv.nomercy.tv"
check_same AAAA "2001-db8--1.$ID.srv.nomercy.tv"
check_same AAAA "2001-db8-1--e8cd.$ID.srv.nomercy.tv"
check_same AAAA "2001-db8--.$ID.srv.nomercy.tv"
check_same A    "$ID.srv.nomercy.tv"
check_same AAAA "$ID.srv.nomercy.tv"
check_same NS   "$ID.srv.nomercy.tv"
check_same A    "2001-db8-1-2-3-4-5-6.$ID.srv.nomercy.tv"
check_same SOA  "srv.nomercy.tv"

# The apex NS set is the one deliberate difference: ns1 alone on the reference, ns1 + ns2 on the replica.
ref_ns=$(dig +short @"$REF" srv.nomercy.tv NS | sort | tr '\n' ' ')
rep_ns=$(dig +short @"$REPLICA" srv.nomercy.tv NS | sort | tr '\n' ' ')
case "$rep_ns" in
    "ns1.nomercy.tv. ns2.nomercy.tv. ") echo "PASS apex NS replica: $rep_ns (reference: $ref_ns)" ;;
    *) echo "FAIL apex NS replica: '$rep_ns' (reference: '$ref_ns')"; FAIL=1 ;;
esac

if [ -n "${PLANT_URL:-}" ]; then
    name="_acme-challenge.$ID.srv.nomercy.tv"
    value="plant-$(date +%s)"
    curl -fsS -X POST -H "Authorization: Bearer ${PLANT_TOKEN}" -d "{\"name\":\"$name\",\"value\":\"$value\"}" "$PLANT_URL" >/dev/null
    start=$(date +%s)
    seen=0
    for i in $(seq 1 40); do
        got=$(dig +short +time=1 +tries=1 @"$REPLICA" "$name" TXT)
        if [ "$got" = "\"$value\"" ]; then seen=1; break; fi
        sleep 0.5
    done
    elapsed=$(( $(date +%s) - start ))
    if [ $seen = 1 ]; then echo "PASS planted TXT $name visible on replica after ~${elapsed}s"; else echo "FAIL planted TXT not on replica within 20s"; FAIL=1; fi
    curl -fsS -X DELETE -H "Authorization: Bearer ${PLANT_TOKEN}" -d "{\"name\":\"$name\"}" "$PLANT_URL" >/dev/null
fi

[ $FAIL = 0 ] && echo "replica matches reference" || { echo "replica check FAILED"; exit 1; }
