#!/usr/bin/env bash
# data-archival-deploy — local helpers for crick.
#
# Run directly (easiest):  ./aliases.sh   or   bash path/to/aliases.sh
#   → opens an interactive bash with helpers loaded (see avd_help).
#
# Or source into your current shell:
#   source path/to/aliases.sh
#
# Zsh: prefer running ./aliases.sh (bash subshell), or: source .../aliases.sh

# Absolute directory containing this script (works even if cwd is e.g. environments/crick).
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
_AVD_CRICK="${DATA_ARCHIVAL_DEPLOY}/environments/crick"

avd_help() {
  cat <<'EOF'
data-archival-deploy — crick helpers (compose in environments/crick)

  cleanup_scratch       Dry-run scratch cleanup (compose default). Writes logs under environments/crick/logs/.
  cleanup_archive       Dry-run archive cleanup (compose service: cleanup_archive).
  restart_visibility    Recreate the visibility container only (pick up new image / UI).
  rm_exited_cleanup     Remove exited containers only for environments/crick (uses docker compose ps — not other Docker projects).
  delete_log_files      Remove cleanup audit files: delete_log_files scratch | archive | all (under environments/crick/logs).

  Real deletes (run manually from environments/crick):
    docker compose run --rm cleanup_scratch --execute --log-dir /app/logs
    docker compose run --rm cleanup_archive --execute --log-dir /app/logs

  avd_help              Show this list.
EOF
}

# Dry-run uses compose command: ["--dry-run", "--log-dir", "/app/logs"]
cleanup_scratch() {
  (cd "${_AVD_CRICK}" && docker compose run --rm cleanup_scratch)
}

cleanup_archive() {
  (cd "${_AVD_CRICK}" && docker compose run --rm cleanup_archive)
}

# Remove exited containers only for this compose app (environments/crick).
# Uses `docker compose ps` so Docker itself decides project membership — never touches other projects.
rm_exited_cleanup() {
  (
    cd "${_AVD_CRICK}" || exit 1
    local count=0
    while IFS= read -r id; do
      [[ -z "${id}" ]] && continue
      docker rm "${id}"
      count=$((count + 1))
    done < <(docker compose ps -a -q --status exited 2>/dev/null)
    if [[ "${count}" -eq 0 ]]; then
      echo "No exited containers for compose project in ${_AVD_CRICK}."
    else
      echo "Removed ${count} exited container(s) for compose project in ${_AVD_CRICK}."
    fi
  )
}

# Recreate only visibility (new image / HTML); leaves other services running
restart_visibility() {
  (cd "${_AVD_CRICK}" && docker compose up -d --force-recreate visibility)
}

# Remove delete-job artifacts for scratch or archive cleanup (audit dirs + last_delete_scan_*.json).
# Does not remove archival workflow logs (e.g. audit/archival_*.jsonl, last_scan.json).
delete_log_files() {
  local role="${1:-}"
  local base="${_AVD_CRICK}/logs"
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
