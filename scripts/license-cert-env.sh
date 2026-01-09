#!/usr/bin/env bash
set -euo pipefail

cert_file="${1:-license.cert}"
output="${2:-.env.license}"

if [ ! -f "$cert_file" ]; then
  echo "Cert file not found: $cert_file" >&2
  exit 1
fi

cert_value=$(cat "$cert_file")
if [ -z "$cert_value" ]; then
  echo "Cert file empty: $cert_file" >&2
  exit 1
fi

cat <<ENV > "$output"
N8N_LICENSE_CERT=$cert_value
N8N_LICENSE_SERVICE_ENABLED=false
N8N_LICENSE_OFFLINE_MODE=true
N8N_LICENSE_AUTO_RENEW_ENABLED=false
ENV

echo "$output"
