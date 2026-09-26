#!/bin/bash
# infra/nomercy-stack/scripts/provision-auto-updates.sh
#
# Installs Ubuntu's security fixes and normal updates every day at the host's
# quietest hour, and never touches the packages that would interrupt the site.
#
# Ubuntu already runs unattended-upgrades daily, at a random time around 06:00
# UTC and with no block list. On this host some upgrades are not live-safe
# (fleet-update skill, "Traps found on the production droplet"):
#   - docker / containerd: a restart pauses the containers' embedded DNS, and
#     the website resolves `mysql` by name on every request.
#   - apparmor: a profile reload can leave containers unstoppable, which breaks
#     the blue-green deploy.
#   - systemd (incl. systemd-resolved) and udev: the website looks up
#     auth.nomercy.tv through the host resolver.
# Those wait for a planned reboot window. Kernels install but the host is never
# rebooted automatically; /var/run/reboot-required tells you when one is due.
#
# Time: 04:00 UTC was the quietest hour of the proxy log (2026-09-25/26, about
# 3,200 requests against 4,400 to 11,000 in other hours).
#
# Idempotent: rewrites its own files and reloads the timers.
#
# Run on the target host as root:
#   /opt/nomercy-stack/scripts/provision-auto-updates.sh

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must run as root" >&2
    exit 1
fi

# Sorts after 50unattended-upgrades, so these lists are added to its own.
cat > /etc/apt/apt.conf.d/51nomercy-unattended-upgrades <<'EOF'
// Written by nomercy-stack scripts/provision-auto-updates.sh; edit it there.
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-updates";
};
// Regular expressions matched against the start of the package name.
Unattended-Upgrade::Package-Blacklist {
    "docker-";
    "containerd";
    "apparmor";
    "libapparmor";
    "systemd";
    "libsystemd";
    "udev";
    "libudev";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# needrestart restarts services whose libraries changed. It already skips
# docker; containerd and systemd-resolved must not be restarted either.
mkdir -p /etc/needrestart/conf.d
cat > /etc/needrestart/conf.d/nomercy.conf <<'EOF'
# Written by nomercy-stack scripts/provision-auto-updates.sh; edit it there.
$nrconf{override_rc}{qr(^containerd)} = 0;
$nrconf{override_rc}{qr(^systemd-resolved)} = 0;
EOF

# The empty OnCalendar= clears Ubuntu's own schedule before setting ours.
mkdir -p /etc/systemd/system/apt-daily.timer.d /etc/systemd/system/apt-daily-upgrade.timer.d
cat > /etc/systemd/system/apt-daily.timer.d/nomercy.conf <<'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 03:30 UTC
RandomizedDelaySec=15m
EOF
cat > /etc/systemd/system/apt-daily-upgrade.timer.d/nomercy.conf <<'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 04:00 UTC
RandomizedDelaySec=10m
EOF

systemctl daemon-reload
systemctl restart apt-daily.timer apt-daily-upgrade.timer

echo "Next runs:"
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer --no-pager
echo
echo "Dry run (what tonight's run would install):"
unattended-upgrade --dry-run 2>&1 | tail -n 5
