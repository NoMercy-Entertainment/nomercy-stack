#!/bin/bash
# infra/nomercy-stack/scripts/provision-swap.sh
#
# Ensures the host has a swapfile. The blue-green website deploy briefly runs
# both colors (website-blue AND website-green) plus the rest of the stack at
# once, and the idle color's boot (composer autoload, artisan optimize) spikes
# memory on top of that. On a droplet with no swap that transient spike pushes
# the host over physical RAM, and the kernel OOM-killer SIGKILLs whatever heavy
# step is running (exit 137) — the deploy fails and the idle color never goes
# healthy. A small swapfile absorbs the burst; swappiness is kept low so it is
# only touched under real pressure, not for steady-state paging.
#
# Idempotent: does nothing if swap is already active.
#
# Run on the target host as root:
#   /opt/nomercy-stack/scripts/provision-swap.sh [SIZE]
# SIZE defaults to 2G (accepts any fallocate size, e.g. 4G).

set -euo pipefail

SIZE="${1:-2G}"
SWAPFILE="/swapfile"
SWAPPINESS=10

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must run as root" >&2
    exit 1
fi

if swapon --show --noheadings | grep -q .; then
    echo "OK: swap already active, nothing to do:"
    swapon --show
    exit 0
fi

echo "No swap active — creating a ${SIZE} swapfile at ${SWAPFILE}."

# fallocate is instant; fall back to dd on filesystems that reject it (e.g. some
# older ext4/xfs setups where swap on a fallocated file is unreliable).
if ! fallocate -l "$SIZE" "$SWAPFILE" 2>/dev/null; then
    echo "fallocate unavailable — falling back to dd (slower)."
    SIZE_MB="$(numfmt --from=iec "$SIZE" | awk '{print int($1 / 1024 / 1024)}')"
    dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SIZE_MB" status=progress
fi

chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE"
swapon "$SWAPFILE"

# Persist across reboots.
if ! grep -qE "^${SWAPFILE}[[:space:]]" /etc/fstab; then
    printf '%s none swap sw 0 0\n' "$SWAPFILE" >> /etc/fstab
    echo "Added ${SWAPFILE} to /etc/fstab."
fi

# Only page to swap under genuine memory pressure.
sysctl -w "vm.swappiness=${SWAPPINESS}" >/dev/null
printf 'vm.swappiness=%s\n' "$SWAPPINESS" > /etc/sysctl.d/99-nomercy-swappiness.conf

echo "Swap enabled:"
swapon --show
free -h
