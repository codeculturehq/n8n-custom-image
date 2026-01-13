#!/usr/bin/env bash
#
# monitor-outbound.sh - Monitor n8n container for external network connections
#
# Usage:
#   ./scripts/monitor-outbound.sh [container_name] [duration_seconds]
#
# Examples:
#   ./scripts/monitor-outbound.sh              # Monitor 'n8n' container for 60s
#   ./scripts/monitor-outbound.sh n8n 300      # Monitor for 5 minutes
#   ./scripts/monitor-outbound.sh n8n 0        # Monitor indefinitely (Ctrl+C to stop)
#
# Requirements:
#   - Docker
#   - tcpdump (brew install tcpdump / apt install tcpdump)
#
set -euo pipefail

# Configuration
CONTAINER_NAME="${1:-n8n}"
DURATION="${2:-60}"
LOG_DIR="/tmp/n8n-traffic-monitor"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/outbound_${TIMESTAMP}.log"
PCAP_FILE="${LOG_DIR}/capture_${TIMESTAMP}.pcap"

# Known n8n telemetry/external endpoints to watch for
KNOWN_ENDPOINTS=(
    "telemetry.n8n.io"
    "api.n8n.io"
    "license.n8n.io"
    "posthog.com"
    "app.posthog.com"
    "us.posthog.com"
    "eu.posthog.com"
    "api.segment.io"
    "cdn.segment.com"
    "sentry.io"
    "npms.io"
    "registry.npmjs.org"
    "api.github.com"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_alert() { echo -e "${RED}[ALERT]${NC} $1" | tee -a "$LOG_FILE"; }

# Check prerequisites
check_prerequisites() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! command -v tcpdump &> /dev/null; then
        log_error "tcpdump is not installed. Install with: brew install tcpdump (macOS) or apt install tcpdump (Linux)"
        exit 1
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Container '${CONTAINER_NAME}' is not running"
        exit 1
    fi
}

# Get container IP address
get_container_ip() {
    docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" 2>/dev/null || \
    docker inspect -f '{{.NetworkSettings.IPAddress}}' "$CONTAINER_NAME" 2>/dev/null
}

# Check if IP is RFC1918 (private)
is_private_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^10\. ]] || \
       [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || \
       [[ "$ip" =~ ^192\.168\. ]] || \
       [[ "$ip" =~ ^127\. ]] || \
       [[ "$ip" =~ ^169\.254\. ]] || \
       [[ "$ip" == "0.0.0.0" ]] || \
       [[ "$ip" == "255.255.255.255" ]]; then
        return 0  # true - is private
    fi
    return 1  # false - is public
}

# Parse and analyze traffic
analyze_traffic() {
    local line="$1"
    local src_ip dst_ip dst_port protocol

    # Extract destination IP from tcpdump output
    # Format: "IP src.port > dst.port: ..."
    if [[ "$line" =~ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.([0-9]+)\ \>\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\.([0-9]+) ]]; then
        src_ip="${BASH_REMATCH[1]}"
        src_port="${BASH_REMATCH[2]}"
        dst_ip="${BASH_REMATCH[3]}"
        dst_port="${BASH_REMATCH[4]}"

        # Check if destination is external (non-RFC1918)
        if ! is_private_ip "$dst_ip"; then
            log_alert "EXTERNAL CONNECTION: ${src_ip}:${src_port} -> ${dst_ip}:${dst_port}"

            # Try to resolve hostname
            local hostname
            hostname=$(host "$dst_ip" 2>/dev/null | awk '/domain name pointer/ {print $5}' | sed 's/\.$//' || echo "unknown")
            if [[ "$hostname" != "unknown" ]]; then
                log_alert "  Resolved to: $hostname"
            fi
        fi
    fi

    # Check for DNS queries
    if [[ "$line" =~ "A\?" ]] || [[ "$line" =~ "AAAA\?" ]]; then
        # Extract queried domain
        local domain
        domain=$(echo "$line" | grep -oE 'A\? [^ ]+|AAAA\? [^ ]+' | awk '{print $2}' | sed 's/\.$//')
        if [[ -n "$domain" ]]; then
            log_warn "DNS QUERY: $domain"
            echo "$(date '+%Y-%m-%d %H:%M:%S') DNS: $domain" >> "$LOG_FILE"

            # Check against known endpoints
            for endpoint in "${KNOWN_ENDPOINTS[@]}"; do
                if [[ "$domain" == *"$endpoint"* ]]; then
                    log_alert "KNOWN TELEMETRY ENDPOINT: $domain"
                fi
            done
        fi
    fi
}

# Main monitoring function
monitor_traffic() {
    local container_ip
    container_ip=$(get_container_ip)

    if [[ -z "$container_ip" ]]; then
        log_warn "Could not determine container IP, monitoring all Docker traffic"
        container_ip="any"
    fi

    log_info "Container IP: $container_ip"
    log_info "Monitoring for external connections..."
    log_info "Log file: $LOG_FILE"
    log_info "PCAP file: $PCAP_FILE"

    if [[ "$DURATION" == "0" ]]; then
        log_info "Duration: indefinite (Ctrl+C to stop)"
    else
        log_info "Duration: ${DURATION}s"
    fi

    echo ""
    echo "=========================================="
    echo " Watching for external connections..."
    echo " Known telemetry endpoints monitored:"
    for endpoint in "${KNOWN_ENDPOINTS[@]}"; do
        echo "   - $endpoint"
    done
    echo "=========================================="
    echo ""

    # Build tcpdump filter
    # Capture: DNS (port 53), HTTP (80), HTTPS (443), and any other outbound
    local filter="src host $container_ip and (port 53 or port 80 or port 443 or port 8080)"

    if [[ "$container_ip" == "any" ]]; then
        # If we can't get container IP, capture from Docker networks
        filter="(port 53 or port 80 or port 443) and not port 5678"
    fi

    # Start tcpdump
    local tcpdump_cmd="tcpdump -i any -n -l"

    if [[ "$DURATION" != "0" ]]; then
        tcpdump_cmd="timeout ${DURATION}s $tcpdump_cmd"
    fi

    # Run tcpdump and analyze in real-time
    # Also save to pcap for later analysis
    sudo $tcpdump_cmd -w "$PCAP_FILE" "$filter" 2>/dev/null &
    local pcap_pid=$!

    # Read from tcpdump for real-time analysis
    sudo tcpdump -i any -n -l "$filter" 2>/dev/null | while read -r line; do
        analyze_traffic "$line"
    done &
    local analyze_pid=$!

    # Wait for duration or Ctrl+C
    if [[ "$DURATION" != "0" ]]; then
        sleep "$DURATION"
        sudo kill "$pcap_pid" 2>/dev/null || true
        sudo kill "$analyze_pid" 2>/dev/null || true
    else
        wait "$pcap_pid"
    fi
}

# Generate summary report
generate_report() {
    echo ""
    echo "=========================================="
    echo " MONITORING SUMMARY"
    echo "=========================================="

    if [[ -f "$LOG_FILE" ]]; then
        local external_count dns_count telemetry_count
        external_count=$(grep -c "EXTERNAL CONNECTION" "$LOG_FILE" 2>/dev/null || echo "0")
        dns_count=$(grep -c "^.*DNS:" "$LOG_FILE" 2>/dev/null || echo "0")
        telemetry_count=$(grep -c "KNOWN TELEMETRY" "$LOG_FILE" 2>/dev/null || echo "0")

        echo ""
        echo "Results:"
        echo "  - External connections detected: $external_count"
        echo "  - DNS queries logged: $dns_count"
        echo "  - Known telemetry endpoints: $telemetry_count"
        echo ""

        if [[ "$external_count" -eq 0 ]] && [[ "$telemetry_count" -eq 0 ]]; then
            log_success "No external connections detected! Zero-outbound-comms verified."
        else
            log_alert "External connections were detected! Review $LOG_FILE for details."
        fi

        echo ""
        echo "Log file: $LOG_FILE"
        echo "PCAP file: $PCAP_FILE (open with Wireshark for detailed analysis)"
    else
        log_info "No traffic logged during monitoring period."
    fi

    echo ""
}

# Cleanup handler
cleanup() {
    echo ""
    log_info "Stopping monitor..."
    # Kill any remaining tcpdump processes
    sudo pkill -f "tcpdump.*$CONTAINER_NAME" 2>/dev/null || true
    generate_report
    exit 0
}

# Main
main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║  n8n Outbound Traffic Monitor            ║"
    echo "║  Verifying zero-outbound-comms setup     ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    check_prerequisites

    # Create log directory
    mkdir -p "$LOG_DIR"

    # Set up cleanup trap
    trap cleanup SIGINT SIGTERM

    # Initialize log file
    echo "# n8n Outbound Traffic Monitor" > "$LOG_FILE"
    echo "# Started: $(date)" >> "$LOG_FILE"
    echo "# Container: $CONTAINER_NAME" >> "$LOG_FILE"
    echo "# Duration: ${DURATION}s" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    monitor_traffic

    generate_report
}

main "$@"
