#!/bin/bash
# Checks the second name server against the first, from a third place (run it on the droplet or any watcher host).
# Usage: check-ns.sh NS1_ADDR NS2_ADDR
# Prints one line per check and ends with "RESULT: PASS" or "RESULT: FAIL <n>". Exit 0 on PASS, 1 on FAIL.
# Checks: ns2 answers SOA; apex NS lists ns1 and ns2; a synthesized A and AAAA equal ns1's; the zone serial of
# the dynamic file equals ns1's (a lagging or stalled zone-sync shows here).
set -u
NS1="${1:?ns1 address}"
NS2="${2:?ns2 address}"
ZONE="${ZONE:-srv.nomercy.tv}"
TRIES="${TRIES:-3}"
fails=0

q() { dig +time=3 +tries=1 +short "@$1" "$2" "$3" 2>/dev/null | grep -v '^;' | sort; }
serial() { # SOA serial of the dynamic file, read from the authority section of a TXT miss
    dig +time=3 +tries=1 +noall +authority "@$1" TXT "_acme-challenge.00000000-0000-4000-8000-0000000000aa.$ZONE" 2>/dev/null | awk '$4=="SOA"{print $7; exit}'
}
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }

soa=$(q "$NS2" "$ZONE" SOA)
if [ -n "$soa" ]; then ok "ns2 answers SOA"; else bad "ns2 gives no SOA (down, filtered or the forward broke)"; fi

nsset=$(q "$NS2" "$ZONE" NS | tr '\n' ' ')
case "$nsset" in *ns1.nomercy.tv.*ns2.nomercy.tv.*|*ns2.nomercy.tv.*ns1.nomercy.tv.*) ok "ns2 lists ns1 and ns2";; *) bad "ns2 NS list is '$nsset'";; esac

for t in A:192-168-1-101.abc123 AAAA:2001-db8--1.abc123; do
    type="${t%%:*}"; name="${t#*:}.$ZONE"
    a=$(q "$NS1" "$name" "$type"); b=$(q "$NS2" "$name" "$type")
    if [ -n "$a" ] && [ "$a" = "$b" ]; then ok "$type synthesis equal ($a)"; else bad "$type synthesis differs: ns1='$a' ns2='$b'"; fi
done

s1=""; s2=""
for i in $(seq 1 "$TRIES"); do
    s1=$(serial "$NS1"); s2=$(serial "$NS2")
    [ -n "$s1" ] && [ "$s1" = "$s2" ] && break
    sleep 4
done
if [ -n "$s1" ] && [ "$s1" = "$s2" ]; then ok "zone serial equal ($s1)"; else bad "zone serial differs: ns1='$s1' ns2='$s2'"; fi

if [ "$fails" -eq 0 ]; then echo "RESULT: PASS"; exit 0; fi
echo "RESULT: FAIL $fails"; exit 1
