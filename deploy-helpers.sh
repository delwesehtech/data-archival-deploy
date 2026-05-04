#!/usr/bin/env bash
# data-archival-deploy — CLI helpers (repo root .env + docker-compose.yml).
#
# Run directly (easiest):  ./deploy-helpers.sh   or   bash path/to/deploy-helpers.sh
#   → opens an interactive bash with helpers loaded (see avd_help).
#
# Or source into your current shell:
#   source path/to/deploy-helpers.sh
#
# Zsh: prefer running ./deploy-helpers.sh (bash subshell), or: source .../deploy-helpers.sh

# Absolute directory containing this script (works even if cwd is e.g. servers/crick).
_avd_script_dir() {
  local f="${1}"
  local d
  d="$(dirname "${f}")"
  if [[ "${d}" != /* ]]; then
    d="$(pwd)/${d}"
  fi
  (cd "${d}" && pwd)
}

_avd_this="${BASH_SOURCE[0]}"

# Invoked as ./deploy-helpers.sh (not sourced): spawn a shell that sources this file.
if [[ -n "${_avd_this}" && "${_avd_this}" == "$0" ]]; then
  DATA_ARCHIVAL_DEPLOY="$(_avd_script_dir "${_avd_this}")"
  export DATA_ARCHIVAL_DEPLOY
  _SELF_ABS="${DATA_ARCHIVAL_DEPLOY}/$(basename "${_avd_this}")"
  _q=$(printf '%q' "${_SELF_ABS}")
  exec bash --rcfile <(
    { [[ -f "${HOME}/.bashrc" ]] && cat "${HOME}/.bashrc"; } || true
    echo "source ${_q}"
    echo 'echo "[data-archival-deploy] Type avd_help for commands. exit to leave this shell."'
  ) -i
fi

if [[ -z "${DATA_ARCHIVAL_DEPLOY:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    DATA_ARCHIVAL_DEPLOY="$(_avd_script_dir "${BASH_SOURCE[0]}")"
  elif [[ -n "${ZSH_VERSION:-}" && -n "${(%):-%x}" ]]; then
    DATA_ARCHIVAL_DEPLOY="$(cd "$(dirname "${(%):-%x}")" && pwd)"
  fi
fi
if [[ -z "${DATA_ARCHIVAL_DEPLOY:-}" ]]; then
  echo "deploy-helpers.sh: set DATA_ARCHIVAL_DEPLOY to the data-archival-deploy repo root, or source from bash." >&2
  return 1 2>/dev/null || exit 1
fi
# Single env file at repo root (gitignored); SERVER_DEPLOY_DIR selects servers/<name>/.
_avd_env_file="${DATA_ARCHIVAL_DEPLOY}/.env"

_avd_ensure_env() {
  if [[ ! -f "${_avd_env_file}" ]]; then
    echo "deploy-helpers.sh: missing ${_avd_env_file}. Copy .env.example to .env and set SERVER_DEPLOY_DIR." >&2
    return 1
  fi
}

# True if .env sets COMPOSE_DOCKER_PLATFORM (servers usually omit it → compose default linux/amd64).
_avd_env_has_compose_docker_platform() {
  [[ -f "${_avd_env_file}" ]] || return 1
  grep -qE '^[[:space:]]*COMPOSE_DOCKER_PLATFORM=' "${_avd_env_file}" 2>/dev/null
}

# Apple Silicon + no explicit platform: use linux/arm64 for native local images. Override via .env or shell.
_avd_apply_default_compose_platform() {
  if [[ -n "${COMPOSE_DOCKER_PLATFORM:-}" ]]; then
    return 0
  fi
  if _avd_env_has_compose_docker_platform; then
    return 0
  fi
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) export COMPOSE_DOCKER_PLATFORM=linux/arm64 ;;
  esac
}

_avd_docker_compose() {
  _avd_ensure_env || return 1
  (
    cd "${DATA_ARCHIVAL_DEPLOY}" || exit 1
    _avd_apply_default_compose_platform
    docker compose --env-file "${_avd_env_file}" -f docker-compose.yml "$@"
  )
}

avd_help() {
  cat <<'EOF'
data-archival-deploy — compose helpers (uses repo root .env + docker-compose.yml)

Apple Silicon: if .env has no COMPOSE_DOCKER_PLATFORM, helpers default to linux/arm64. Linux servers: omit it (linux/amd64).

================================================================================
  Runnable shell commands — type the name at this prompt, then Enter:
================================================================================

  cleanup_scratch
      Dry-run scratch cleanup (compose default). Logs under SERVER_DEPLOY_DIR/logs/.

  cleanup_archive
      Dry-run archive-drive cleanup.

  archival
      Dry-run archival (archive → S3 Glacier per archive_policy.yaml).

  download_restored_objects
      After visibility “Mark for restore”: HeadObject poll + download under ARCHIVE_PATH/.restores/.
      With no args uses --max-wait-seconds 600 --poll-interval 5; or pass your own flags.

  restart_visibility
      Recreate the visibility container (new image / UI).

  rm_exited_cleanup
      Remove exited containers for this compose project only.

  avd_help
      Show this list.

================================================================================
  Full docker compose — copy/paste from repo root (same .env as above):
================================================================================

  Cleanup

  $ docker compose --env-file .env -f docker-compose.yml run --rm cleanup_scratch --execute --log-dir /app/logs
  $ docker compose --env-file .env -f docker-compose.yml run --rm cleanup_archive --execute --log-dir /app/logs

  Archive and restore

  $ docker compose --env-file .env -f docker-compose.yml run --rm archival --execute --log-dir /app/logs
  $ docker compose --env-file .env -f docker-compose.yml run --rm restore --log-dir /app/logs --max-wait-seconds 600 --poll-interval 5
      # after visibility “Mark for restore”; same as download_restored_objects with no args (append flags for custom wait/poll)

Restore: visibility initiates Glacier restore in AWS; run download_restored_objects on a schedule or ad hoc.
EOF
}

# Dry-run uses compose command: ["--dry-run", "--log-dir", "/app/logs"]
cleanup_scratch() {
  _avd_docker_compose run --rm cleanup_scratch
}

cleanup_archive() {
  _avd_docker_compose run --rm cleanup_archive
}

# Dry-run archival (compose default: --dry-run --log-dir /app/logs). Uses ARCHIVE_POLICY_PATH from compose.
archival() {
  _avd_docker_compose run --rm archival
}

# Download restored objects (engine.restore finalize): poll S3 until readable, download under ARCHIVE_PATH/.restores/.
download_restored_objects() {
  if [[ $# -eq 0 ]]; then
    _avd_docker_compose run --rm restore --log-dir /app/logs --max-wait-seconds 600 --poll-interval 5
  else
    _avd_docker_compose run --rm restore --log-dir /app/logs "$@"
  fi
}

# Remove exited containers only for this compose app (servers/crick).
# Uses `docker compose ps` so Docker itself decides project membership — never touches other projects.
rm_exited_cleanup() {
  _avd_ensure_env || return 1
  (
    cd "${DATA_ARCHIVAL_DEPLOY}" || exit 1
    _avd_apply_default_compose_platform
    local count=0
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      docker rm "${id}"
      count=$((count + 1))
    done < <(docker compose --env-file "${_avd_env_file}" -f docker-compose.yml ps -a -q --status exited 2>/dev/null)
    if [[ "${count}" -eq 0 ]]; then
      echo "No exited containers for compose project (see COMPOSE_PROJECT_NAME in repo root .env)."
    else
      echo "Removed ${count} exited container(s) for this compose project."
    fi
  )
}

# Recreate only visibility (new image / HTML); leaves other services running
restart_visibility() {
  _avd_docker_compose up -d --force-recreate visibility
}
