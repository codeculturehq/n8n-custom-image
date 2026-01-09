#!/usr/bin/env bash
set -euo pipefail
file="config/egress/allowlist-profiles.json"
python -m json.tool "$file" >/dev/null
