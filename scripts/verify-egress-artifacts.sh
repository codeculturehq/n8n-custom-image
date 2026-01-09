#!/usr/bin/env bash
set -euo pipefail
for f in docker/egress/iptables.rules docker/docker-compose.egress.yml k8s/egress/networkpolicy.yaml; do
  test -f "$f"
done
