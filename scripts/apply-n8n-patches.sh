#!/usr/bin/env bash
set -euo pipefail
root_dir="$(pwd)"
for p in patches/n8n/*.patch; do
  git -C vendor/n8n apply "$root_dir/$p"
done
