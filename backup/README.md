# Backup System

This directory contains the canonical backup system for the Pi home server.

## Overview

The backup setup uses:

- restic
- rotating external HDDs
- versioned snapshots
- restore support

This is the only supported backup path for the system.

---

## What is backed up

The intended backup coverage includes:

- `/srv/nas`
- `/srv/appdata`
- repo deployment state such as:
  - `docker-compose.yml`
  - `.env`
  - `caddy/`
  - other rebuild-critical repo files if included in the backup source list

In practice, this covers the important persistent service state for:

- Immich library and database
- OpenCloud data and config
- Caddy data/config state
- deployment configuration

---

## What is not guaranteed to be backed up

Do not assume the following are covered unless you explicitly add them:

- OS packages
- apt-installed software state
- Tailscale machine state
- firewall rules
- host-level manual tweaks outside the repo and backup source list
- secrets stored outside `.env` or outside the backed-up paths

---

## Usage

### Initialize a backup drive

```bash
./init-drive.sh
```

### Run a backup

```bash
./backup-to-drive.sh
```

### Restore latest snapshot

```bash
./restore-latest.sh /target/path
```

### Restore to live filesystem

```bash
./restore-latest.sh /
```

This will prompt for confirmation.

---

## Recommended recovery model

For rebuilds, use this order:

1. Fresh OS
2. Clone repo
3. Run `./scripts/bootstrap.sh`
4. Configure `.env`
5. Mount backup drive
6. Restore backup
7. Start services

For OpenCloud specifically, the reliable assumption is:

1. restore `/srv/appdata/opencloud/config`
2. then start OpenCloud

Do not rely on an empty config directory being fully recreated by init alone in every case.

---

## Verification after backup

After running a backup, confirm that:

- a new restic snapshot exists
- the expected directories are included
- restore works to a temporary test location from time to time

A simple restore test target is:

```bash
mkdir -p /tmp/restore-test
./restore-latest.sh /tmp/restore-test
```

---

## Notes

- Keep `RESTIC_PASSWORD` safe.
- Rotate the external drives as planned.
- Test restores periodically, not just backups.
- During an actual cutover or recovery, avoid improvising. Follow the documented rebuild flow.
