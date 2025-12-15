# n8n v2.0 Migration Guide

This document covers the breaking changes and migration steps for upgrading from n8n v1.x to v2.0.

## Overview

n8n v2.0 was released on December 10, 2024. This is a major version with significant security hardening and architectural changes.

**Support Timeline:**
- v1.x will receive security patches for **3 months** after v2.0 release (until ~March 2025)
- After that period, only v2.x will be supported

## Breaking Changes

### 1. ExecuteCommand Node Disabled by Default

**Impact: HIGH** - This affects our PDF/LaTeX builder workflow.

The `ExecuteCommand` and `LocalFileTrigger` nodes are now disabled by default for security reasons.

**To re-enable:**
```bash
# Set environment variable
NODES_EXCLUDE=[]

# Or in docker-compose.yml
environment:
  - NODES_EXCLUDE=[]
```

**Why this matters for us:** Our Eisvogel/Pandoc LaTeX workflow uses ExecuteCommand to run `pandoc` with `--pdf-engine=tectonic`.

### 2. Environment Variable Access Blocked in Code Nodes

Code nodes can no longer access environment variables by default.

**To re-enable:**
```bash
N8N_BLOCK_ENV_ACCESS_IN_NODE=false
```

### 3. Task Runners Enabled by Default

Task runners are now enabled by default for improved performance and isolation. The task runner is no longer included in the main Docker image.

**For self-hosted deployments:**
- Task runner runs as a separate process/container
- Configure via `N8N_RUNNERS_*` environment variables
- Can be disabled if not needed: `N8N_RUNNERS_DISABLED=true`

### 4. MySQL/MariaDB Support Removed

MySQL and MariaDB are no longer supported as database backends.

**Supported databases:**
- PostgreSQL (recommended)
- SQLite

**If migrating from MySQL/MariaDB:**
1. Export data using n8n's export functionality
2. Set up PostgreSQL database
3. Import data into new n8n instance

### 5. Removed Legacy Environment Variables

The following environment variables have been removed:
- `N8N_PERSONALIZATION_ENABLED` - now always enabled
- Various deprecated workflow settings

## Migration Checklist

### Before Upgrading

- [ ] **Backup your database** - Critical!
- [ ] **Backup your `.n8n` folder** (contains credentials and workflows)
- [ ] **Check Migration Report** in Settings → General (available in recent v1.x versions)
- [ ] **Review workflows using ExecuteCommand** - will need NODES_EXCLUDE=[]
- [ ] **Review Code nodes accessing env vars** - will need N8N_BLOCK_ENV_ACCESS_IN_NODE=false
- [ ] **Check database type** - MySQL/MariaDB users must migrate to PostgreSQL first

### Our Custom Image Configuration

For our custom n8n image with PDF/LaTeX support, add these environment variables:

```yaml
# docker-compose.yml example
services:
  n8n:
    image: tinod/n8n-custom-image:v2
    environment:
      # Re-enable ExecuteCommand for PDF generation
      - NODES_EXCLUDE=[]
      # Allow env access in Code nodes (if needed)
      - N8N_BLOCK_ENV_ACCESS_IN_NODE=false
      # Database
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=your_password
```

### After Upgrading

- [ ] Verify all workflows execute correctly
- [ ] Test PDF generation workflow specifically
- [ ] Check credential connections
- [ ] Monitor logs for deprecation warnings

## Docker Image Tags

Our custom image follows this tagging strategy:

| Tag | Description |
|-----|-------------|
| `tinod/n8n-custom-image:latest` | Latest v2.x release |
| `tinod/n8n-custom-image:v2` | Latest v2.x release |
| `tinod/n8n-custom-image:v1` | Latest v1.x release |
| `tinod/n8n-custom-image:2.0.2` | Specific version |
| `tinod/n8n-custom-image:1.70.0` | Specific version |

**Recommendation:** Pin to major version (`v1` or `v2`) for stability while receiving patches.

## Rollback Plan

If issues occur after upgrading:

1. **Stop n8n v2 container**
2. **Restore database backup**
3. **Switch to v1 image:**
   ```yaml
   image: tinod/n8n-custom-image:v1
   ```
4. **Start container and verify**

## New Features in v2.0

While primarily a security-focused release, v2.0 includes:

- **Improved task runners** - Better performance for code execution
- **Enhanced security model** - Stricter defaults for production
- **Cleaner codebase** - Removed deprecated features

## Resources

- [Official n8n v2.0 Release Notes](https://github.com/n8n-io/n8n/releases/tag/n8n%402.0.0)
- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community Forum](https://community.n8n.io/)

## Our Specific Considerations

### PDF/LaTeX Workflow

Our Eisvogel-based PDF generator workflow uses:
- `pandoc` with `--pdf-engine=tectonic`
- ExecuteCommand node for running pandoc
- Possibly environment variables in Code nodes

**Required v2 configuration:**
```bash
NODES_EXCLUDE=[]
```

### Custom Packages in Image

Our custom image includes:
- Chromium (for Puppeteer)
- Python 3 with pip and venv
- Pandoc
- Tectonic (LaTeX engine)
- yt-dlp
- ffmpeg
- git

All these tools remain available in v2 - only the n8n node permissions change.
