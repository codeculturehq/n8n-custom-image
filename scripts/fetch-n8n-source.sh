#!/usr/bin/env bash
set -euo pipefail
TAG=${1:-"n8n@2.3.2"}

if command -v trash >/dev/null 2>&1; then
  if [ -d vendor/n8n ]; then
    trash vendor/n8n
  fi
else
  echo "trash is required for safe delete" >&2
  exit 1
fi

mkdir -p vendor
if [ -n "${GIT_SSH_COMMAND:-}" ]; then
  env GIT_SSH_COMMAND="$GIT_SSH_COMMAND" git clone --depth 1 --branch "$TAG" git@github.com:n8n-io/n8n.git vendor/n8n
else
  git clone --depth 1 --branch "$TAG" git@github.com:n8n-io/n8n.git vendor/n8n
fi
