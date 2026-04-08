#!/usr/bin/env bash
set -euo pipefail

curl -fsSL https://tailscale.com/install.sh | sh

echo "Run: sudo tailscale up"
