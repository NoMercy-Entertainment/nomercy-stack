#!/usr/bin/env bash
# Proves write-fail2ban-ignore.sh puts TRUSTED_IPS (CI runner addresses) in
# fail2ban's ignoreip and nowhere else, refuses bad values, and keeps the
# trusted entries of the existing file when a run has none.
#   bash scripts/check-fail2ban-ignore.sh
set -u

repo=$(cd "$(dirname "$0")/.." && pwd)
writer="$repo/scripts/write-fail2ban-ignore.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
file="$tmp/fail2ban/config/fail2ban/jail.d/01-admin-ignoreip.local"
bad=0

fail() { echo "FAIL: $1"; bad=$((bad + 1)); }

run() { STACK_DIR="$tmp" LOCAL_NETWORKS="10.0.0.0/8" SELF_ADDRESSES="198.51.100.9" ADMIN_IPS="192.0.2.5" "$@" bash "$writer" 2>&1; }

# 1. TRUSTED_IPS lands in ignoreip, comma list accepted.
run env TRUSTED_IPS="203.0.113.7,203.0.113.8" > /dev/null
grep -E '^ignoreip = .*192\.0\.2\.5 .*203\.0\.113\.7 203\.0\.113\.8$' "$file" > /dev/null \
    || fail "trusted addresses are not in ignoreip"

# 2. Trusted addresses are not in the admin paths (UFW, admin-allow.inc).
grep -E '203\.0\.113' "$repo/scripts/write-admin-allow.sh" > /dev/null && fail "write-admin-allow.sh names a trusted address"
[ -e "$tmp/proxy/sites/admin-allow.inc" ] && fail "the writer touched admin-allow.inc"
grep -iE 'trusted_ips' "$repo/scripts/provision-security.sh" | grep -E 'ufw |write-admin-allow' > /dev/null \
    && fail "provision-security.sh passes TRUSTED_IPS to ufw or write-admin-allow.sh"

# 3. A bad value is refused and the file stays as it was.
before=$(cat "$file")
if run env TRUSTED_IPS="203.0.113.7; rm -rf /" > /dev/null; then fail "a bad TRUSTED_IPS was accepted"; fi
[ "$before" = "$(cat "$file")" ] || fail "a refused run changed the file"

# 4. An empty TRUSTED_IPS keeps the trusted entries of the existing file.
run env TRUSTED_IPS="" > /dev/null
grep -E '^ignoreip = .*203\.0\.113\.7 203\.0\.113\.8$' "$file" > /dev/null \
    || fail "an empty TRUSTED_IPS dropped the existing trusted entries"

# 5. A new value replaces the old one.
run env TRUSTED_IPS="198.51.100.77" > /dev/null
grep -E '^ignoreip = .*198\.51\.100\.77$' "$file" > /dev/null && ! grep -E '203\.0\.113\.7' "$file" > /dev/null \
    || fail "a new TRUSTED_IPS did not replace the old one"

if [ "$bad" -gt 0 ]; then
    echo "FAIL: $bad check(s) failed."
    exit 1
fi
echo "OK: TRUSTED_IPS reaches fail2ban's ignoreip only, is validated and survives an empty run."
