#!/usr/bin/env bash
#
# quick-traffic-check.sh - Quick 30-second traffic check for n8n container
#
# Usage: ./scripts/quick-traffic-check.sh
#
set -uo pipefail

CONTAINER="${1:-n8n}"
DURATION="${2:-30}"

echo "╔════════════════════════════════════════════════════╗"
echo "║  Quick n8n Traffic Check (${DURATION}s)                     ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Verify container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Error: Container '$CONTAINER' is not running"
    exit 1
fi

echo "Monitoring container: $CONTAINER"
echo "Duration: ${DURATION} seconds"
echo ""
echo "Capturing all non-local traffic..."
echo "─────────────────────────────────────────────────────"

# Capture traffic - filter out local ports
docker run --rm --net container:"$CONTAINER" \
    nicolaka/netshoot \
    sh -c "timeout $DURATION tcpdump -i any -n -c 100 'not port 5678 and not port 5432 and not port 5679' 2>/dev/null || true"

echo "─────────────────────────────────────────────────────"
echo ""

# Quick DNS check - see if any DNS queries happened
echo "Checking for DNS queries..."
docker run --rm --net container:"$CONTAINER" \
    nicolaka/netshoot \
    sh -c "timeout 5 tcpdump -i any -n port 53 -c 10 2>/dev/null || echo 'No DNS queries detected'"

echo ""
echo "Done! If you saw no traffic above, zero-outbound-comms is working."
