#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ ! -f ".env" ]]; then
  echo "Missing .env. Copy .env.example to .env and fill values first." >&2
  exit 1
fi

echo "Pulling ${IMAGE_NAME:-<unset>}:${IMAGE_TAG:-<unset>} and recreating services..."
docker compose pull
docker compose up -d --force-recreate

echo "Deployment complete."
docker compose ps
