# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Custom n8n Docker image that extends the official `n8nio/n8n` base image with additional dependencies for automation workflows. Published to Docker Hub as `tinod/n8n-custom-image`.

## Build Commands

```bash
# Build locally with specific n8n version
docker build --build-arg N8N_VERSION=1.70.0 -t n8n-custom-image:local .

# Build for multi-architecture (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 --build-arg N8N_VERSION=1.70.0 -t n8n-custom-image:local .

# Test the built image
docker run -it --rm -p 5678:5678 n8n-custom-image:local
```

## CI/CD Architecture

Three GitHub Actions workflows handle automated releases:

1. **check-n8n-new-release.yml** - Daily cron (8am UTC) checks for new upstream n8n releases and triggers builds
2. **create-new-release-on-push.yml** - Triggers builds when Dockerfile or workflow files change on main
3. **build-and-push.yml** - Reusable workflow that builds multi-arch images (amd64/arm64), pushes to Docker Hub, creates GitHub release, and notifies Slack

Version suffixes (e.g., `1.70.0-1`, `1.70.0-2`) are automatically appended when rebuilding the same n8n version with Dockerfile changes.

## Dockerfile Structure

The image extends `n8nio/n8n:${N8N_VERSION}` and adds:

- **Browser automation**: Chromium, Puppeteer environment vars
- **Media processing**: ffmpeg, yt-dlp
- **Document processing**: pandoc, tectonic (LaTeX)
- **Python environment**: python3 with venv at `/home/node/venv`
- **Node.js tools**: cryptr

Key environment variables set in the image:
- `PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true`
- `PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser`
- `PYTHONUNBUFFERED=1`

## Manual Release Trigger

To manually build a specific version, run the "Build and push" workflow from GitHub Actions UI with the desired n8n version (must match a [released n8n version](https://github.com/n8n-io/n8n/releases)).

## Required Secrets

- `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` - Docker Hub credentials
- `RELEASE_NOTIFICATION__SLACK_WEBHOOK_URL` - Slack notification webhook
