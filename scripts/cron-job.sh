#!/bin/bash

###############################################################################
# cleanup.sh
###############################################################################

usage() {
cat << EOF
Usage:
  $(basename "$0") --job JOB_NAME --check-drive PATH [OPTIONS]

Description:
  Runs a Docker Compose cleanup job only when disk usage of the specified
  filesystem path exceeds the configured threshold.

Required:
  --job JOB_NAME
      Docker Compose service/job to execute.

  --check-drive PATH
      Filesystem path used ONLY to check disk usage.

Optional:
  --threshold PERCENT
      Disk usage percentage that triggers cleanup.
      Default: 90

  -h, --help
      Show this help message.

Examples:

  $(basename "$0") --job cleanup_archive --check-drive /data

  $(basename "$0") --job cleanup_logs --check-drive /mnt/archive --threshold 95

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
CHECK_DRIVE=""
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
        --check-drive)
            CHECK_DRIVE="$2"
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

if [ -z "$CHECK_DRIVE" ]; then
    echo "ERROR: --check-drive is required"
    usage
    exit 1
fi

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
    echo "ERROR: threshold must be integer"
    exit 1
fi

###############################################################################
# Log file per job
###############################################################################

LOG_FILE="$SCRIPT_DIR/${CLEANUP_JOB}.log"
mkdir -p "$(dirname "$LOG_FILE")"

###############################################################################
# Disk usage check
###############################################################################

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

USAGE=$(df -P "$CHECK_DRIVE" 2>/dev/null | \
        awk 'NR==2 {gsub("%","",$5); print $5}')

if [ -z "$USAGE" ]; then
    echo "[$TIMESTAMP] ERROR: cannot read disk usage for $CHECK_DRIVE" >> "$LOG_FILE"
    exit 1
fi

echo "[$TIMESTAMP] job=$CLEANUP_JOB repo=$REPO_ROOT drive=$CHECK_DRIVE usage=${USAGE}% threshold=${THRESHOLD}%" \
    >> "$LOG_FILE"

###############################################################################
# Execute job
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

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] job=$CLEANUP_JOB exit_code=$EXIT_CODE" \
        >> "$LOG_FILE"

else
    echo "[$TIMESTAMP] below threshold, skipping execution" >> "$LOG_FILE"
fi

echo "------------------------------------------------------------" >> "$LOG_FILE"