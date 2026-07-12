#!/bin/bash
# /opt/nomercy-stack/scripts/disk-cleanup.sh
# Daily disk maintenance for the NoMercy production stack.
# Prevents disk-full outages by pruning Docker build cache, dangling images,
# stopped containers, unused networks, and old system logs.
#
# Alert threshold: 85% disk usage triggers a log warning.
# Safe: never touches named Docker volumes (Postgres, Keycloak data).

set -euo pipefail

LOGFILE="/var/log/nomercy-disk-cleanup.log"
THRESHOLD=85

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

# --- Disk check before cleanup ---
DISK_BEFORE=$(df /dev/vda1 | awk 'NR==2 {print $5}' | tr -d '%')
AVAIL_BEFORE=$(df -h /dev/vda1 | awk 'NR==2 {print $4}')
log "START — disk usage: ${DISK_BEFORE}% (${AVAIL_BEFORE} free)"

# --- Docker: prune build cache (the biggest offender) ---
BUILDER_FREED=$(docker builder prune -f 2>&1 | grep -E '^Total reclaimed' | awk '{print $NF}' || echo "0B")
log "Docker builder prune: freed ${BUILDER_FREED}"

# --- Docker: prune stopped containers, dangling images, unused networks ---
# Does NOT remove volumes (-v is intentionally omitted)
PRUNE_FREED=$(docker system prune -f 2>&1 | grep -E '^Total reclaimed' | awk '{print $NF}' || echo "0B")
log "Docker system prune: freed ${PRUNE_FREED}"

# --- System journal logs: keep last 100MB ---
journalctl --vacuum-size=100M 2>&1 | grep -E 'freed|Vacuuming' | while read line; do
    log "journalctl: $line"
done

# --- Old rotated/compressed logs older than 30 days ---
LOGCOUNT=$(find /var/log -name '*.gz' -mtime +30 -o -name '*.1' -mtime +30 2>/dev/null | wc -l)
find /var/log -name '*.gz' -mtime +30 -delete 2>/dev/null || true
find /var/log -name '*.1' -mtime +30 -delete 2>/dev/null || true
log "Deleted ${LOGCOUNT} old rotated log files"

# --- Disk check after cleanup ---
DISK_AFTER=$(df /dev/vda1 | awk 'NR==2 {print $5}' | tr -d '%')
AVAIL_AFTER=$(df -h /dev/vda1 | awk 'NR==2 {print $4}')
log "END   — disk usage: ${DISK_AFTER}% (${AVAIL_AFTER} free)"

# --- Alert if still above threshold ---
if [ "$DISK_AFTER" -ge "$THRESHOLD" ]; then
    log "WARNING: disk usage ${DISK_AFTER}% exceeds ${THRESHOLD}% threshold — manual intervention may be needed"
    # Extend here with curl to a webhook/Discord if needed in future
fi
