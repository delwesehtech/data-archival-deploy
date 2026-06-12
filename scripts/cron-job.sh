#!/bin/bash

###############################################################################
# cleanup.sh
#
# Runs a Docker Compose cleanup job only when a filesystem exceeds a specified
# utilization threshold.
#
# Assumption:
#   This script lives inside a repo folder (e.g. repo/scripts/cleanup.sh)
#   and docker-compose.yml is located one directory above it (repo root).
###############################################################################

usage() {
cat << EOF
Usage:
  $(basename "$0") --job JOB_NAME --mount PATH [OPTIONS]

Description:
  Checks disk utilization for a mount point and runs the specified Docker
  Compose cleanup job only when utilization meets or exceeds the threshold.

Required:
  --job JOB_NAME
      Docker Compose service/job to execute.

  --mount PATH
      Mount point to monitor.

Optional:
  --threshold PERCENT
      Disk utilization percentage that triggers cleanup.
      Default: 90

  --log-file FILE
      Log file location.
      Default: <script directory>/archive-cleanup.log

  -h, --help
      Display this help message.

Examples:

  $(basename "$0") --job cleanup_archive --mount /data

  $(basename "$0") --job cleanup_logs --mount /data --threshold 95

  $(basename "$0") --job cleanup_archive --mount /mnt/archive

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
LOG_FILE="$SCRIPT_DIR/archive-cleanup.log"

CLEANUP_JOB=""
MOUNT_POINT=""

###############################################################################
# Parse Arguments
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
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$1'"
            echo
            usage
            exit 1
            ;;
    esac
done

###############################################################################
# Validate Inputs
###############################################################################

if [ -z "$CLEANUP_JOB" ]; then
    echo "ERROR: --job is required"
    echo
    usage
    exit 1
fi

if [ -z "$MOUNT_POINT" ]; then
    echo "ERROR: --mount is required"
    echo
    usage
    exit 1
fi

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Threshold must be an integer."
    exit 1
fi

if [ ! -d "$MOUNT_POINT" ]; then
    echo "ERROR: Mount point '$MOUNT_POINT' does not exist."
    exit 1
fi

###############################################################################
# Ensure log directory exists
###############################################################################

mkdir -p "$(dirname "$LOG_FILE")"

###############################################################################
# Get Disk Usage
###############################################################################

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

USAGE=$(df -P "$MOUNT_POINT" 2>/dev/null | \
        awk 'NR==2 {gsub("%","",$5); print $5}')

if [ -z "$USAGE" ]; then
    echo "[$TIMESTAMP] ERROR: Unable to determine disk usage for $MOUNT_POINT" \
        >> "$LOG_FILE"
    exit 1
fi

###############################################################################
# Log Status
###############################################################################

echo "[$TIMESTAMP] Job=$CLEANUP_JOB Repo=$REPO_ROOT Mount=$MOUNT_POINT Usage=${USAGE}% Threshold=${THRESHOLD}%" \
    >> "$LOG_FILE"

###############################################################################
# Run Cleanup If Threshold Met
###############################################################################

if [ "$USAGE" -ge "$THRESHOLD" ]; then

    echo "[$TIMESTAMP] Threshold met. Starting cleanup job '$CLEANUP_JOB'." \
        >> "$LOG_FILE"

    (
        cd "$REPO_ROOT" || exit 1

        docker compose \
            --env-file .env \
            -f docker-compose.yml \
            run --rm "$CLEANUP_JOB"
    ) >> "$LOG_FILE" 2>&1

    EXIT_CODE=$?

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleanup job '$CLEANUP_JOB' completed with exit code $EXIT_CODE." \
        >> "$LOG_FILE"

else

    echo "[$TIMESTAMP] Usage ${USAGE}% is below threshold ${THRESHOLD}%. Cleanup skipped." \
        >> "$LOG_FILE"

fi

echo "-------------------------------------------------------------------" >> "$LOG_FILE"

exit 0