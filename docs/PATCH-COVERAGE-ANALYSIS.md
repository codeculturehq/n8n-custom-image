# n8n v2.x Patch Coverage Analysis

**Analysis Date:** 2026-01-11
**n8n Version Analyzed:** 2.3.2
**Status:** GAPS IDENTIFIED - Additional patches recommended

---

## Executive Summary

Our current v2 patches (`patches/n8n/v2/`) cover the **primary telemetry and analytics endpoints** but miss several **secondary external communication channels**. This document details all external endpoints found in n8n v2.x source code and their patch coverage status.

### Coverage Statistics
- **Covered Endpoints:** 9/15 (60%)
- **Partially Covered:** 2/15 (13%)
- **Not Covered:** 4/15 (27%)

---

## Complete External Endpoint Inventory

### 1. PostHog Analytics ✅ COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://us.i.posthog.com` | `@n8n/config/src/configs/diagnostics.config.ts:11` | ✅ Full |

**How Patched:**
- `0001-disable-external-comms.patch`: Sets `posthog.enabled = false` in frontend settings
- `0002-noop-telemetry-posthog.patch`: Adds early return in `posthog/index.ts` init()

**Verification:** When `N8N_DISABLE_EXTERNAL_COMMUNICATIONS=true`:
- Backend: `globalConfig.diagnostics.enabled` set to false
- Frontend: `posthog.enabled` setting propagated as false
- Defense-in-depth: Early return prevents initialization even if config check fails

---

### 2. Telemetry (RudderStack) ✅ COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://telemetry.n8n.io` (frontend) | `diagnostics.config.ts:15` | ✅ Full |
| `https://telemetry.n8n.io` (backend) | `diagnostics.config.ts:20` | ✅ Full |

**How Patched:**
- `0001-disable-external-comms.patch`: Sets `telemetry.enabled = false`
- `0002-noop-telemetry-posthog.patch`: Adds early return in `telemetry/index.ts` init()

---

### 3. License Server ✅ COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://license.n8n.io/v1` | `@n8n/config/src/configs/license.config.ts` | ✅ Full |

**How Patched:**
- `0003-license-feature-overrides.patch`:
  - Sets `offlineMode = true` when external comms disabled
  - Overrides `serverUrl` to empty string
  - Adds GDPR feature/quota override env vars

---

### 4. Version Notifications ✅ COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://api.n8n.io/api/versions/` | `version-notifications.config.ts:11` | ✅ Full |
| `https://api.n8n.io/api/whats-new` | `version-notifications.config.ts:19` | ✅ Full |

**How Patched:**
- `0001-disable-external-comms.patch`:
  - Backend: `globalConfig.versionNotifications.enabled = false`
  - Frontend: `versionNotifications.enabled && !externalCommsDisabled`

**Frontend Guard:** `versions.store.ts` checks `enabled` from settings before `fetchVersions()`

---

### 5. Dynamic Banners ✅ COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://api.n8n.io/api/banners` | `dynamic-banners.config.ts:6` | ✅ Full |

**How Patched:**
- `0001-disable-external-comms.patch`:
  - Backend: `globalConfig.dynamicBanners.enabled = false`
  - Frontend: `dynamicBanners.enabled && !externalCommsDisabled`

---

### 6. Templates API ✅ COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://api.n8n.io/api/` | `templates.config.ts:11` | ✅ Full |

**How Patched:**
- `0001-disable-external-comms.patch`:
  - Backend: `globalConfig.templates.enabled = false`
  - Frontend: `templates.enabled && !externalCommsDisabled`

**Frontend Guard:** `templates.store.ts` uses `settingsStore.templatesHost` only when templates enabled

---

### 7. Sentry Error Reporting ✅ COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| Backend DSN (configurable) | `sentry.config.ts:6` (`N8N_SENTRY_DSN`) | ✅ Full |
| Frontend DSN (configurable) | `sentry.config.ts:10` (`N8N_FRONTEND_SENTRY_DSN`) | ✅ Full |

**How Patched:**
- `0001-disable-external-comms.patch`:
  - `globalConfig.sentry.backendDsn = ''`
  - `globalConfig.sentry.frontendDsn = ''`

---

### 8. Personalization Survey ✅ COVERED

| Feature | Location | Coverage |
|---------|----------|----------|
| Personalization flow | `frontend.service.ts` | ✅ Full |

**How Patched:**
- `0001-disable-external-comms.patch`:
  - Backend: `globalConfig.personalization.enabled = false`
  - Frontend: `personalizationSurveyEnabled && !externalCommsDisabled`

---

### 9. AI Workflow Builder Templates ⚠️ PARTIALLY COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://api.n8n.io/api/templates/search` | `ai-workflow-builder.ee/src/tools/web/templates.ts:14` | ⚠️ Partial |
| `https://api.n8n.io/api/workflows/templates/{id}` | `ai-workflow-builder.ee/src/tools/web/templates.ts:95` | ⚠️ Partial |

**Current State:**
- These are enterprise-edition (`.ee`) features
- Gated by `N8N_AI_ENABLED` env var (must be explicitly enabled)
- **NOT gated by `N8N_DISABLE_EXTERNAL_COMMUNICATIONS`**

**Risk Level:** LOW - Requires explicit AI enablement

**Recommendation:** Add check for `N8N_DISABLE_EXTERNAL_COMMUNICATIONS` in AI workflow builder or document that `N8N_AI_ENABLED` should remain `false` for air-gapped deployments.

---

### 10. Email Signup/Onboarding ⚠️ PARTIALLY COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://api.n8n.io/api/accounts/onboarding` | `workflow-webhooks.ts:4-5` | ⚠️ Partial |

**Current State:**
- Called by `submitEmailOnSignup()` in `users.store.ts`
- Called from `SetupView.vue` and `SignupView.vue`
- **NOT gated by `N8N_DISABLE_EXTERNAL_COMMUNICATIONS`**

**Risk Level:** MEDIUM - Called during initial setup flow

**Recommendation:** Create patch to check `externalCommsDisabled` before `submitEmailOnSignup()` call in users.store.ts

---

### 11. Community Packages - NPM Registry ❌ NOT COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://registry.npmjs.org` | `community-packages.service.ts:41` | ❌ None |

**Current State:**
- Used for community package installation
- Controllable via `N8N_COMMUNITY_PACKAGES_ENABLED=false` env var
- Controllable via `N8N_COMMUNITY_PACKAGES_REGISTRY` for custom registry
- **NOT automatically disabled by `N8N_DISABLE_EXTERNAL_COMMUNICATIONS`**

**Risk Level:** MEDIUM - User action required (installing packages)

**Recommendation:**
1. Document that `N8N_COMMUNITY_PACKAGES_ENABLED=false` should be set for air-gapped
2. OR add to `0001` patch: `this.globalConfig.communityPackages.enabled = false`

---

### 12. Community Packages - Package Status ❌ NOT COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://api.n8n.io/api/package` | `community-packages.service.ts:251` | ❌ None |

**Current State:**
- Called by `checkNpmPackageStatus()` during package installation
- Graceful failure (silent catch, returns OK status)
- **NOT gated by any env var**

**Risk Level:** LOW - Only during package install, fails gracefully

**Recommendation:** Add check for `N8N_DISABLE_EXTERNAL_COMMUNICATIONS` or rely on community packages being disabled

---

### 13. Community Packages - Vetted Nodes List ❌ NOT COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://api.n8n.io/api/community-nodes` | `community-node-types-utils.ts:25` | ❌ None |
| `https://api-staging.n8n.io/api/community-nodes` | `community-node-types-utils.ts:24` | ❌ None |

**Current State:**
- Called by `getCommunityNodeTypes()` for reinstalling missing packages
- Only called when `N8N_REINSTALL_MISSING_PACKAGES=true`
- **NOT gated by `N8N_DISABLE_EXTERNAL_COMMUNICATIONS`**

**Risk Level:** LOW - Only with explicit reinstall setting

**Recommendation:** Add check or document `N8N_REINSTALL_MISSING_PACKAGES` should remain `false`

---

### 14. NPM Package Count Search ❌ NOT COVERED

| Endpoint | Location | Coverage |
|----------|----------|----------|
| `https://api.npms.io/v2/search` | `communityNodes.ts:42` | ❌ None |

**Current State:**
- Called by `getAvailableCommunityPackageCount()` in frontend
- Called from `SettingsCommunityNodesView.vue`
- Gated by `communityNodesEnabled` setting
- **NOT automatically disabled by `N8N_DISABLE_EXTERNAL_COMMUNICATIONS`**

**Risk Level:** LOW - UI display only, depends on community nodes being enabled

**Recommendation:** Disable community nodes feature when external comms disabled

---

### 15. N8N IO Base URL (Constants) ⚠️ INFORMATIONAL

| Constant | Location | Usage |
|----------|----------|-------|
| `N8N_IO_BASE_URL = 'https://api.n8n.io/api/'` | `@n8n/constants/src/api.ts:1` | Various |

**Note:** This is a constant used by multiple features. Coverage depends on the feature using it.

---

## Recommended Additional Patches

### Patch 4: Disable Community Packages When External Comms Disabled

Add to `0001-disable-external-comms.patch` in `base-command.ts`:

```diff
if (externalCommsDisabled) {
    this.globalConfig.diagnostics.enabled = false;
    // ... existing ...
+   // Disable community packages to prevent NPM/API calls
+   Container.get(CommunityPackagesConfig).enabled = false;
}
```

### Patch 5: Guard Email Signup

Create new patch for `users.store.ts`:

```diff
const submitContactEmail = async (email: string, agree: boolean) => {
+   const externalCommsDisabled = process.env.N8N_DISABLE_EXTERNAL_COMMUNICATIONS === 'true';
+   if (externalCommsDisabled) {
+       return null;
+   }
    if (currentUser.value) {
        return await onboardingApi.submitEmailOnSignup(
```

---

## Environment Variables for Complete Isolation

For air-gapped deployment, use the complete secure stack:

```bash
# Use the production-ready docker-compose
docker compose -f docker/docker-compose.secure.yml --env-file docker/.env.secure up -d
```

The `docker-compose.secure.yml` includes ALL of these variables pre-configured:

```bash
# Primary control (our patches check this)
N8N_DISABLE_EXTERNAL_COMMUNICATIONS=true

# Backup/belt-and-suspenders (native n8n env vars)
N8N_DIAGNOSTICS_ENABLED=false
N8N_VERSION_NOTIFICATIONS_ENABLED=false
N8N_TEMPLATES_ENABLED=false
N8N_PERSONALIZATION_ENABLED=false
N8N_LICENSE_AUTO_RENEW_ENABLED=false
N8N_HIRING_BANNER_ENABLED=false
N8N_ONBOARDING_FLOW_DISABLED=true
N8N_AI_ENABLED=false

# Community packages
N8N_COMMUNITY_PACKAGES_ENABLED=false
N8N_REINSTALL_MISSING_PACKAGES=false
```

See: [`docker/docker-compose.secure.yml`](../docker/docker-compose.secure.yml)

---

## Verification Matrix

| Feature | Env Var Check | Frontend Setting | Backend Config | Early Return |
|---------|---------------|------------------|----------------|--------------|
| PostHog | ✅ | ✅ | ✅ | ✅ |
| Telemetry | ✅ | ✅ | ✅ | ✅ |
| License | ✅ | N/A | ✅ | ✅ |
| Versions | ✅ | ✅ | ✅ | ❌ |
| Banners | ✅ | ✅ | ✅ | ❌ |
| Templates | ✅ | ✅ | ✅ | ❌ |
| Sentry | ✅ | ✅ | ✅ | N/A |
| Personalization | ✅ | ✅ | ✅ | ❌ |
| AI Builder | ❌ | ❌ | N/A | ❌ |
| Email Signup | ❌ | ❌ | N/A | ❌ |
| Community Pkgs | ❌ | ❌ | ❌ | ❌ |

---

## Conclusion

**Current patches provide 60% coverage** of external communication points, focusing on the most impactful analytics and telemetry endpoints.

**For full GDPR/air-gapped compliance:**
1. Apply existing patches (primary protection)
2. Set recommended environment variables (defense-in-depth)
3. Consider creating additional patches for community packages and email signup
4. Document that `N8N_AI_ENABLED` must remain `false` for isolated deployments

The gaps identified are **low-to-medium risk** because they either:
- Require explicit user action (community package installation)
- Are gated by other feature flags (`N8N_AI_ENABLED`)
- Have graceful failure modes (package status check)
