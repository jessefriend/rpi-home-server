#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your normal user, not root."
  exit 1
fi

echo "== Installing base packages =="
sudo apt-get update
sudo apt-get install -y curl ca-certificates restic

if ! command -v docker >/dev/null 2>&1; then
  echo "== Installing Docker =="
  curl -fsSL https://get.docker.com | sh
fi

if ! groups "$USER" | grep -q '\bdocker\b'; then
  echo "== Adding ${USER} to docker group =="
  sudo usermod -aG docker "$USER"
  echo
  echo "Log out and back in once before using Docker without sudo."
  echo
fi

echo "== Creating directories =="
sudo mkdir -p /srv/nas/photos/immich-library
sudo mkdir -p /srv/nas/files/opencloud-data
sudo mkdir -p /srv/appdata/immich/postgres
sudo mkdir -p /srv/appdata/opencloud/config
sudo mkdir -p /srv/appdata/caddy/data
sudo mkdir -p /srv/appdata/caddy/config

if [[ ! -f .env ]]; then
  echo "== Creating .env from template =="
  cp .env.example .env
  echo
  echo "Edit .env before continuing:"
  echo "  nano .env"
  echo
fi

echo "== Bootstrap complete =="
echo
echo "Next steps:"
echo "  1. Edit .env"
echo "  2. If rebuilding, mount backup drive and run:"
echo "       ./backup/restore-latest.sh /"
echo "  3. Initialize OpenCloud once if needed:"
echo "       docker compose --profile init run --rm opencloud-init"
echo "  4. Start the stack:"
echo "       docker compose up -d --build"
