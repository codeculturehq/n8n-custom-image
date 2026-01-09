# License Service Toggle

Goal: disable outbound license traffic by default, while allowing controlled, temporary tests.

## Profiles
Profiles live in `config/license/profiles.json`.

- `offline_default` (safe default)
- `online_test` (temporary activation/renewal test)
- `internal_proxy` (route via internal proxy)

## Apply a profile
Generate an env file:

```bash
./scripts/license-profile.sh offline_default
# writes .env.license
```

## Export license cert (one-time)

Postgres:

```bash
export PGHOST=... PGDATABASE=... PGUSER=... PGPASSWORD=...
./scripts/license-cert-export.sh postgres license.cert
```

SQLite:

```bash
export SQLITE_PATH=/path/to/database.sqlite
./scripts/license-cert-export.sh sqlite license.cert
```

Create offline env file from cert:

```bash
./scripts/license-cert-env.sh license.cert .env.license
```

Use it with Docker:

```bash
docker run --env-file .env.license -e N8N_LICENSE_ACTIVATION_KEY=... \
  tinod/n8n-custom-image:latest
```

Kubernetes example:

```yaml
env:
  - name: N8N_LICENSE_SERVICE_ENABLED
    value: "true"
  - name: N8N_LICENSE_OFFLINE_MODE
    value: "false"
  - name: N8N_LICENSE_AUTO_RENEW_ENABLED
    value: "false"
```

## Notes
- For privacy, keep `N8N_LICENSE_SERVICE_ENABLED=false` in production unless explicitly approved.
- For tests, enable only for the window needed, then revert to `offline_default`.
- If using an internal proxy, set `N8N_LICENSE_SERVER_URL_OVERRIDE` and ensure egress allowlist covers it.
