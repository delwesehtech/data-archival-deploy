#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ ! -f ".env" ]]; then
  echo "Missing .env. Copy .env.example to .env and fill values first." >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <previous-image-tag>" >&2
  echo "Example: $0 a1b2c3d4e5f6" >&2
  exit 1
fi

export IMAGE_TAG="$1"
echo "Rolling back to ${IMAGE_NAME:-<unset>}:${IMAGE_TAG} ..."
docker compose pull
docker compose up -d --force-recreate

echo "Rollback complete."
docker compose ps
