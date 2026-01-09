# n8n Security & DSGVO (GDPR) Analysis (Open Source v2.x)

**Scope**
- Source: `n8n@2.3.2` tag (latest 2.x at review time). Repo path: `/Users/codeculture/Projects/oss/n8n`.
- Static code review only (no runtime traffic capture, no dependency audit).
- Focus: background/automatic outbound calls, trackers, licensing, telemetry, and DSGVO impact.

## Executive Summary
n8n self‑hosted includes multiple **default‑enabled** background services that phone home to n8n‑controlled infrastructure (telemetry, PostHog analytics, version notifications, templates, banners) plus optional Sentry error reporting and license checks. These are configurable via environment variables and can be fully disabled or redirected. Telemetry is fairly rich (instance ID, system configuration, workflow metadata and node graphs for manual runs). GDPR relevance depends on your deployment role and whether telemetry is enabled.

## Background / Automatic Outbound Calls (Self‑Hosted Defaults)
**Diagnostics / Telemetry (RudderStack + PostHog)**
- Default on: `N8N_DIAGNOSTICS_ENABLED=true`.
- Backend telemetry data plane: `https://telemetry.n8n.io`.
- Frontend telemetry JS loader: `https://cdn-rs.n8n.io/v1/ra.min.js`.
- RudderStack source config fetch: `https://api-rs.n8n.io/sourceConfig`.
- PostHog backend + frontend: `https://us.i.posthog.com` (proxy via `/posthog`).
- Evidence: `packages/@n8n/config/src/configs/diagnostics.config.ts`, `packages/cli/src/telemetry/index.ts`, `packages/cli/src/controllers/telemetry.controller.ts`, `packages/cli/src/controllers/posthog.controller.ts`, `packages/frontend/editor-ui/src/app/plugins/telemetry/index.ts`, `packages/frontend/editor-ui/src/app/stores/posthog.store.ts`.

**Version Notifications & “What’s New”**
- Default on: `N8N_VERSION_NOTIFICATIONS_ENABLED=true`.
- Endpoints: `https://api.n8n.io/api/versions/`, `https://api.n8n.io/api/whats-new`.
- Evidence: `packages/@n8n/config/src/configs/version-notifications.config.ts`, `packages/frontend/editor-ui/src/app/stores/versions.store.ts`.

**Dynamic Banners**
- Default on: `https://api.n8n.io/api/banners`.
- Evidence: `packages/@n8n/config/src/configs/dynamic-banners.config.ts`, `packages/frontend/editor-ui/src/features/shared/banners/banners.store.ts`.

**Templates**
- Default on: `https://api.n8n.io/api/` (templates API), plus redirects to `https://n8n.io/workflows/`.
- Adds UTM params containing instance URL, version, active workflow count, and optional user role.
- Evidence: `packages/@n8n/config/src/configs/templates.config.ts`, `packages/frontend/editor-ui/src/features/workflows/templates/templates.store.ts`, `packages/frontend/editor-ui/src/app/constants/urls.ts`.

**License Server**
- Default license server: `https://license.n8n.io/v1` with auto‑renew on.
- Evidence: `packages/@n8n/config/src/configs/license.config.ts`, `packages/cli/src/license.ts`.

**Sentry Error Reporting (Optional)**
- Enabled only if DSN is configured (`N8N_SENTRY_DSN` / `N8N_FRONTEND_SENTRY_DSN`).
- Evidence: `packages/@n8n/config/src/configs/sentry.config.ts`, `packages/core/src/errors/error-reporter.ts`, `packages/frontend/editor-ui/src/app/plugins/sentry.ts`.

## Telemetry Payload (Privacy‑Relevant)
**Identifiers**
- `instanceId` is stable and derived from encryption key (pseudonymous but persistent).
- Evidence: `packages/core/src/instance-settings/instance-settings.ts`.

**System / Config**
- OS type/version, CPU model/speed, memory, DB type, execution settings, deployment type, metrics flags, license plan, etc.
- Evidence: `packages/cli/src/events/relays/telemetry.event-relay.ts`.

**Workflow/Execution Metadata**
- Workflow IDs, user IDs, node graphs (manual runs), error messages, node types/IDs, webhook origin domain.
- HTTP Request nodes include domain base + sanitized path.
- Evidence: `packages/cli/src/events/relays/telemetry.event-relay.ts`, `packages/workflow/src/telemetry-helpers.ts`.

**Personalization Survey**
- Survey answers tracked via telemetry when enabled.
- Evidence: `packages/cli/src/events/relays/telemetry.event-relay.ts`.

**License Metrics to License Server**
- Counts of workflows/users/executions plus up to 1000 active workflow IDs.
- Evidence: `packages/cli/src/metrics/license-metrics.service.ts`.

**IP Handling**
- RudderStack events set IP to `0.0.0.0` to avoid IP capture.
- Evidence: `packages/cli/src/telemetry/index.ts`, `packages/frontend/editor-ui/src/app/plugins/telemetry/index.ts`.

## DSGVO/GDPR Impact Assessment (High‑Level)
**Roles**
- Self‑hosted: you are data controller; n8n becomes a separate controller for telemetry it receives.
- Cloud: n8n acts as processor for workflow data; also controller for its diagnostics stack.

**Potential Personal Data**
- Pseudonymous identifiers (instanceId, userId), system metadata, workflow metadata, errors, survey answers.
- Risk of accidental personal data in error messages or node metadata.

**Lawful Basis (typical)**
- Telemetry / analytics: legitimate interest, but opt‑in recommended for EU deployments.
- License checks: contract necessity (if using licensed features).

**International Transfers**
- PostHog host is US‑based by default; cross‑border transfer likely.
- RudderStack + n8n telemetry endpoints are external services; DPA/SCCs required if enabled.

**Data Minimization**
- IP redaction and path anonymization exist, but workflow and execution metadata is still extensive.

## Security Considerations
- Telemetry and PostHog proxy endpoints are unauthenticated (rate‑limited). Harden at ingress/WAF.
- Metrics endpoint is off by default; protect when enabled (`/metrics`).
- Sentry backend excludes cookies/headers/body; URL only.

## Recommended Hardening (Custom Build / Ops)
**Disable all background outbound calls**
```bash
N8N_DIAGNOSTICS_ENABLED=false
N8N_PERSONALIZATION_ENABLED=false
N8N_VERSION_NOTIFICATIONS_ENABLED=false
N8N_VERSION_NOTIFICATIONS_WHATS_NEW_ENABLED=false
N8N_DYNAMIC_BANNERS_ENABLED=false
N8N_TEMPLATES_ENABLED=false
N8N_SENTRY_DSN=
N8N_FRONTEND_SENTRY_DSN=
```

**License**
```bash
N8N_LICENSE_AUTO_RENEW_ENABLED=false
N8N_LICENSE_SERVICE_ENABLED=false    # disable remote calls; offline license only
N8N_LICENSE_OFFLINE_MODE=true        # force offline mode (optional)
N8N_LICENSE_SERVER_URL_OVERRIDE=     # optional internal proxy
```
To temporarily test license activation/renewal, set `N8N_LICENSE_SERVICE_ENABLED=true`.

Profiles: `config/license/profiles.json` (apply via `scripts/license-profile.sh`).

**Redirect to internal services (if you must keep features)**
- `N8N_DIAGNOSTICS_CONFIG_BACKEND`, `N8N_DIAGNOSTICS_CONFIG_FRONTEND`
- `N8N_DIAGNOSTICS_POSTHOG_API_HOST`
- `N8N_VERSION_NOTIFICATIONS_ENDPOINT`, `N8N_VERSION_NOTIFICATIONS_WHATS_NEW_ENDPOINT`
- `N8N_DYNAMIC_BANNERS_ENDPOINT`, `N8N_TEMPLATES_HOST`

## Notes / Limitations
- No runtime trace or packet capture; only static review of v2.3.2 source.
- Node executions can call any external service by workflow design (user‑initiated, not background).
- Community packages pull from `https://registry.npmjs.org` when enabled and used.

## Evidence Map (Key Files)
- Telemetry: `packages/cli/src/telemetry/index.ts`, `packages/cli/src/events/relays/telemetry.event-relay.ts`
- Diagnostics config: `packages/@n8n/config/src/configs/diagnostics.config.ts`
- Version notifications: `packages/@n8n/config/src/configs/version-notifications.config.ts`
- Templates: `packages/@n8n/config/src/configs/templates.config.ts`, `packages/frontend/editor-ui/src/features/workflows/templates/templates.store.ts`
- Banners: `packages/@n8n/config/src/configs/dynamic-banners.config.ts`
- License: `packages/@n8n/config/src/configs/license.config.ts`, `packages/cli/src/license.ts`
- Sentry: `packages/@n8n/config/src/configs/sentry.config.ts`, `packages/core/src/errors/error-reporter.ts`
