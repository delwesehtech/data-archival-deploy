#!/usr/bin/env bash
# data-archival-deploy — local helpers (uses repo root .env next to docker-compose.yml).
#
# Run directly (easiest):  ./aliases.sh   or   bash path/to/aliases.sh
#   → opens an interactive bash with helpers loaded (see avd_help).
#
# Or source into your current shell:
#   source path/to/aliases.sh
#
# Zsh: prefer running ./aliases.sh (bash subshell), or: source .../aliases.sh

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

# Invoked as ./aliases.sh (not sourced): spawn a shell that sources this file.
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
  echo "aliases.sh: set DATA_ARCHIVAL_DEPLOY to the data-archival-deploy repo root, or source from bash." >&2
  return 1 2>/dev/null || exit 1
fi
# Single env file at repo root (gitignored); SERVER_DEPLOY_DIR selects servers/<name>/.
_avd_env_file="${DATA_ARCHIVAL_DEPLOY}/.env"

_avd_ensure_env() {
  if [[ ! -f "${_avd_env_file}" ]]; then
    echo "aliases.sh: missing ${_avd_env_file}. Copy .env.example to .env and set SERVER_DEPLOY_DIR." >&2
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

# Resolve servers/<name> from SERVER_DEPLOY_DIR= in .env (repo-relative or absolute).
_avd_server_deploy_dir() {
  _avd_ensure_env || return 1
  local line val
  line="$(grep -E '^[[:space:]]*SERVER_DEPLOY_DIR=' "${_avd_env_file}" | tail -1)" || return 1
  if [[ "${line}" =~ ^[[:space:]]*SERVER_DEPLOY_DIR=(.*)$ ]]; then
    val="${BASH_REMATCH[1]}"
  else
    echo "aliases.sh: could not parse SERVER_DEPLOY_DIR in ${_avd_env_file}" >&2
    return 1
  fi
  val="${val%%$'\r'}"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  if [[ "${val}" == \"*\" ]]; then
    val="${val:1:${#val}-2}"
  fi
  if [[ -z "${val}" ]]; then
    echo "aliases.sh: SERVER_DEPLOY_DIR is empty in ${_avd_env_file}" >&2
    return 1
  fi
  if [[ "${val}" == /* ]]; then
    echo "${val}"
  else
    echo "${DATA_ARCHIVAL_DEPLOY}/${val}"
  fi
}

avd_help() {
  cat <<'EOF'
data-archival-deploy — helpers (repo root .env + docker-compose.yml)

  On Apple Silicon, if .env does not set COMPOSE_DOCKER_PLATFORM, helpers default it to linux/arm64 (native local builds). Linux servers: omit it (linux/amd64). Override in .env anytime.

  cleanup_scratch       Dry-run scratch cleanup (compose default). Logs under $SERVER_DEPLOY_DIR/logs/.
  cleanup_archive       Dry-run archive cleanup (compose service: cleanup_archive).
  restart_visibility    Recreate the visibility container only (pick up new image / UI).
  rm_exited_cleanup     Remove exited containers only for this compose project (uses docker compose ps).
  delete_log_files      Remove cleanup audit files: delete_log_files scratch | archive | all (under active server logs/).

  Real deletes (from repo root; same .env as helpers):
    docker compose --env-file .env -f docker-compose.yml run --rm cleanup_scratch --execute --log-dir /app/logs
    docker compose --env-file .env -f docker-compose.yml run --rm cleanup_archive --execute --log-dir /app/logs

  avd_help              Show this list.
EOF
}

# Dry-run uses compose command: ["--dry-run", "--log-dir", "/app/logs"]
cleanup_scratch() {
  _avd_docker_compose run --rm cleanup_scratch
}

cleanup_archive() {
  _avd_docker_compose run --rm cleanup_archive
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

# Remove delete-job artifacts for scratch or archive cleanup (audit dirs + last_delete_scan_*.json).
# Does not remove archival workflow logs (e.g. audit/archival_*.jsonl, last_scan.json).
delete_log_files() {
  local role="${1:-}"
  local deploy_root base
  deploy_root="$(_avd_server_deploy_dir)" || return 1
  base="${deploy_root}/logs"
  case "${role}" in
    scratch)
      rm -rf "${base}/audit/cleanup_scratch"
      rm -f "${base}/last_delete_scan_cleanup_scratch.json"
      echo "Removed scratch cleanup logs under ${base}."
      ;;
    archive)
      rm -rf "${base}/audit/cleanup_archive"
      rm -f "${base}/last_delete_scan_cleanup_archive.json"
      echo "Removed archive cleanup logs under ${base}."
      ;;
    all)
      rm -rf "${base}/audit/cleanup_scratch" "${base}/audit/cleanup_archive"
      rm -f "${base}/last_delete_scan_cleanup_scratch.json" "${base}/last_delete_scan_cleanup_archive.json"
      echo "Removed scratch and archive cleanup logs under ${base}."
      ;;
    *)
      echo "Usage: delete_log_files scratch|archive|all" >&2
      return 1
      ;;
  esac
}
