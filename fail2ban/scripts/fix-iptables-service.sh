#!/usr/bin/with-contenv bash

echo "🔧 Starting iptables fix service..."

# Initial fix on startup
echo "🔄 Initial iptables symlink setup..."

# Remove existing symlinks/files
rm -f /usr/sbin/iptables /usr/sbin/iptables-save /usr/sbin/iptables-restore

# Create new symlinks to legacy multi-tool
ln -sf xtables-legacy-multi /usr/sbin/iptables
ln -sf xtables-legacy-multi /usr/sbin/iptables-save
ln -sf xtables-legacy-multi /usr/sbin/iptables-restore

echo "✅ Initial iptables symlinks fixed"

# Track previous state to avoid unnecessary restarts
previous_state=""

while true; do
    # Check if iptables is working and symlinks are correct
    current_state=""
    if [ -L /usr/sbin/iptables ] && [ "$(readlink /usr/sbin/iptables)" = "xtables-legacy-multi" ]; then
        # Test if iptables actually works
        if /usr/sbin/iptables --version >/dev/null 2>&1; then
            current_state="working"
        else
            current_state="broken"
        fi
    else
        current_state="missing"
    fi
    
    # Only fix if state changed and is broken
    if [ "$current_state" != "working" ] && [ "$current_state" != "$previous_state" ]; then
        echo "🔄 iptables issue detected (state: $current_state), fixing..."
        
        # Remove existing symlinks/files
        rm -f /usr/sbin/iptables /usr/sbin/iptables-save /usr/sbin/iptables-restore
        
        # Create new symlinks to legacy multi-tool
        ln -sf xtables-legacy-multi /usr/sbin/iptables
        ln -sf xtables-legacy-multi /usr/sbin/iptables-save
        ln -sf xtables-legacy-multi /usr/sbin/iptables-restore
        
        echo "✅ iptables symlinks fixed (state: $current_state -> working)"
        
        # Only restart fail2ban if it was actually broken
        if [ "$current_state" = "broken" ]; then
            echo "🔄 Restarting fail2ban service..."
            /usr/bin/s6-svc -r /var/run/s6/services/fail2ban/ 2>/dev/null || echo "Failed to restart fail2ban service"
        fi
    fi
    
    previous_state="$current_state"
    
    # Check every 60 seconds (less frequent to reduce overhead)
    sleep 60
done
