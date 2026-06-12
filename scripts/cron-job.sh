#!/bin/bash

###############################################################################
# cleanup.sh
###############################################################################

usage() {
cat << EOF
Usage:
  $(basename "$0") --job JOB_NAME --mount PATH [OPTIONS]

Description:
  Runs a Docker Compose cleanup job only when disk usage exceeds threshold.

Required:
  --job JOB_NAME
  --mount PATH

Optional:
  --threshold PERCENT   Default: 90
  -h, --help
EOF
}

###############################################################################
# Paths
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

###############################################################################
# Defaults
###############################################################################

THRESHOLD=90
CLEANUP_JOB=""
MOUNT_POINT=""
LOG_FILE=""

###############################################################################
# Parse arguments
###############################################################################

while [[ $# -gt 0 ]]; do
    case "$1" in
        --job)
            CLEANUP_JOB="$2"
            shift 2
            ;;
        --mount)
            MOUNT_POINT="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option $1"
            usage
            exit 1
            ;;
    esac
done

###############################################################################
# Validate inputs
###############################################################################

if [ -z "$CLEANUP_JOB" ]; then
    echo "ERROR: --job is required"
    usage
    exit 1
fi

if [ -z "$MOUNT_POINT" ]; then
    echo "ERROR: --mount is required"
    usage
    exit 1
fi

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
    echo "ERROR: threshold must be integer"
    exit 1
fi

###############################################################################
# Log file derived from job name
###############################################################################

LOG_FILE="$SCRIPT_DIR/${CLEANUP_JOB}.log"

mkdir -p "$(dirname "$LOG_FILE")"

###############################################################################
# Disk usage
###############################################################################

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

USAGE=$(df -P "$MOUNT_POINT" 2>/dev/null | \
        awk 'NR==2 {gsub("%","",$5); print $5}')

if [ -z "$USAGE" ]; then
    echo "[$TIMESTAMP] ERROR: cannot read disk usage for $MOUNT_POINT" >> "$LOG_FILE"
    exit 1
fi

echo "[$TIMESTAMP] job=$CLEANUP_JOB repo=$REPO_ROOT mount=$MOUNT_POINT usage=${USAGE}% threshold=${THRESHOLD}%" \
    >> "$LOG_FILE"

###############################################################################
# Run job
###############################################################################

if [ "$USAGE" -ge "$THRESHOLD" ]; then

    echo "[$TIMESTAMP] threshold met, running $CLEANUP_JOB" >> "$LOG_FILE"

    (
        cd "$REPO_ROOT" || exit 1

        docker compose \
            --env-file .env \
            -f docker-compose.yml \
            run --rm "$CLEANUP_JOB"
    ) >> "$LOG_FILE" 2>&1

    EXIT_CODE=$?

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] job=$CLEANUP_JOB finished exit_code=$EXIT_CODE" \
        >> "$LOG_FILE"

else
    echo "[$TIMESTAMP] below threshold, skipping" >> "$LOG_FILE"
fi

echo "------------------------------------------------------------" >> "$LOG_FILE"