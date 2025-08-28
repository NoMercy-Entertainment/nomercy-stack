#!/bin/bash

# Fail2Ban Performance Trends
# Shows historical performance data and trends

echo "========================================================"
echo "📈 FAIL2BAN PERFORMANCE TRENDS"
echo "========================================================"

LOG_FILE="/opt/NoMercyStack/logs/fail2ban/fail2ban-performance.csv"

if [ ! -f "$LOG_FILE" ]; then
    echo "❌ No performance data found. Run ./fail2ban-monitor.sh first."
    exit 1
fi

echo "📊 Recent Performance Data:"
echo
echo "Time                | Banned | Attempts | Unique IPs | Jails"
echo "-------------------+--------+----------+------------+-------"

# Show last 10 entries
tail -10 "$LOG_FILE" | grep -v "timestamp" | while IFS=',' read -r timestamp banned attempts unique jails; do
    # Format timestamp for display
    display_time=$(echo "$timestamp" | cut -d' ' -f2)
    printf "%-18s | %6s | %8s | %10s | %5s\n" "$display_time" "$banned" "$attempts" "$unique" "$jails"
done

echo
echo "📈 TRENDS:"

# Calculate trends if we have multiple entries
ENTRY_COUNT=$(wc -l < "$LOG_FILE")
if [ "$ENTRY_COUNT" -gt 2 ]; then
    # Get first and last non-header entries
    FIRST_LINE=$(sed -n '2p' "$LOG_FILE")
    LAST_LINE=$(tail -1 "$LOG_FILE")
    
    if [ -n "$FIRST_LINE" ] && [ -n "$LAST_LINE" ]; then
        FIRST_BANNED=$(echo "$FIRST_LINE" | cut -d',' -f2)
        FIRST_ATTEMPTS=$(echo "$FIRST_LINE" | cut -d',' -f3)
        FIRST_UNIQUE=$(echo "$FIRST_LINE" | cut -d',' -f4)
        
        LAST_BANNED=$(echo "$LAST_LINE" | cut -d',' -f2)
        LAST_ATTEMPTS=$(echo "$LAST_LINE" | cut -d',' -f3)
        LAST_UNIQUE=$(echo "$LAST_LINE" | cut -d',' -f4)
        
        BANNED_CHANGE=$((LAST_BANNED - FIRST_BANNED))
        ATTEMPTS_CHANGE=$((LAST_ATTEMPTS - FIRST_ATTEMPTS))
        UNIQUE_CHANGE=$((LAST_UNIQUE - FIRST_UNIQUE))
        
        echo "   📊 Total Banned: $BANNED_CHANGE change since first reading"
        echo "   🎯 Attempts: $ATTEMPTS_CHANGE new attempts detected"
        echo "   🚫 Unique IPs: $UNIQUE_CHANGE new IPs permanently banned"
        
        # Calculate rate per hour (rough estimate)
        FIRST_TIME=$(echo "$FIRST_LINE" | cut -d',' -f1)
        LAST_TIME=$(echo "$LAST_LINE" | cut -d',' -f1)
        echo "   ⏰ Monitoring period: $FIRST_TIME to $LAST_TIME"
    fi
else
    echo "   📝 Not enough data for trend analysis (need multiple readings)"
fi

echo
echo "💡 TIP: Run './fail2ban-monitor.sh' regularly to build trend data"
echo "📁 Data stored in: $LOG_FILE"
