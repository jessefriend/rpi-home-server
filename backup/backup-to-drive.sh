#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
EXCLUDE_FILE="${SCRIPT_DIR}/exclude.txt"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${RESTIC_REPO:?RESTIC_REPO is required. Copy backup/.env.example to backup/.env and set it.}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD is required. Copy backup/.env.example to backup/.env and set it.}"

KEEP_LAST="${KEEP_LAST:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"

if [[ ! -d "$(dirname "$RESTIC_REPO")" ]]; then
  echo "Drive mount path does not exist: $(dirname "$RESTIC_REPO")" >&2
  exit 1
fi

if ! restic -r "$RESTIC_REPO" snapshots >/dev/null 2>&1; then
  echo "Restic repo not found at $RESTIC_REPO"
  echo "Run ./backup/init-drive.sh first for this drive."
  exit 1
fi

BACKUP_PATHS=(
  /srv/appdata
  /srv/nas
)

if [[ -f "$REPO_ROOT/docker-compose.yml" ]]; then
  BACKUP_PATHS+=("$REPO_ROOT/docker-compose.yml")
fi

if [[ -f "$REPO_ROOT/.env" ]]; then
  BACKUP_PATHS+=("$REPO_ROOT/.env")
fi

if [[ -d /etc/caddy ]]; then
  BACKUP_PATHS+=(/etc/caddy)
fi

echo "Backing up to $RESTIC_REPO"
printf 'Included paths:\n'
printf '  %s\n' "${BACKUP_PATHS[@]}"

restic -r "$RESTIC_REPO" backup \
  --exclude-file "$EXCLUDE_FILE" \
  "${BACKUP_PATHS[@]}"

restic -r "$RESTIC_REPO" forget --prune \
  --keep-last "$KEEP_LAST" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY"

restic -r "$RESTIC_REPO" check --read-data-subset=5%

echo
echo "Backup finished successfully."
restic -r "$RESTIC_REPO" snapshots
