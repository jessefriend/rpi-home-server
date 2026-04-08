#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

: "${RESTIC_REPO:?RESTIC_REPO is required. Copy backup/.env.example to backup/.env and set it.}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD is required. Copy backup/.env.example to backup/.env and set it.}"

TARGET="${1:-}"
SNAPSHOT="${2:-latest}"

if [[ -z "${TARGET}" ]]; then
  echo "Usage: ./backup/restore-latest.sh /path/to/restore-target [snapshot-id|latest]" >&2
  exit 1
fi

echo "== Latest snapshots =="
restic -r "${RESTIC_REPO}" snapshots

echo
echo "Repository: ${RESTIC_REPO}"
echo "Snapshot:   ${SNAPSHOT}"
echo "Target:     ${TARGET}"
echo

if [[ "${TARGET}" == "/" ]]; then
  echo "WARNING: restoring to / will write directly into the live filesystem."
  read -r -p "Type YES to continue: " CONFIRM
  [[ "${CONFIRM}" == "YES" ]] || exit 1
else
  mkdir -p "${TARGET}"
  read -r -p "Restore to ${TARGET}? [y/N]: " CONFIRM
  [[ "${CONFIRM}" =~ ^[Yy]$ ]] || exit 1
fi

restic -r "${RESTIC_REPO}" restore "${SNAPSHOT}" --target "${TARGET}"

echo
echo "Restore completed to ${TARGET}"
echo "Next:"
echo "  - verify restored files"
echo "  - check .env"
echo "  - run: docker compose up -d --build"
