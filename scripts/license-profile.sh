#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"
output="${2:-.env.license}"

if [ -z "$profile" ]; then
  echo "Usage: $0 <profile> [output-file]" >&2
  exit 1
fi

python3 - <<'PY' "$profile" "$output"
import json
import sys

profile = sys.argv[1]
out_path = sys.argv[2]

with open('config/license/profiles.json', 'r', encoding='utf-8') as fh:
    profiles = json.load(fh)

if profile not in profiles:
    print(f"Unknown profile: {profile}", file=sys.stderr)
    print("Available:", ", ".join(profiles.keys()), file=sys.stderr)
    sys.exit(1)

env = profiles[profile].get('env', {})

lines = [f"{k}={v}" for k, v in env.items()]

with open(out_path, 'w', encoding='utf-8') as out:
    out.write("\n".join(lines) + "\n")

if profile == 'online_test':
    print("WARNING: online_test enabled; disable after testing.", file=sys.stderr)

print(out_path)
PY
