#!/usr/bin/env bash
# data-archival-deploy — bump VERSION, tag, and push (main only).
#
# - Must be on branch main (no tags from dev/feature branches).
# - Reads repo-root VERSION (e.g. v1.05), computes next (v1.06).
# - Pushes main to GIT_REMOTE (default: origin), then creates annotated tag ${next},
#   pushes the tag (via push-main-and-tag.sh), and writes VERSION to ${next} locally (commit that file yourself).
#
# Usage: from repo root, ./scripts/tag-and-push.sh
# Env: GIT_REMOTE (default origin), VERSION_FILE (default: ./VERSION)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GIT_REMOTE="${GIT_REMOTE:-origin}"
VERSION_FILE="${VERSION_FILE:-${REPO_ROOT}/VERSION}"

if ! command -v git >/dev/null 2>&1; then
  echo "tag-and-push.sh: git is required." >&2
  exit 1
fi

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "tag-and-push.sh: missing VERSION at ${VERSION_FILE}" >&2
  echo "Create it with a line like: v1.00" >&2
  exit 1
fi

current="$(tr -d ' \t\r\n' < "${VERSION_FILE}")"
if [[ ! "${current}" =~ ^v([0-9]+)\.([0-9]+)$ ]]; then
  echo "tag-and-push.sh: VERSION must look like v<major>.<minor>, e.g. v1.05 (got: ${current})" >&2
  exit 1
fi

major="${BASH_REMATCH[1]}"
minor_str="${BASH_REMATCH[2]}"
minor_width="${#minor_str}"
minor_num="$((10#${minor_str}))"
next_minor_num="$((minor_num + 1))"
next_minor_str="$(printf "%0${minor_width}d" "${next_minor_num}")"
next="v${major}.${next_minor_str}"

cd "${REPO_ROOT}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "tag-and-push.sh: not a git work tree at ${REPO_ROOT}." >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "${branch}" != "main" ]]; then
  echo "tag-and-push.sh: must be on branch main (current: ${branch:-unknown})." >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/${next}" >/dev/null 2>&1; then
  echo "tag-and-push.sh: git tag ${next} already exists locally." >&2
  exit 1
fi
if git ls-remote --tags "${GIT_REMOTE}" "refs/tags/${next}" 2>/dev/null | grep -q .; then
  echo "tag-and-push.sh: git tag ${next} already exists on ${GIT_REMOTE}." >&2
  exit 1
fi

echo "Current VERSION file: ${current}"
echo "New tag:              ${next}"
"${SCRIPT_DIR}/push-main-and-tag.sh" "${next}"

printf "%s\n" "${next}" > "${VERSION_FILE}"
echo "Updated ${VERSION_FILE} -> ${next}"
echo "Done: pushed main + tag ${next} to ${GIT_REMOTE}. Commit VERSION if you track it in git."
