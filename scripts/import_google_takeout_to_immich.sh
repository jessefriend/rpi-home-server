#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Google Photos Takeout -> Immich importer for Raspberry Pi / Linux
#
# What it does:
# 1) Validates all Takeout ZIPs in TAKEOUT_DIR
# 2) Optionally extracts them to STAGING_DIR for local archival/inspection
# 3) Imports them into Immich using immich-go
# 4) Runs a few sanity checks and prints next steps
#
# Why it does NOT copy files into Immich's media folders directly:
# - Immich's official docs recommend immich-go for Google Photos Takeout imports.
# - Directly writing into Immich's storage folders is the risky path.

TAKEOUT_DIR="${TAKEOUT_DIR:-$HOME/takeout}"
STAGING_DIR="${STAGING_DIR:-/srv/nas/import/google-photos}"
LOG_DIR="${LOG_DIR:-$HOME/immich-import-logs}"
IMMICH_URL="${IMMICH_URL:-http://localhost:2283}"
IMMICH_API_KEY="${IMMICH_API_KEY:-}"
IMMICH_GO_BIN="${IMMICH_GO_BIN:-/usr/local/bin/immich-go}"

# Set to true if you want the ZIPs extracted to STAGING_DIR as well.
EXTRACT_ARCHIVES="${EXTRACT_ARCHIVES:-true}"
KEEP_EXTRACTED="${KEEP_EXTRACTED:-true}"

# Conservative defaults for a Pi
CONCURRENT_TASKS="${CONCURRENT_TASKS:-4}"
CLIENT_TIMEOUT="${CLIENT_TIMEOUT:-60m}"
PAUSE_IMMICH_JOBS="${PAUSE_IMMICH_JOBS:-true}"
ON_ERRORS="${ON_ERRORS:-continue}"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf '[%s] %s\n' "$(ts)" "$*" | tee -a "$MAIN_LOG" ; }
die() { log "ERROR: $*"; exit 1; }

cleanup_on_error() {
  local rc=$?
  log "Aborted with exit code $rc"
  log "See logs in: $LOG_DIR"
  exit "$rc"
}
trap cleanup_on_error ERR INT TERM

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

bytes_to_human() {
  numfmt --to=iec-i --suffix=B "$1"
}

mkdir -p "$LOG_DIR"
MAIN_LOG="$LOG_DIR/import-$(date +%Y%m%d-%H%M%S).log"
touch "$MAIN_LOG"

log "Starting Google Photos Takeout -> Immich import"
log "TAKEOUT_DIR=$TAKEOUT_DIR"
log "STAGING_DIR=$STAGING_DIR"
log "IMMICH_URL=$IMMICH_URL"
log "EXTRACT_ARCHIVES=$EXTRACT_ARCHIVES"
log "KEEP_EXTRACTED=$KEEP_EXTRACTED"

require_cmd bash
require_cmd find
require_cmd awk
require_cmd sed
require_cmd grep
require_cmd df
require_cmd du
require_cmd unzip
require_cmd curl
require_cmd tee
require_cmd sort
require_cmd xargs
require_cmd mktemp
require_cmd numfmt

[ -d "$TAKEOUT_DIR" ] || die "Takeout directory not found: $TAKEOUT_DIR"

mapfile -d '' ZIPS < <(find "$TAKEOUT_DIR" -maxdepth 1 -type f -name '*.zip' -print0 | sort -z)
[ "${#ZIPS[@]}" -gt 0 ] || die "No .zip files found in $TAKEOUT_DIR"

if [ -z "$IMMICH_API_KEY" ]; then
  die "IMMICH_API_KEY is empty. Export it first, e.g.: export IMMICH_API_KEY='your-api-key'"
fi

log "Checking Immich endpoint..."
HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' "$IMMICH_URL" || true)"
if [ "$HTTP_CODE" = "000" ]; then
  die "Could not reach Immich at $IMMICH_URL"
fi
log "Immich responded with HTTP $HTTP_CODE at $IMMICH_URL"

log "Found ${#ZIPS[@]} zip file(s):"
for z in "${ZIPS[@]}"; do
  size_bytes="$(stat -c '%s' "$z")"
  log "  - $(basename "$z") ($(bytes_to_human "$size_bytes"))"
done

log "Testing ZIP integrity..."
for z in "${ZIPS[@]}"; do
  log "Testing $(basename "$z")"
  unzip -tqq "$z" >>"$MAIN_LOG" 2>&1 || die "ZIP integrity check failed: $z"
done
log "All ZIP integrity checks passed"

total_zip_bytes=0
for z in "${ZIPS[@]}"; do
  size_bytes="$(stat -c '%s' "$z")"
  total_zip_bytes=$(( total_zip_bytes + size_bytes ))
done

if [ "$EXTRACT_ARCHIVES" = "true" ]; then
  mkdir -p "$STAGING_DIR"
  free_bytes="$(df -B1 --output=avail "$STAGING_DIR" | tail -n1 | tr -d ' ')"
  recommended_bytes=$(( total_zip_bytes * 2 ))
  log "Total ZIP size: $(bytes_to_human "$total_zip_bytes")"
  log "Free space on staging filesystem: $(bytes_to_human "$free_bytes")"
  log "Recommended free space for extraction: about $(bytes_to_human "$recommended_bytes")"
  if [ "$free_bytes" -lt "$recommended_bytes" ]; then
    die "Not enough free space for safe extraction in $STAGING_DIR"
  fi
fi

install_immich_go() {
  local arch url tmpdir
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64) arch="arm64" ;;
    x86_64|amd64) arch="x86_64" ;;
    *)
      die "Unsupported architecture for automatic immich-go install: $arch"
      ;;
  esac

  url="https://github.com/simulot/immich-go/releases/latest/download/immich-go_Linux_${arch}.tar.gz"
  tmpdir="$(mktemp -d)"
  log "Downloading immich-go from: $url"
  curl -fsSL "$url" -o "$tmpdir/immich-go.tgz"
  tar -xzf "$tmpdir/immich-go.tgz" -C "$tmpdir"
  sudo install -m 0755 "$tmpdir/immich-go" "$IMMICH_GO_BIN"
  rm -rf "$tmpdir"
}

if [ ! -x "$IMMICH_GO_BIN" ]; then
  log "immich-go not found at $IMMICH_GO_BIN; installing..."
  require_cmd tar
  require_cmd sudo
  install_immich_go
fi

"$IMMICH_GO_BIN" --help >/dev/null 2>&1 || die "immich-go exists but failed to run"
log "immich-go ready: $IMMICH_GO_BIN"

if [ "$EXTRACT_ARCHIVES" = "true" ]; then
  mkdir -p "$STAGING_DIR"
  log "Extracting archives to $STAGING_DIR ..."
  for z in "${ZIPS[@]}"; do
    log "Extracting $(basename "$z")"
    unzip -q -o "$z" -d "$STAGING_DIR"
  done

  if [ -d "$STAGING_DIR/Takeout" ]; then
    TAKEOUT_ROOT="$STAGING_DIR/Takeout"
  else
    TAKEOUT_ROOT="$STAGING_DIR"
  fi

  media_count="$(find "$TAKEOUT_ROOT" -type f \(       -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o       -iname '*.webp' -o -iname '*.heic' -o -iname '*.heif' -o -iname '*.tif' -o -iname '*.tiff' -o       -iname '*.mp4' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.mkv' -o -iname '*.webm' -o       -iname '*.m4v' -o -iname '*.3gp' -o -iname '*.dng' -o -iname '*.arw' -o -iname '*.cr2' -o -iname '*.nef'     \) | wc -l | tr -d ' ')"

  json_count="$(find "$TAKEOUT_ROOT" -type f -iname '*.json' | wc -l | tr -d ' ')"

  [ "$media_count" -gt 0 ] || die "Extraction completed, but no media files were found under $TAKEOUT_ROOT"
  log "Extraction sanity check passed: media files=$media_count, json sidecars=$json_count"
fi

log "Starting upload with immich-go..."
log "This uses the ZIP files directly; it does NOT write into Immich's media folders by hand."

IMPORT_CMD=(
  "$IMMICH_GO_BIN" upload from-google-photos
  "--server=$IMMICH_URL"
  "--api-key=$IMMICH_API_KEY"
  "--concurrent-tasks=$CONCURRENT_TASKS"
  "--client-timeout=$CLIENT_TIMEOUT"
  "--pause-immich-jobs=$PAUSE_IMMICH_JOBS"
  "--on-errors=$ON_ERRORS"
  "--session-tag"
)

for z in "${ZIPS[@]}"; do
  IMPORT_CMD+=("$z")
done

printf '%q ' "${IMPORT_CMD[@]}" | tee -a "$MAIN_LOG"
printf '\n' | tee -a "$MAIN_LOG"

"${IMPORT_CMD[@]}" 2>&1 | tee -a "$MAIN_LOG"

log "Import command finished."
log "Next sanity checks:"
log "  1) Open Immich and verify a few old photos have correct dates"
log "  2) In Immich admin, check Administration -> Jobs until queues drain"
log "  3) Keep your original ZIPs until you are satisfied with the import"

if [ "$EXTRACT_ARCHIVES" = "true" ] && [ "$KEEP_EXTRACTED" != "true" ]; then
  log "Removing extracted staging data from $STAGING_DIR"
  rm -rf "$STAGING_DIR"
fi

log "Done."
