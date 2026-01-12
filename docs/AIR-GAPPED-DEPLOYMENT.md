# Air-Gapped Deployment Guide

Complete guide for deploying n8n-custom-image in environments with no internet connectivity.

## Overview

Air-gapped deployments are common in:
- Government and military networks
- Financial institutions with strict security policies
- Healthcare systems (HIPAA compliance)
- Industrial control systems (ICS/SCADA)
- GDPR/DSGVO compliant environments

This guide covers complete offline deployment including image transfer, license management, and network isolation verification.

## Prerequisites

### Source Environment (Internet-Connected)
- Docker installed
- Access to Docker Hub or this repository
- Ability to export files to transfer medium (USB, secure file transfer)

### Target Environment (Air-Gapped)
- Docker or Kubernetes installed
- Container registry (optional but recommended)
- PostgreSQL or SQLite for n8n database
- Network isolation verified

## Step 1: Export Docker Images

### Option A: Direct Docker Save

```bash
# Pull the secure image
docker pull tinod/n8n-custom-image-secure:latest

# Save to tar archive
docker save tinod/n8n-custom-image-secure:latest -o n8n-custom-image-secure.tar

# Compress for transfer (optional)
gzip n8n-custom-image-secure.tar
# Result: n8n-custom-image-secure.tar.gz (~800MB)
```

### Option B: Build Locally Then Export

```bash
# Clone repository
git clone https://github.com/your-org/n8n-custom-image.git
cd n8n-custom-image

# Build secure image locally
docker build --build-arg N8N_VERSION=2.3.2 \
  -f Dockerfile.secure \
  -t n8n-custom-image-secure:2.3.2 .

# Export
docker save n8n-custom-image-secure:2.3.2 -o n8n-secure-2.3.2.tar
```

### Option C: Multi-Architecture Export

```bash
# For clusters with mixed architectures (amd64 + arm64)
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg N8N_VERSION=2.3.2 \
  -f Dockerfile.secure \
  -t n8n-custom-image-secure:2.3.2 \
  --output type=oci,dest=n8n-secure-multiarch.tar .
```

## Step 2: Transfer to Air-Gapped Environment

### Security Considerations

1. **Verify checksums** before and after transfer
   ```bash
   # Source environment
   sha256sum n8n-custom-image-secure.tar.gz > checksums.txt

   # Target environment
   sha256sum -c checksums.txt
   ```

2. **Scan for malware** on transfer medium
3. **Document chain of custody** for audit trail

### Transfer Methods

| Method | Use Case |
|--------|----------|
| USB drive | Small deployments, one-time setup |
| Secure file transfer | Regular updates, automated pipelines |
| Physical media (DVD/tape) | High-security environments |
| Data diode | One-way transfer for maximum security |

## Step 3: Import Images

### Docker Environment

```bash
# Decompress if needed
gunzip n8n-custom-image-secure.tar.gz

# Load into Docker
docker load -i n8n-custom-image-secure.tar

# Verify
docker images | grep n8n-custom-image-secure
```

### Private Registry (Recommended)

```bash
# Load image
docker load -i n8n-custom-image-secure.tar

# Tag for private registry
docker tag tinod/n8n-custom-image-secure:latest \
  registry.internal.corp/n8n/n8n-custom-image-secure:latest

# Push to internal registry
docker push registry.internal.corp/n8n/n8n-custom-image-secure:latest
```

### Kubernetes with containerd

```bash
# Import directly to containerd
ctr -n k8s.io images import n8n-custom-image-secure.tar

# Or use crictl
crictl pull --creds user:pass registry.internal/n8n-custom-image-secure:latest
```

## Step 4: License Configuration

### Option A: Community Edition (No License Required)

The secure image works without a license in Community mode:

```bash
docker run -d \
  -p 5678:5678 \
  -e N8N_LICENSE_SERVICE_ENABLED=false \
  -e N8N_LICENSE_OFFLINE_MODE=true \
  n8n-custom-image-secure:latest
```

### Option B: Pre-Activated License (Recommended for Enterprise)

1. **Activate license on internet-connected machine**
   ```bash
   # Temporary online activation
   docker run -it --rm \
     -e N8N_LICENSE_ACTIVATION_KEY=your-activation-key \
     -e N8N_LICENSE_SERVICE_ENABLED=true \
     -v $(pwd)/n8n-data:/home/node/.n8n \
     n8n-custom-image-secure:latest
   ```

2. **Export license certificate**
   ```bash
   # From SQLite
   export SQLITE_PATH=./n8n-data/database.sqlite
   ./scripts/license-cert-export.sh sqlite license.cert

   # Or from PostgreSQL
   export PGHOST=localhost PGDATABASE=n8n PGUSER=n8n PGPASSWORD=secret
   ./scripts/license-cert-export.sh postgres license.cert
   ```

3. **Generate offline env file**
   ```bash
   ./scripts/license-cert-env.sh license.cert .env.license
   ```

4. **Deploy with pre-loaded certificate**
   ```bash
   docker run -d \
     -p 5678:5678 \
     --env-file .env.license \
     -e N8N_LICENSE_SERVICE_ENABLED=false \
     -e N8N_LICENSE_OFFLINE_MODE=true \
     n8n-custom-image-secure:latest
   ```

### Option C: GDPR Feature Overrides (Patched Image)

For environments using the patched secure image with GDPR overrides:

```bash
docker run -d \
  -p 5678:5678 \
  -e N8N_LICENSE_SERVICE_ENABLED=false \
  -e N8N_LICENSE_OFFLINE_MODE=true \
  -e N8N_LICENSE_FORCE_PLAN=Enterprise \
  -e N8N_LICENSE_FORCE_FEATURES=feat:sharing,feat:ldap,feat:advancedExecutionFilters \
  -e N8N_LICENSE_QUOTA_USERS_LIMIT=100 \
  -e N8N_LICENSE_QUOTA_WORKFLOW_HISTORY_PRUNE_LIMIT=1000 \
  n8n-custom-image-secure:latest
```

## Step 5: Network Isolation

### Docker Compose

Use the complete secure stack configuration:

```bash
# Copy environment example
cp docker/.env.secure.example docker/.env.secure

# Edit with your values (IMPORTANT: set encryption keys!)
nano docker/.env.secure

# Start the secure stack
docker compose -f docker/docker-compose.secure.yml --env-file docker/.env.secure up -d
```

For complete network isolation, uncomment `internal: true` in the networks section of `docker-compose.secure.yml`.

<details>
<summary>Manual configuration (click to expand)</summary>

```yaml
version: '3.8'
services:
  n8n:
    image: tinod/n8n-custom-image-secure:latest
    networks:
      - n8n-internal
    environment:
      - N8N_DISABLE_EXTERNAL_COMMUNICATIONS=true
      - N8N_LICENSE_SERVICE_ENABLED=false
      - N8N_LICENSE_OFFLINE_MODE=true
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      - N8N_TEMPLATES_ENABLED=false
    ports:
      - "5678:5678"

  postgres:
    image: postgres:16-alpine
    networks:
      - n8n-internal
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=changeme

networks:
  n8n-internal:
    driver: bridge
    internal: true  # No external connectivity
```

</details>

### iptables Rules (Docker Host)

```bash
# Block all outbound from n8n container
iptables -I DOCKER-USER -s 172.17.0.0/16 -j DROP

# Allow only internal network
iptables -I DOCKER-USER -s 172.17.0.0/16 -d 172.17.0.0/16 -j ACCEPT
iptables -I DOCKER-USER -s 172.17.0.0/16 -d 10.0.0.0/8 -j ACCEPT
```

### Kubernetes NetworkPolicy

Apply minimal egress policy:

```bash
kubectl apply -f k8s/egress/networkpolicy.yaml
```

Or for Cilium clusters:

```bash
kubectl apply -f k8s/egress/cilium-egress-policy.yaml
```

## Step 6: Verification

### Run Zero-Outbound Verification

```bash
# On the air-gapped system
./scripts/verify-zero-outbound.sh
```

Expected output:
```
Phase 1: Static Source Analysis
--------------------------------
✓ PASS: Telemetry service has external comms check
✓ PASS: PostHog service has external comms check
...

Phase 3: Dockerfile Environment Check
--------------------------------------
✓ PASS: N8N_DISABLE_EXTERNAL_COMMUNICATIONS=true in Dockerfile
✓ PASS: N8N_DIAGNOSTICS_ENABLED=false in Dockerfile
...

VERIFICATION PASSED
```

### Network Verification

```bash
# Check no outbound connections from container
docker exec n8n-container netstat -tuln

# Monitor DNS requests (should be empty or internal only)
tcpdump -i docker0 port 53

# Check container has no route to internet
docker exec n8n-container curl -s --max-time 5 https://api.n8n.io || echo "Blocked (expected)"
```

### Functional Verification

1. Access n8n UI at `http://localhost:5678`
2. Create a test workflow
3. Verify no errors related to license or external services
4. Check Settings → Telemetry shows disabled

## Step 7: Ongoing Maintenance

### Version Updates

1. **Source environment**: Pull/build new version, export tar
2. **Transfer**: Use same secure transfer process
3. **Target environment**: Load new image, update deployments
4. **Verify**: Run verification script after update

### License Renewal (If Using Enterprise License)

1. Export current certificate before expiry
2. Renew on internet-connected system
3. Export new certificate
4. Transfer and update deployment

### Backup Procedures

```bash
# Backup n8n data
docker exec n8n-container tar czf - /home/node/.n8n > n8n-backup-$(date +%Y%m%d).tar.gz

# Backup PostgreSQL
pg_dump -h localhost -U n8n n8n > n8n-db-$(date +%Y%m%d).sql
```

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "License check failed" | License service trying to phone home | Set `N8N_LICENSE_SERVICE_ENABLED=false` |
| Missing features | Community mode limitations | Use GDPR feature overrides or pre-activated license |
| Workflow templates empty | Templates require API call | Expected in air-gapped; `N8N_TEMPLATES_ENABLED=false` |
| Version notification errors | Trying to check for updates | `N8N_VERSION_NOTIFICATIONS_ENABLED=false` |

### Debug Mode

```bash
docker run -it --rm \
  -e N8N_LOG_LEVEL=debug \
  -e N8N_DISABLE_EXTERNAL_COMMUNICATIONS=true \
  n8n-custom-image-secure:latest
```

### Container Shell Access

```bash
docker exec -it n8n-container /bin/sh
# Check environment
env | grep N8N
# Check network
cat /etc/resolv.conf
```

## Security Checklist

- [ ] Images verified with checksums
- [ ] Transfer medium scanned for malware
- [ ] Chain of custody documented
- [ ] Network isolation verified (no internet egress)
- [ ] DNS queries monitored (internal only)
- [ ] License configuration reviewed
- [ ] Telemetry verified disabled
- [ ] Verification script passes
- [ ] Backup procedures tested
- [ ] Update procedures documented

## Related Documentation

- [Docker Compose Secure Stack](../docker/docker-compose.secure.yml) - Complete production config
- [Patch Coverage Analysis](PATCH-COVERAGE-ANALYSIS.md) - External endpoint coverage
- [License Toggle Guide](license/toggle.md) - License profile management
- [Zero Outbound Comms Plan](plans/2026-01-09-zero-outbound-comms.md) - Technical design
- [Egress Allowlist Profiles](egress/allowlist-profiles.md) - Network profiles
- [SECURITY-DSGVO-ANALYSIS.md](../SECURITY-DSGVO-ANALYSIS.md) - GDPR compliance analysis
