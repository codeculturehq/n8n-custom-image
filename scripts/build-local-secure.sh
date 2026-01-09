#!/usr/bin/env bash
set -euo pipefail
docker build -t n8n-custom-image-secure:local -f Dockerfile.secure .
