#!/usr/bin/env bash
#
# monitor-outbound-docker.sh - Monitor n8n container using Docker sidecar (no sudo)
#
# Usage:
#   ./scripts/monitor-outbound-docker.sh [container_name] [duration_seconds]
#
# Examples:
#   ./scripts/monitor-outbound-docker.sh              # Monitor 'n8n' for 60s
#   ./scripts/monitor-outbound-docker.sh n8n 300      # Monitor for 5 minutes
#
# This uses nicolaka/netshoot as a sidecar to capture traffic from the n8n container.
# No sudo required!
#
set -uo pipefail  # Removed -e to handle timeout exit codes

CONTAINER_NAME="${1:-n8n}"
DURATION="${2:-60}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="/tmp/n8n-traffic-${TIMESTAMP}.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_alert() { echo -e "${RED}[ALERT]${NC} $1"; }

# Known telemetry endpoints
TELEMETRY_PATTERN="telemetry\.n8n\.io|api\.n8n\.io|license\.n8n\.io|posthog\.com|segment\.io|sentry\.io|npmjs\.org|npms\.io"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  n8n Outbound Traffic Monitor (Docker Sidecar)   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Check container exists
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_alert "Container '${CONTAINER_NAME}' is not running"
    exit 1
fi

log_info "Target container: $CONTAINER_NAME"
log_info "Duration: ${DURATION}s"
log_info "Output file: $OUTPUT_FILE"
echo ""

# Create the tcpdump filter
# Exclude local traffic (port 5678 is n8n, 5432 is postgres)
FILTER="not port 5678 and not port 5432 and not port 5679"

# Initialize output file
touch "$OUTPUT_FILE"

echo "Starting traffic capture..."
echo "Press Ctrl+C to stop early"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${CYAN} Live Traffic (external connections highlighted)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Run tcpdump in netshoot container attached to n8n's network namespace
# Use || true to handle timeout exit code (124)
docker run --rm --net container:"$CONTAINER_NAME" \
    --name n8n-traffic-monitor \
    nicolaka/netshoot \
    timeout "$DURATION" tcpdump -i any -n -l "$FILTER" 2>/dev/null | \
while read -r line; do
    echo "$line" >> "$OUTPUT_FILE"

    # Check for external IPs (not RFC1918)
    if echo "$line" | grep -qE '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)' | grep -qvE '(^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.|^127\.)'; then
        # Highlight potential external traffic
        if echo "$line" | grep -qE "$TELEMETRY_PATTERN"; then
            echo -e "${RED}[TELEMETRY]${NC} $line"
        elif echo "$line" | grep -qvE '(10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|127\.[0-9]+\.[0-9]+\.[0-9]+)'; then
            echo -e "${YELLOW}[EXTERNAL?]${NC} $line"
        else
            echo "$line"
        fi
    else
        echo "$line"
    fi
done || true

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

# Analyze results
if [[ -f "$OUTPUT_FILE" ]]; then
    echo "Analysis:"

    # Count DNS queries
    dns_count=$(grep -c "A?" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "  - DNS queries: $dns_count"

    # Check for telemetry endpoints
    telemetry_hits=$(grep -cE "$TELEMETRY_PATTERN" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "  - Known telemetry endpoints: $telemetry_hits"

    # Check for external IPs
    external_ips=$(grep -oE '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)' "$OUTPUT_FILE" 2>/dev/null | \
        grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|127\.|0\.0\.0\.0|255\.)' | \
        sort -u | wc -l || echo "0")
    echo "  - Unique external IPs: $external_ips"

    echo ""
    if [[ "$telemetry_hits" -eq 0 ]] && [[ "$external_ips" -eq 0 ]]; then
        log_success "No telemetry or external connections detected!"
        log_success "Zero-outbound-comms appears to be working correctly."
    else
        log_warn "Some external traffic detected. Review: $OUTPUT_FILE"

        if [[ "$telemetry_hits" -gt 0 ]]; then
            echo ""
            log_alert "Telemetry endpoints found:"
            grep -E "$TELEMETRY_PATTERN" "$OUTPUT_FILE" | head -10
        fi
    fi
else
    log_info "No traffic captured during monitoring period."
fi

echo ""
echo "Full capture saved to: $OUTPUT_FILE"
