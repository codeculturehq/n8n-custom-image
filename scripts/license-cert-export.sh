#!/usr/bin/env bash
set -euo pipefail

backend="${1:-}"
output="${2:-license.cert}"

if [ -z "$backend" ]; then
  echo "Usage: $0 <postgres|sqlite> [output-file]" >&2
  exit 1
fi

case "$backend" in
  postgres)
    if [ -z "${PGHOST:-}" ]; then
      echo "PGHOST not set" >&2
      exit 1
    fi
    if [ -z "${PGDATABASE:-}" ]; then
      echo "PGDATABASE not set" >&2
      exit 1
    fi
    # uses libpq env vars: PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD
    psql -t -c "select value from settings where key='license.cert';" | awk 'NF{print; exit}' > "$output"
    ;;
  sqlite)
    if [ -z "${SQLITE_PATH:-}" ]; then
      echo "SQLITE_PATH not set" >&2
      exit 1
    fi
    sqlite3 "$SQLITE_PATH" "select value from settings where key='license.cert';" > "$output"
    ;;
  *)
    echo "Unknown backend: $backend" >&2
    exit 1
    ;;
esac

if [ ! -s "$output" ]; then
  echo "No certificate found" >&2
  exit 1
fi

echo "$output"
