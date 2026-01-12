#!/usr/bin/env bash
# Zero-Outbound Verification for n8n-custom-image
# Validates that n8n makes no external network calls when properly configured
set -euo pipefail

VENDOR_DIR="${VENDOR_DIR:-vendor/n8n}"
N8N_URL="${N8N_URL:-http://localhost:5678}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"

echo "=============================================="
echo " Zero-Outbound Verification Suite"
echo "=============================================="
echo ""

PASSED=0
FAILED=0
WARNINGS=0

pass() {
  echo "✓ PASS: $1"
  ((PASSED++)) || true
}

fail() {
  echo "✗ FAIL: $1"
  ((FAILED++)) || true
}

warn() {
  echo "! WARN: $1"
  ((WARNINGS++)) || true
}

info() {
  echo "  INFO: $1"
}

# ==============================================================================
# Phase 1: Static Source Analysis
# ==============================================================================
echo "Phase 1: Static Source Analysis"
echo "--------------------------------"

if [[ -d "$VENDOR_DIR" ]]; then
  # Check telemetry disable in telemetry/index.ts
  if grep -q "N8N_DISABLE_EXTERNAL_COMMUNICATIONS" "$VENDOR_DIR/packages/cli/src/telemetry/index.ts"; then
    pass "Telemetry service has external comms check"
  else
    fail "Telemetry service missing external comms check (patch 0002 not applied?)"
  fi

  # Check posthog disable
  if grep -q "N8N_DISABLE_EXTERNAL_COMMUNICATIONS" "$VENDOR_DIR/packages/cli/src/posthog/index.ts"; then
    pass "PostHog service has external comms check"
  else
    fail "PostHog service missing external comms check (patch 0002 not applied?)"
  fi

  # Check license service disable
  if grep -q "licenseServiceEnabled" "$VENDOR_DIR/packages/cli/src/license.ts"; then
    pass "License service has service enable check"
  else
    fail "License service missing enable check (patch 0001/0003 not applied?)"
  fi

  # Check GDPR overrides
  if grep -q "FORCED_FEATURES" "$VENDOR_DIR/packages/cli/src/license.ts"; then
    pass "License service has GDPR feature overrides"
  else
    fail "License service missing GDPR overrides (patch 0003 not applied?)"
  fi

  # Check frontend service
  if grep -q "externalCommsDisabled" "$VENDOR_DIR/packages/cli/src/services/frontend.service.ts"; then
    pass "Frontend service has external comms check"
  else
    fail "Frontend service missing external comms check (patch 0001 not applied?)"
  fi

  # Check base command
  if grep -q "N8N_DISABLE_EXTERNAL_COMMUNICATIONS" "$VENDOR_DIR/packages/cli/src/commands/base-command.ts"; then
    pass "Base command has external comms check"
  else
    fail "Base command missing external comms check (patch 0001 not applied?)"
  fi
else
  warn "Vendor directory not found - skipping static analysis"
fi

echo ""

# ==============================================================================
# Phase 2: Runtime API Verification (only if n8n is running)
# ==============================================================================
echo "Phase 2: Runtime API Verification"
echo "----------------------------------"

if curl -sf --max-time 2 "$N8N_URL/healthz" >/dev/null 2>&1; then
  info "n8n is running at $N8N_URL"

  # Check settings endpoint for telemetry
  SETTINGS=$(curl -sf --max-time 5 "$N8N_URL/rest/settings" 2>/dev/null || echo '{}')

  if echo "$SETTINGS" | jq -e '.data.telemetry.enabled == false' >/dev/null 2>&1; then
    pass "Telemetry is disabled in runtime settings"
  elif echo "$SETTINGS" | jq -e '.data.telemetry == null' >/dev/null 2>&1; then
    pass "Telemetry is null (disabled) in runtime settings"
  else
    fail "Telemetry appears enabled in runtime settings"
  fi

  # Check posthog settings
  if echo "$SETTINGS" | jq -e '.data.posthog.enabled == false' >/dev/null 2>&1; then
    pass "PostHog is disabled in runtime settings"
  elif echo "$SETTINGS" | jq -e '.data.posthog == null' >/dev/null 2>&1; then
    pass "PostHog is null (disabled) in runtime settings"
  else
    fail "PostHog appears enabled in runtime settings"
  fi

  # Check version notifications
  if echo "$SETTINGS" | jq -e '.data.versionNotifications.enabled == false' >/dev/null 2>&1; then
    pass "Version notifications disabled"
  else
    warn "Version notifications status unknown"
  fi

else
  warn "n8n not running at $N8N_URL - skipping runtime verification"
  info "Start n8n with: docker run -p 5678:5678 n8n-custom-image:local"
fi

echo ""

# ==============================================================================
# Phase 3: Dockerfile Environment Check
# ==============================================================================
echo "Phase 3: Dockerfile Environment Check"
echo "--------------------------------------"

if [[ -f "$DOCKERFILE" ]]; then
  # Check for privacy env vars
  if grep -q "N8N_DISABLE_EXTERNAL_COMMUNICATIONS=true" "$DOCKERFILE"; then
    pass "N8N_DISABLE_EXTERNAL_COMMUNICATIONS=true in Dockerfile"
  else
    fail "N8N_DISABLE_EXTERNAL_COMMUNICATIONS not set in Dockerfile"
  fi

  if grep -q "N8N_DIAGNOSTICS_ENABLED=false" "$DOCKERFILE"; then
    pass "N8N_DIAGNOSTICS_ENABLED=false in Dockerfile"
  else
    fail "N8N_DIAGNOSTICS_ENABLED not set to false"
  fi

  if grep -q "N8N_VERSION_NOTIFICATIONS_ENABLED=false" "$DOCKERFILE"; then
    pass "N8N_VERSION_NOTIFICATIONS_ENABLED=false in Dockerfile"
  else
    fail "N8N_VERSION_NOTIFICATIONS_ENABLED not set to false"
  fi

  if grep -q "N8N_TEMPLATES_ENABLED=false" "$DOCKERFILE"; then
    pass "N8N_TEMPLATES_ENABLED=false in Dockerfile"
  else
    fail "N8N_TEMPLATES_ENABLED not set to false"
  fi
else
  warn "Dockerfile not found - skipping env var check"
fi

echo ""

# ==============================================================================
# Phase 4: Known External Endpoints Reference
# ==============================================================================
echo "Phase 4: Known External Endpoints (for firewall/network policy)"
echo "----------------------------------------------------------------"
echo "Block these domains for full isolation:"
echo "  - license.n8n.io (license server)"
echo "  - telemetry.n8n.io (telemetry)"
echo "  - api.n8n.io (templates, version checks)"
echo "  - api.posthog.com (analytics)"
echo "  - api.rudderstack.com (analytics)"
echo "  - *.sentry.io (error reporting)"
echo ""

# ==============================================================================
# Summary
# ==============================================================================
echo "=============================================="
echo " Verification Summary"
echo "=============================================="
echo "  Passed:   $PASSED"
echo "  Failed:   $FAILED"
echo "  Warnings: $WARNINGS"
echo ""

if [[ $FAILED -gt 0 ]]; then
  echo "VERIFICATION FAILED"
  echo "Apply patches with: ./scripts/apply-n8n-patches.sh"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo "VERIFICATION PASSED WITH WARNINGS"
  exit 0
else
  echo "VERIFICATION PASSED"
  exit 0
fi
