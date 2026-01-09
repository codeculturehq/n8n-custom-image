#!/usr/bin/env bash
set -euo pipefail
rg -n "N8N_DISABLE_EXTERNAL_COMMUNICATIONS" Dockerfile
