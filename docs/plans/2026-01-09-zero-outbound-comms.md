# Zero Outbound Comms Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a custom n8n image that hard-disables background outbound communications and enforces workflow egress allowlists for Docker and Kubernetes.

**Architecture:** Three layers. (1) Env defaults disable telemetry/updates/templates/banners/license auto-renew. (2) Patch n8n source to hard-disable external comms and remove proxy controllers. (3) Runtime egress deny-all + allowlist profiles in Docker/K8s.

**Tech Stack:** Docker, bash, git patches, Node.js (n8n source), Kubernetes NetworkPolicy/Cilium, JSON config.

### Task 1: Add Allowlist Profiles (Data + Docs)

**Files:**
- Create: `config/egress/allowlist-profiles.json`
- Create: `docs/egress/allowlist-profiles.md`
- Create: `scripts/verify-allowlist-profiles.sh`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
file="config/egress/allowlist-profiles.json"
python -m json.tool "$file" >/dev/null
```

**Step 2: Run test to verify it fails**

Run: `bash scripts/verify-allowlist-profiles.sh`
Expected: FAIL with "No such file or directory".

**Step 3: Write minimal implementation**

`config/egress/allowlist-profiles.json`
```json
{
  "minimal": {
    "description": "RFC1918 + localhost only",
    "allow": ["127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  },
  "standard_saas": {
    "description": "Common business SaaS",
    "allow_domains": [
      "*.slack.com",
      "*.googleapis.com",
      "*.microsoft.com",
      "*.github.com",
      "*.amazonaws.com"
    ]
  },
  "ai_heavy": {
    "description": "AI providers + vector DBs",
    "allow_domains": [
      "api.openai.com",
      "api.anthropic.com",
      "*.googleapis.com",
      "*.pinecone.io",
      "*.weaviate.io"
    ]
  }
}
```

`docs/egress/allowlist-profiles.md`
```md
# Egress Allowlist Profiles

- minimal: RFC1918 + localhost only
- standard_saas: common SaaS domains
- ai_heavy: AI providers + vector DBs
```

`scripts/verify-allowlist-profiles.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
file="config/egress/allowlist-profiles.json"
python -m json.tool "$file" >/dev/null
```

**Step 4: Run test to verify it passes**

Run: `bash scripts/verify-allowlist-profiles.sh`
Expected: PASS (exit 0, no output).

**Step 5: Commit**

```bash
git add config/egress/allowlist-profiles.json docs/egress/allowlist-profiles.md scripts/verify-allowlist-profiles.sh
git commit -m "docs: add egress allowlist profiles"
```

### Task 2: Add Docker + K8s Egress Enforcement Artifacts

**Files:**
- Create: `docker/egress/iptables.rules`
- Create: `docker/docker-compose.egress.yml`
- Create: `k8s/egress/networkpolicy.yaml`
- Create: `k8s/egress/cilium-egress-policy.yaml`
- Create: `scripts/verify-egress-artifacts.sh`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
for f in docker/egress/iptables.rules docker/docker-compose.egress.yml k8s/egress/networkpolicy.yaml; do
  test -f "$f"
done
```

**Step 2: Run test to verify it fails**

Run: `bash scripts/verify-egress-artifacts.sh`
Expected: FAIL with "No such file or directory".

**Step 3: Write minimal implementation**

`docker/egress/iptables.rules`
```
*filter
:OUTPUT DROP [0:0]
-A OUTPUT -d 127.0.0.0/8 -j ACCEPT
-A OUTPUT -d 10.0.0.0/8 -j ACCEPT
-A OUTPUT -d 172.16.0.0/12 -j ACCEPT
-A OUTPUT -d 192.168.0.0/16 -j ACCEPT
COMMIT
```

`docker/docker-compose.egress.yml`
```yaml
services:
  n8n:
    image: codelytvtech/n8n-custom-image:local
    environment:
      - N8N_DISABLE_EXTERNAL_COMMUNICATIONS=true
    cap_add:
      - NET_ADMIN
    command: ["/bin/sh", "-lc", "iptables-restore < /egress/iptables.rules && n8n start"]
    volumes:
      - ./docker/egress/iptables.rules:/egress/iptables.rules:ro
```

`k8s/egress/networkpolicy.yaml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: n8n-egress-deny-all
spec:
  podSelector: { matchLabels: { app: n8n } }
  policyTypes: [Egress]
  egress:
    - to:
        - ipBlock: { cidr: 10.0.0.0/8 }
        - ipBlock: { cidr: 172.16.0.0/12 }
        - ipBlock: { cidr: 192.168.0.0/16 }
```

`k8s/egress/cilium-egress-policy.yaml`
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: n8n-egress-allowlist
spec:
  endpointSelector:
    matchLabels:
      app: n8n
  egress:
    - toEntities:
        - cluster
    - toFQDNs:
        - matchPattern: "*.slack.com"
        - matchPattern: "*.googleapis.com"
```

`scripts/verify-egress-artifacts.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
for f in docker/egress/iptables.rules docker/docker-compose.egress.yml k8s/egress/networkpolicy.yaml; do
  test -f "$f"
done
```

**Step 4: Run test to verify it passes**

Run: `bash scripts/verify-egress-artifacts.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add docker/egress/iptables.rules docker/docker-compose.egress.yml k8s/egress/networkpolicy.yaml k8s/egress/cilium-egress-policy.yaml scripts/verify-egress-artifacts.sh
git commit -m "docs: add docker and k8s egress artifacts"
```

### Task 3: Add Source Build + Patch Pipeline

**Files:**
- Create: `scripts/fetch-n8n-source.sh`
- Create: `scripts/apply-n8n-patches.sh`
- Create: `scripts/verify-patches.sh`
- Create: `patches/n8n/0001-disable-external-comms.patch`
- Create: `patches/n8n/0002-noop-telemetry-posthog.patch`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
[ -f patches/n8n/0001-disable-external-comms.patch ]
[ -f patches/n8n/0002-noop-telemetry-posthog.patch ]
```

**Step 2: Run test to verify it fails**

Run: `bash scripts/verify-patches.sh`
Expected: FAIL (missing patches).

**Step 3: Write minimal implementation**

`scripts/fetch-n8n-source.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
TAG=${1:-"n8n@2.3.2"}
rm -rf vendor/n8n
mkdir -p vendor
GIT_SSH_COMMAND=${GIT_SSH_COMMAND:-""} git clone --depth 1 --branch "$TAG" git@github.com:n8n-io/n8n.git vendor/n8n
```

`scripts/apply-n8n-patches.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
for p in patches/n8n/*.patch; do
  git -C vendor/n8n apply "$p"
done
```

`scripts/verify-patches.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
[ -f patches/n8n/0001-disable-external-comms.patch ]
[ -f patches/n8n/0002-noop-telemetry-posthog.patch ]
```

`patches/n8n/0001-disable-external-comms.patch` (key changes)
```diff
+// external comms hard disable
+const externalCommsDisabled = process.env.N8N_DISABLE_EXTERNAL_COMMUNICATIONS === 'true';
```

**Step 4: Run test to verify it passes**

Run: `bash scripts/verify-patches.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add scripts/fetch-n8n-source.sh scripts/apply-n8n-patches.sh scripts/verify-patches.sh patches/n8n/0001-disable-external-comms.patch patches/n8n/0002-noop-telemetry-posthog.patch
git commit -m "build: add n8n source patch pipeline"
```

### Task 4: Hard-Disable External Comms in n8n (Patch)

**Files:**
- Modify (via patch): `vendor/n8n/packages/cli/src/commands/base-command.ts`
- Modify (via patch): `vendor/n8n/packages/cli/src/server.ts`
- Modify (via patch): `vendor/n8n/packages/cli/src/services/frontend.service.ts`
- Modify (via patch): `vendor/n8n/packages/cli/src/license.ts`
- Create: `scripts/verify-no-external-comms.sh`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
curl -sf http://localhost:5678/rest/settings | jq -e '.telemetry.enabled == false'
```

**Step 2: Run test to verify it fails**

Run: `bash scripts/verify-no-external-comms.sh`
Expected: FAIL (flags still enabled or endpoints available).

**Step 3: Write minimal implementation**

`packages/cli/src/commands/base-command.ts` (patch snippet)
```ts
const externalCommsDisabled = process.env.N8N_DISABLE_EXTERNAL_COMMUNICATIONS === 'true';
if (externalCommsDisabled) {
  this.globalConfig.diagnostics.enabled = false;
  this.globalConfig.versionNotifications.enabled = false;
  this.globalConfig.versionNotifications.whatsNewEnabled = false;
  this.globalConfig.dynamicBanners.enabled = false;
  this.globalConfig.templates.enabled = false;
  this.globalConfig.personalization.enabled = false;
  this.globalConfig.license.autoRenewalEnabled = false;
}
```

`packages/cli/src/server.ts`
```ts
if (!externalCommsDisabled) {
  await import('@/controllers/telemetry.controller');
  await import('@/controllers/posthog.controller');
}
```

`packages/cli/src/services/frontend.service.ts`
```ts
if (externalCommsDisabled) {
  telemetrySettings.enabled = false;
  this.settings.versionNotifications.enabled = false;
  this.settings.versionNotifications.whatsNewEnabled = false;
  this.settings.templates.enabled = false;
  this.settings.dynamicBanners.enabled = false;
}
```

`packages/cli/src/license.ts`
```ts
if (process.env.N8N_DISABLE_EXTERNAL_COMMUNICATIONS === 'true') {
  this.logger.warn('External comms disabled: skipping license init');
  return;
}
```

`scripts/verify-no-external-comms.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
curl -sf http://localhost:5678/rest/settings | jq -e '.telemetry.enabled == false'
! curl -sf http://localhost:5678/rest/telemetry/rudderstack
! curl -sf http://localhost:5678/rest/posthog/decide/
```

**Step 4: Run test to verify it passes**

Run: `bash scripts/verify-no-external-comms.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add patches/n8n/0001-disable-external-comms.patch
git commit -m "fix: hard-disable external comms"
```

### Task 5: No-Op Telemetry/PostHog (Defense-in-Depth)

**Files:**
- Modify (via patch): `vendor/n8n/packages/cli/src/telemetry/index.ts`
- Modify (via patch): `vendor/n8n/packages/cli/src/posthog/index.ts`
- Modify (via patch): `vendor/n8n/packages/frontend/editor-ui/src/app/plugins/telemetry/index.ts`
- Modify (via patch): `vendor/n8n/packages/frontend/editor-ui/src/app/stores/posthog.store.ts`
- Create: `scripts/verify-no-telemetry-strings.sh`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
if rg -n "telemetry\.n8n\.io|posthog" vendor/n8n/packages -g'*.ts' >/dev/null; then
  echo "telemetry/posthog strings still present"
  exit 1
fi
```

**Step 2: Run test to verify it fails**

Run: `bash scripts/verify-no-telemetry-strings.sh`
Expected: FAIL (strings present).

**Step 3: Write minimal implementation**

`packages/cli/src/telemetry/index.ts`
```ts
if (process.env.N8N_DISABLE_EXTERNAL_COMMUNICATIONS === 'true') return;
```

`packages/cli/src/posthog/index.ts`
```ts
if (process.env.N8N_DISABLE_EXTERNAL_COMMUNICATIONS === 'true') return;
```

`packages/frontend/editor-ui/src/app/plugins/telemetry/index.ts`
```ts
if (window?.n8nExternalCommsDisabled) return;
```

`scripts/verify-no-telemetry-strings.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
if rg -n "telemetry\\.n8n\\.io|posthog" vendor/n8n/packages -g'*.ts' >/dev/null; then
  echo "telemetry/posthog strings still present"
  exit 1
fi
```

**Step 4: Run test to verify it passes**

Run: `bash scripts/verify-no-telemetry-strings.sh`
Expected: PASS (no matches).

**Step 5: Commit**

```bash
git add patches/n8n/0002-noop-telemetry-posthog.patch
git commit -m "fix: noop telemetry and posthog"
```

### Task 6: Update Dockerfile to Build from Patched Source

**Files:**
- Modify: `Dockerfile`
- Create: `scripts/build-local.sh`
- Create: `scripts/verify-dockerfile.sh`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
rg -n "N8N_DISABLE_EXTERNAL_COMMUNICATIONS" Dockerfile
```

**Step 2: Run test to verify it fails**

Run: `bash scripts/verify-dockerfile.sh`
Expected: FAIL (env not set).

**Step 3: Write minimal implementation**

`Dockerfile` (additions)
```Dockerfile
ARG N8N_TAG=n8n@2.3.2
ENV N8N_DISABLE_EXTERNAL_COMMUNICATIONS=true \
    N8N_DIAGNOSTICS_ENABLED=false \
    N8N_VERSION_NOTIFICATIONS_ENABLED=false \
    N8N_VERSION_NOTIFICATIONS_WHATS_NEW_ENABLED=false \
    N8N_DYNAMIC_BANNERS_ENABLED=false \
    N8N_TEMPLATES_ENABLED=false \
    N8N_PERSONALIZATION_ENABLED=false \
    N8N_LICENSE_AUTO_RENEW_ENABLED=false
```

`scripts/verify-dockerfile.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
rg -n "N8N_DISABLE_EXTERNAL_COMMUNICATIONS" Dockerfile
```

`scripts/build-local.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
docker build -t n8n-custom-image:local .
```

**Step 4: Run test to verify it passes**

Run: `bash scripts/verify-dockerfile.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add Dockerfile scripts/build-local.sh scripts/verify-dockerfile.sh
git commit -m "build: harden docker image defaults"
```

### Task 7: End-to-End Verification Script

**Files:**
- Create: `scripts/verify-no-external-runtime.sh`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail
curl -sf http://localhost:5678/rest/telemetry/health
```

**Step 2: Run test to verify it fails**

Run: `bash scripts/verify-no-external-runtime.sh`
Expected: FAIL (endpoint still available or settings enabled).

**Step 3: Write minimal implementation**

`scripts/verify-no-external-runtime.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
curl -sf http://localhost:5678/rest/settings | jq -e '.telemetry.enabled == false'
! curl -sf http://localhost:5678/rest/telemetry/rudderstack
! curl -sf http://localhost:5678/rest/posthog/decide/
```

**Step 4: Run test to verify it passes**

Run: `bash scripts/verify-no-external-runtime.sh`
Expected: PASS (exit 0).

**Step 5: Commit**

```bash
git add scripts/verify-no-external-runtime.sh
git commit -m "test: add runtime no-egress checks"
```

## Final Verification (after all tasks)
- `bash scripts/verify-allowlist-profiles.sh`
- `bash scripts/verify-egress-artifacts.sh`
- `bash scripts/verify-no-external-comms.sh`
- `bash scripts/verify-no-external-runtime.sh`
- `docker build -t n8n-custom-image:local .`
