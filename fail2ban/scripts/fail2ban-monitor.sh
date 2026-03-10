#!/bin/bash

# ZERO TOLERANCE Fail2Ban Master Monitor
# Comprehensive fail2ban monitoring in one concise output

echo "========================================================"
echo "🚫 ZERO TOLERANCE PROTECTION MASTER STATUS"
echo "========================================================"
echo "📅 $(date)"
echo

# Container and Service Status
echo "🐳 SYSTEM STATUS:"
CONTAINER_STATUS=$(docker ps --filter "name=fail2ban" --format "{{.Status}}" | head -1)
if [[ "$CONTAINER_STATUS" == *"Up"* ]]; then
    echo "   ✅ Container: Running ($CONTAINER_STATUS)"
    
    SERVICE_STATUS=$(docker exec fail2ban fail2ban-client status 2>/dev/null | grep "Number of jail" | awk '{print $4}')
    if [ -n "$SERVICE_STATUS" ]; then
        echo "   ✅ Service: Active ($SERVICE_STATUS jails)"
    else
        echo "   ❌ Service: Not responding"
        exit 1
    fi
else
    echo "   ❌ Container: Not running"
    exit 1
fi

echo "📊 PROTECTION STATISTICS (All Active Jails):"

# Get all active jails dynamically
JAIL_LIST=$(docker exec fail2ban fail2ban-client status 2>/dev/null | grep "Jail list:" | cut -d: -f2 | tr ',' '\n' | sed 's/^[ \t]*//;s/[ \t]*$//')

# Track totals
TOTAL_BANNED=0
TOTAL_ATTEMPTS=0

# Process each jail
while IFS= read -r jail; do
    if [ -n "$jail" ]; then
        CURRENT=$(docker exec fail2ban fail2ban-client status "$jail" 2>/dev/null | grep "Currently banned:" | grep -o '[0-9]\+' || echo "0")
        FAILED=$(docker exec fail2ban fail2ban-client status "$jail" 2>/dev/null | grep "Total failed:" | grep -o '[0-9]\+' || echo "0")
        
        # Add to totals
        TOTAL_BANNED=$((TOTAL_BANNED + ${CURRENT:-0}))
        TOTAL_ATTEMPTS=$((TOTAL_ATTEMPTS + ${FAILED:-0}))
        
        # Format jail name for display
        case "$jail" in
            "nginx-wp-scan")        echo "   🎯 WordPress/Secure:  ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
            "nginx-vuln-scan")      echo "   🐛 Vulnerability:     ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
            "nginx-bad-bots")       echo "   🤖 Bad Bots:         ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
            "nginx-smb-exploit")    echo "   🚨 SMB Exploits:      ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
            "nginx-systematic-scan") echo "   🔍 System Scanning:   ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
            "nginx-zero-tolerance") echo "   ⚡ Zero Tolerance:    ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
            "nginx-aggressive-scan") echo "   🔥 Aggressive Scan:   ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
            "nginx-head-scan")      echo "   📡 HEAD Scanning:     ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
            "sshd")                 echo "   🔐 SSH Attacks:       ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
            *) echo "   📋 $jail: ${CURRENT:-0} banned | ${FAILED:-0} attempts" ;;
        esac
    fi
done <<< "$JAIL_LIST"

echo "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   📊 TOTAL ACROSS JAILS: $TOTAL_BANNED banned | $TOTAL_ATTEMPTS attempts"

# Total banned IPs
TOTAL_UNIQUE_BANNED=$(iptables -L | grep "Chain f2b-" | awk '{print $2}' | while read chain; do iptables -L "$chain" -n | grep REJECT | awk '{print $4}'; done | grep -v "0.0.0.0/0" | grep -v "0.0.0" | sort -u | wc -l)
echo "   🚫 TOTAL UNIQUE IPs: $TOTAL_UNIQUE_BANNED permanently banned"

# Recent Activity (last 10 lines)
echo
echo "🕐 RECENT ACTIVITY (last 10 events):"
if docker exec fail2ban test -f /logs/fail2ban/fail2ban.log; then
    docker exec fail2ban tail -10 /logs/fail2ban/fail2ban.log 2>/dev/null | grep -E "(Ban|Found|NOTICE)" | while read line; do
        if [[ "$line" == *"Ban "* ]]; then
            echo "   ⛔ $line"
        elif [[ "$line" == *"Found"* ]]; then
            echo "   🔍 $line"
        else
            echo "   ℹ️  $line"
        fi
    done
else
    echo "   📝 Recent log entries:"
    docker exec fail2ban tail -5 /var/log/fail2ban.log 2>/dev/null | tail -3 | while read line; do
        echo "   ℹ️  $line"
    done
fi

# Top Attacking IPs
echo
echo "🎯 TOP ATTACKING IPs:"
if [ "$TOTAL_UNIQUE_BANNED" -gt 0 ]; then
    # Get IPs from all f2b chains using numeric output
    {
        iptables -L | grep "Chain f2b-" | awk '{print $2}' | while read chain; do
            iptables -L "$chain" -n | grep REJECT | awk '{print $4}'
        done
    } | grep -v "0.0.0.0/0" | grep -v "0.0.0" | sort | uniq -c | sort -nr | head -8 | while read count ip; do
        echo "   🚨 $ip ($count rules)"
    done
else
    echo "   📍 No banned IPs yet"
fi

# Filter Test Results (quick)
echo
echo "🔍 FILTER EFFECTIVENESS:"
LOG_LINES=$(docker exec fail2ban wc -l /remotelogs/nginx/access.log 2>/dev/null | awk '{print $1}' || echo "0")
if [ "$LOG_LINES" -gt 0 ]; then
    # Quick filter test - simplified version
    echo "   📋 Log entries: $LOG_LINES total"
    
    # Count recent matches in last 100 lines for speed
    WP_RECENT=$(docker exec fail2ban tail -100 /remotelogs/nginx/access.log 2>/dev/null | grep -cE "(wp-|\.env|\.git|config\.php|admin\.php|alfacgiapi)" || echo "0")
    VULN_RECENT=$(docker exec fail2ban tail -100 /remotelogs/nginx/access.log 2>/dev/null | grep -cE "(database|\.sql|\.bak|backup)" || echo "0") 
    BOT_RECENT=$(docker exec fail2ban tail -100 /remotelogs/nginx/access.log 2>/dev/null | grep -cE "(sqlmap|nmap|nikto|scanner)" || echo "0")
    
    echo "   🎯 WordPress patterns: $WP_RECENT recent matches"
    echo "   🐛 Vulnerability patterns: $VULN_RECENT recent matches"  
    echo "   🤖 Bad bot patterns: $BOT_RECENT recent matches"
else
    echo "   ⚠️  No log entries found"
fi

# System Health Check
echo
echo "⚡ SYSTEM HEALTH:"

# Check iptables sync
HOST_CHAINS=$(iptables -L | grep -c "f2b-")
if [ "$HOST_CHAINS" -gt 0 ]; then
    echo "   ✅ Iptables: $HOST_CHAINS chains active"
else
    echo "   ⚠️  Iptables: No active chains"
fi

# Check log accessibility
if docker exec fail2ban test -r /remotelogs/nginx/access.log; then
    echo "   ✅ Logs: Accessible"
else
    echo "   ❌ Logs: Not accessible"
fi

# Check jail configurations
ALL_JAILS_OK=true
JAIL_COUNT=0
CONFIGURED_JAILS=0

# Check all active jails
while IFS= read -r jail; do
    if [ -n "$jail" ]; then
        JAIL_COUNT=$((JAIL_COUNT + 1))
        BANTIME=$(docker exec fail2ban fail2ban-client get "$jail" bantime 2>/dev/null)
        MAXRETRY=$(docker exec fail2ban fail2ban-client get "$jail" maxretry 2>/dev/null)
        
        if [ "$BANTIME" = "-1" ] && [ "$MAXRETRY" = "1" ]; then
            CONFIGURED_JAILS=$((CONFIGURED_JAILS + 1))
        else
            ALL_JAILS_OK=false
        fi
    fi
done <<< "$(docker exec fail2ban fail2ban-client status 2>/dev/null | grep "Jail list:" | cut -d: -f2 | tr ',' '\n' | sed 's/^[ \t]*//;s/[ \t]*$//')"

if $ALL_JAILS_OK; then
    echo "   ✅ Config: Zero tolerance active ($CONFIGURED_JAILS/$JAIL_COUNT jails: 1 attempt = permanent ban)"
else
    echo "   ⚠️  Config: $CONFIGURED_JAILS/$JAIL_COUNT jails properly configured for zero tolerance"
fi

echo
echo "========================================================"
echo "🎯 ZERO TOLERANCE: 1 attempt = PERMANENT BAN (-1)"
echo "📊 Status: $([ $TOTAL_UNIQUE_BANNED -gt 0 ] && echo "ACTIVE - $TOTAL_UNIQUE_BANNED IPs blocked" || echo "STANDBY - No threats detected")"
echo "🕐 Monitoring since: $(date)"
echo "========================================================"

# Optional: Log performance data for time-series tracking
LOG_DIR="/opt/nomercy-stack/logs/fail2ban"
if [ -d "$LOG_DIR" ]; then
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$TIMESTAMP,$TOTAL_BANNED,$TOTAL_ATTEMPTS,$TOTAL_UNIQUE_BANNED,$JAIL_COUNT" >> "$LOG_DIR/fail2ban-performance.csv"
    
    # Create header if file is new
    if [ $(wc -l < "$LOG_DIR/fail2ban-performance.csv" 2>/dev/null || echo 0) -eq 1 ]; then
        sed -i '1i\timestamp,total_banned,total_attempts,unique_ips,active_jails' "$LOG_DIR/fail2ban-performance.csv"
    fi
fi
