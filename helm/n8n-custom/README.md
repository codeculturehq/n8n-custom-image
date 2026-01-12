# n8n-custom Helm Chart

GDPR-compliant n8n workflow automation with privacy-first defaults.

## Features

- **Privacy-first defaults**: All telemetry, analytics, and external communications disabled by default
- **GDPR/DSGVO compliant**: Meets European data protection requirements
- **License management**: Offline mode, pre-loaded certificates, GDPR feature overrides
- **Network policies**: Configurable egress profiles (minimal, saas, ai-providers, custom)
- **Flexible database**: SQLite or PostgreSQL support
- **Queue mode**: Redis-backed scaling for high availability

## Installation

### Quick Start (GDPR-compliant defaults)

```bash
helm install n8n ./helm/n8n-custom \
  --namespace n8n \
  --create-namespace
```

### With PostgreSQL

```bash
helm install n8n ./helm/n8n-custom \
  --namespace n8n \
  --create-namespace \
  --set database.type=postgres \
  --set database.postgres.host=postgres.database.svc \
  --set database.postgres.password=your-password
```

### With Ingress

```bash
helm install n8n ./helm/n8n-custom \
  --namespace n8n \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=n8n.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

### Air-gapped Deployment

```bash
helm install n8n ./helm/n8n-custom \
  --namespace n8n \
  --create-namespace \
  --set license.offlineMode=true \
  --set license.serviceEnabled=false \
  --set networkPolicy.enabled=true \
  --set networkPolicy.profile=minimal
```

### With GDPR Feature Overrides

```bash
helm install n8n ./helm/n8n-custom \
  --namespace n8n \
  --create-namespace \
  --set license.gdprOverrides.enabled=true \
  --set license.gdprOverrides.forcePlan=Enterprise \
  --set license.gdprOverrides.forceFeatures="feat:sharing,feat:ldap"
```

## Configuration

### Privacy Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `privacy.disableExternalCommunications` | Disable all external API calls | `true` |
| `privacy.disableDiagnostics` | Disable telemetry | `true` |
| `privacy.disableVersionNotifications` | Disable version checks | `true` |
| `privacy.disableTemplates` | Disable workflow templates | `true` |
| `privacy.disablePersonalization` | Disable personalization | `true` |
| `privacy.disableAI` | Disable AI features | `true` |

### License Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `license.serviceEnabled` | Enable license service | `false` |
| `license.offlineMode` | Offline mode (no license server) | `true` |
| `license.autoRenewEnabled` | Auto-renew license | `false` |
| `license.activationKey` | License activation key | `""` |
| `license.certificate` | Pre-loaded license cert (base64) | `""` |
| `license.existingSecret` | Use existing secret | `""` |

### GDPR Feature Overrides

| Parameter | Description | Default |
|-----------|-------------|---------|
| `license.gdprOverrides.enabled` | Enable GDPR overrides | `false` |
| `license.gdprOverrides.forcePlan` | Force plan name | `""` |
| `license.gdprOverrides.forceFeatures` | Force-enable features | `""` |
| `license.gdprOverrides.blockFeatures` | Force-disable features | `""` |
| `license.gdprOverrides.quotas` | Quota overrides (map) | `{}` |

### Network Policy

| Parameter | Description | Default |
|-----------|-------------|---------|
| `networkPolicy.enabled` | Enable network policies | `true` |
| `networkPolicy.profile` | Profile: minimal, saas, ai-providers, custom | `minimal` |
| `networkPolicy.additionalEgress` | Custom egress rules (for custom profile) | `[]` |

### Database

| Parameter | Description | Default |
|-----------|-------------|---------|
| `database.type` | Database type: sqlite or postgres | `sqlite` |
| `database.sqlite.path` | SQLite file path | `/home/node/.n8n/database.sqlite` |
| `database.postgres.host` | PostgreSQL host | `""` |
| `database.postgres.port` | PostgreSQL port | `5432` |
| `database.postgres.database` | Database name | `n8n` |
| `database.postgres.user` | Database user | `n8n` |
| `database.postgres.password` | Database password | `""` |
| `database.postgres.existingSecret` | Use existing secret | `""` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.storageClass` | Storage class | `""` |
| `persistence.accessMode` | Access mode | `ReadWriteOnce` |
| `persistence.size` | Storage size | `10Gi` |
| `persistence.existingClaim` | Use existing PVC | `""` |

## Network Policy Profiles

### minimal (default, GDPR-compliant)
- Only allows traffic to RFC1918 private ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- No internet egress
- Suitable for air-gapped and high-security environments

### saas
- Allows HTTPS (443) to internet
- Suitable for SaaS integrations (Slack, Google, Microsoft, etc.)

### ai-providers
- Allows HTTPS (443) to internet
- Suitable for AI provider integrations (OpenAI, Anthropic, etc.)

### custom
- Uses `networkPolicy.additionalEgress` for custom rules
- Combine with specific egress rules for your environment

## Upgrading

```bash
helm upgrade n8n ./helm/n8n-custom --namespace n8n
```

## Uninstalling

```bash
helm uninstall n8n --namespace n8n
```

Note: PersistentVolumeClaims are not deleted automatically. Remove manually if needed:

```bash
kubectl delete pvc -l app.kubernetes.io/name=n8n-custom -n n8n
```

## Related Documentation

- [Air-Gapped Deployment Guide](../docs/AIR-GAPPED-DEPLOYMENT.md)
- [License Toggle Guide](../docs/license/toggle.md)
- [Cilium L7 Policies](../k8s/egress/cilium-egress-policy.yaml)
- [Standard NetworkPolicies](../k8s/egress/networkpolicy.yaml)
