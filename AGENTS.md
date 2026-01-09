# Repository Guidelines

## Project Structure & Module Organization
- `Dockerfile` defines the custom n8n image build (base image + tooling).
- `.github/workflows/` contains CI automation for release checks and image publishing.
- Documentation lives in `README.md`, `CLAUDE.md`, and `MIGRATION-V2.md`.
- No application source tree or test suite; changes are primarily Dockerfile and CI workflow updates.

## Build, Test, and Development Commands
- Local build with a pinned n8n version:
  `docker build --build-arg N8N_VERSION=1.70.0 -t n8n-custom-image:local .`
- Multi-arch build (requires buildx):
  `docker buildx build --platform linux/amd64,linux/arm64 --build-arg N8N_VERSION=1.70.0 -t n8n-custom-image:local .`
- Quick smoke test by running the image:
  `docker run -it --rm -p 5678:5678 n8n-custom-image:local`
- Releases are automated via GitHub Actions; manual builds use the “Build and push” workflow with a released n8n version.

## Coding Style & Naming Conventions
- Dockerfile: keep `ARG`/`ENV` near the top, group `apk add` packages logically, and prefer explicit comments for optional steps.
- GitHub Actions YAML: 2-space indentation, kebab-case workflow filenames (already in use).
- Image versioning follows upstream n8n versions; rebuilds of the same version append suffixes (e.g., `1.70.0-1`).

## Testing Guidelines
- No automated tests in this repo.
- Validate changes by building and running the image locally.
- For CI-level confidence, ensure the GitHub Actions workflows succeed after updates.

## Commit & Pull Request Guidelines
- Existing history uses short, imperative commit messages without prefixes (e.g., “Update Dockerfile”, “Fix …”).
- When bumping n8n versions, mention the version in the commit or PR description.
- PRs should include: summary of Dockerfile/CI changes, referenced n8n release link if applicable, and any new dependencies added.

## Security & Configuration Tips
- Required secrets are stored in GitHub Actions: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, and `RELEASE_NOTIFICATION__SLACK_WEBHOOK_URL`.
- Do not commit credentials or tokens; rely on Actions secrets for publishing.
