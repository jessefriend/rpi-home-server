#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

: "${RESTIC_REPO:?RESTIC_REPO is required. Copy backup/.env.example to backup/.env and set it.}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD is required. Copy backup/.env.example to backup/.env and set it.}"

if [[ ! -d "$(dirname "$RESTIC_REPO")" ]]; then
  echo "Parent path for repo does not exist: $(dirname "$RESTIC_REPO")" >&2
  exit 1
fi

if restic -r "$RESTIC_REPO" snapshots >/dev/null 2>&1; then
  echo "Restic repo already exists at $RESTIC_REPO"
  exit 0
fi

restic -r "$RESTIC_REPO" init

echo "Initialized restic repo at $RESTIC_REPO"
