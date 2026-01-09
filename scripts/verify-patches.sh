#!/usr/bin/env bash
set -euo pipefail
[ -f patches/n8n/0001-disable-external-comms.patch ]
[ -f patches/n8n/0002-noop-telemetry-posthog.patch ]
