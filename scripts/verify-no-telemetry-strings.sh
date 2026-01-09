#!/usr/bin/env bash
set -euo pipefail
rg -n "N8N_DISABLE_EXTERNAL_COMMUNICATIONS" vendor/n8n/packages/cli/src/telemetry/index.ts
rg -n "N8N_DISABLE_EXTERNAL_COMMUNICATIONS" vendor/n8n/packages/cli/src/posthog/index.ts
rg -n "telemetry.*enabled" vendor/n8n/packages/frontend/editor-ui/src/app/stores/posthog.store.ts
