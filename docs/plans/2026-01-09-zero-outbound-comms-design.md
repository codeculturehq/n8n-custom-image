# Zero Outbound Comms Design

**Date:** 2026-01-09

## Goal
Custom n8n image with **zero background outbound communication** (telemetry, analytics, updates, templates, banners, license checks). Workflow traffic remains allowed via **explicit allowlist profiles** and enforced at multiple layers.

## Non-Goals
- No changes to user-defined workflow behavior beyond egress allowlist.
- No dependency audit or runtime packet capture in this phase.
- No SaaS analytics or external monitoring.

## Architecture (Layered Controls)
1) **Config Kill-Switch**
- Default env disables diagnostics, updates, templates, banners, personalization, Sentry, license auto-renew.
- Ensures features are off even without code patch.

2) **Code Hard-Disable (Recommended)**
- Patch n8n to hard-disable telemetry/PostHog init, proxies, and remote fetchers.
- Skip controller registration (`/telemetry`, `/posthog`).
- Force settings payload to disable version checks, templates, banners.
- Skip license server auto-renew and background calls.

3) **Network Enforcement**
- Docker: iptables/egress proxy deny-all, allowlist profiles.
- Kubernetes: NetworkPolicy + egress gateway/proxy (or Cilium FQDN policies).
- DNS sinkhole for known telemetry domains as final guard.

## Allowlist Profiles (Workflow Egress)
- **Minimal**: localhost + RFC1918 only.
- **Standard SaaS**: common business APIs (Slack, Google, MS, GitHub, AWS, etc.).
- **AI-heavy**: OpenAI/Anthropic/Google AI + vector DBs.

Profiles are explicit JSON/YAML and referenced by Docker/K8s configs and proxy rules.

## Data Flow Summary
- Startup: config forces external features off; telemetry is no-op.
- UI: settings reflect disabled features; no calls to n8n API for updates/banners/templates.
- Runtime: workflow HTTP calls pass through allowlist enforcement layer.

## Risks
- Upstream n8n changes may add new background endpoints.
- Domain allowlist in K8s requires egress proxy or FQDN-aware CNI.
- License features will be limited if license server access is blocked.

## Success Criteria
- Zero background outbound calls in default image.
- Explicit allowlist controls workflow egress.
- CI script verifies settings flags + disabled endpoints.
