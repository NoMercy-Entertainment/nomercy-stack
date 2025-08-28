#!/usr/bin/with-contenv bash
# Fix iptables symlinks for legacy compatibility
# This script ensures fail2ban can properly execute iptables commands

echo "🔧 Fixing iptables symlinks for legacy compatibility..."

# Check if xtables-legacy-multi exists
if [ ! -f /usr/sbin/xtables-legacy-multi ]; then
    echo "❌ xtables-legacy-multi not found at /usr/sbin/xtables-legacy-multi"
    echo "� Searching for xtables tools..."
    find /usr -name "*xtables*" 2>/dev/null || echo "No xtables tools found"
    exit 0
fi

# Remove existing symlinks/files if they exist
rm -f /usr/sbin/iptables /usr/sbin/iptables-save /usr/sbin/iptables-restore

# Create new symlinks to legacy multi-tool
ln -sf /usr/sbin/xtables-legacy-multi /usr/sbin/iptables
ln -sf /usr/sbin/xtables-legacy-multi /usr/sbin/iptables-save
ln -sf /usr/sbin/xtables-legacy-multi /usr/sbin/iptables-restore

# Verify the symlinks work
if /usr/sbin/iptables --version > /dev/null 2>&1; then
    echo "✅ iptables symlinks fixed successfully"
    echo "📋 iptables version: $(/usr/sbin/iptables --version)"
else
    echo "⚠️ iptables test failed, but symlinks created"
    ls -la /usr/sbin/iptables* || echo "No iptables files found"
fi

echo "🚀 iptables fix complete"
