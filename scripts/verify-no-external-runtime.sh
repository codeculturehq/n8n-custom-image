#!/usr/bin/env bash
set -euo pipefail
curl -sf http://localhost:5678/rest/settings | jq -e '(.data.telemetry.enabled == false) or (.data.telemetry == null)'
! curl -sf http://localhost:5678/rest/telemetry/rudderstack
! curl -sf http://localhost:5678/rest/posthog/decide/
