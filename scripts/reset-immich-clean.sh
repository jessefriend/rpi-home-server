#!/usr/bin/env bash
set -euo pipefail

IMMICH_ROOT="/srv/nas/photos/immich-library"
IMMICH_DB="/srv/appdata/immich/postgres"

cd "$(dirname "$0")/.."

docker compose down

sudo rm -rf "${IMMICH_ROOT:?}/"*
sudo rm -rf "${IMMICH_DB:?}/"*

sudo mkdir -p "${IMMICH_ROOT}"/{upload,library,thumbs,encoded-video,profile,backups}

sudo touch "${IMMICH_ROOT}/upload/.immich"
sudo touch "${IMMICH_ROOT}/library/.immich"
sudo touch "${IMMICH_ROOT}/thumbs/.immich"
sudo touch "${IMMICH_ROOT}/encoded-video/.immich"
sudo touch "${IMMICH_ROOT}/profile/.immich"
sudo touch "${IMMICH_ROOT}/backups/.immich"

sudo chown -R 1000:1000 "${IMMICH_ROOT}"
sudo mkdir -p "${IMMICH_DB}"
sudo chown -R 999:999 "${IMMICH_DB}"

docker compose up -d --force-recreate
docker compose ps
