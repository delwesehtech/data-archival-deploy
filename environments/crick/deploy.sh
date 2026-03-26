#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ ! -f ".env" ]]; then
  echo "Missing .env. Copy .env.example to .env and fill values first." >&2
  exit 1
fi

# Set PULL_IMAGE=1 after docker login when IMAGE_NAME is a registry path (e.g. ghcr.io/org/data-archival).
# Omit pull for locally tagged images (data-archival:latest) or compose will error on Docker Hub.
if [[ "${PULL_IMAGE:-0}" == "1" ]]; then
  echo "Pulling ${IMAGE_NAME:-<unset>}:${IMAGE_TAG:-<unset>} ..."
  docker compose pull
fi
echo "Starting services (${IMAGE_NAME:-<unset>}:${IMAGE_TAG:-<unset>})..."
docker compose up -d --force-recreate

echo "Deployment complete."
docker compose ps
