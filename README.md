# Pi Home Server

Raspberry Pi 5 home server with:

- Immich
- OpenCloud
- Caddy
- Dashy
- Tailscale
- restic-based rotating-drive backups

The intended model is:

- custom domain access
- HTTPS everywhere
- Tailscale-only exposure
- Docker-first
- simple rebuild flow

---

## Current architecture

```text
Client device
   │
   ▼
Tailscale
   │
   ▼
photos.example.com / cloud.example.com / home.example.com
   │
   ▼
Caddy (TLS + reverse proxy)
   ├──> Immich
   ├──> OpenCloud
   └──> Dashy

Data:
- /srv/nas
- /srv/appdata
```

Notes:

- DNS records point to the Pi's Tailscale IP.
- Services are intentionally not exposed publicly.
- Caddy is the only service publishing ports 80/443.
- Immich, OpenCloud, and Dashy stay internal to the Docker network.

---

## Services

| Service | Purpose | Access |
|---|---|---|
| Caddy | Reverse proxy + HTTPS | `https://photos.example.com`, `https://cloud.example.com`, `https://home.example.com` |
| Immich | Photo backup / gallery | proxied through Caddy |
| OpenCloud | File storage | proxied through Caddy |
| Dashy | Dashboard / service launcher | proxied through Caddy |
| PostgreSQL | Immich database | internal only |
| Valkey/Redis | Immich cache/queue | internal only |

---

## Data paths

- Immich library: `/srv/nas/photos/immich-library`
- Immich DB: `/srv/appdata/immich/postgres`
- OpenCloud data: `/srv/nas/files/opencloud-data`
- OpenCloud config: `/srv/appdata/opencloud/config`
- Caddy data: `/srv/appdata/caddy/data`
- Caddy config state: `/srv/appdata/caddy/config`

---

## Access

Inside Tailscale only:

- `https://photos.example.com` → Immich
- `https://cloud.example.com` → OpenCloud
- `https://home.example.com` → Dashy

No public exposure is intended.

---

## Initial setup

### 1. Clone the repo

```bash
git clone <your-repo-url>
cd pi-home-server
```

### 2. Run bootstrap

```bash
./scripts/bootstrap.sh
```

### 3. Create and edit env

```bash
cp .env.example .env
nano .env
```

If you use private or Tailscale-only hostnames, set `CADDY_DNS_PLUGIN` and `CADDY_TLS_ISSUER_CONFIG` in `.env` before building Caddy.

### 4. Initialize OpenCloud once if needed

```bash
docker compose --profile init run --rm opencloud-init
```

### 5. Start the stack

```bash
docker compose up -d --build
```

---

## Rebuild / recovery flow

Goal: a simple, repeatable rebuild from a fresh Pi.

### Fresh rebuild steps

```bash
# 1. Fresh Raspberry Pi OS

# 2. Clone repo
git clone <your-repo-url>
cd pi-home-server

# 3. Install prerequisites and create directories
./scripts/bootstrap.sh

# 4. Configure env
nano .env

# 5. Mount backup drive
# example only; adjust device/path as needed
sudo mkdir -p /mnt/backup
sudo mount /dev/sdX1 /mnt/backup

# 6. Restore data
./backup/restore-latest.sh /

# 7. Initialize OpenCloud once if needed
docker compose --profile init run --rm opencloud-init

# 8. Start services
docker compose up -d --build
```

### Verify

```bash
docker compose ps
curl -I https://photos.example.com
curl -I https://cloud.example.com
curl -I https://home.example.com
```

---

## Backup system

The canonical backup system is the `backup/` directory.

It uses:

- restic
- rotating external HDDs
- versioned backups
- restore support

See:

- [`backup/README.md`](backup/README.md)

Legacy `scripts/backup.sh` has been removed on purpose.  
There is one backup system only: `backup/`.

---

## Common commands

```bash
docker compose up -d
docker compose down
docker compose pull
docker compose logs -f
docker compose ps
docker compose --profile init run --rm opencloud-init
```

---

## Immich notes

If Immich storage markers or folder layout need repair:

```bash
./scripts/fix-immich-storage.sh
```

If you want to fully reset Immich:

```bash
./scripts/reset-immich-clean.sh
```

---

## OpenCloud notes

- `OPENCLOUD_URL` must match the browser URL exactly.
- For this setup, that means:

```dotenv
OPENCLOUD_URL=https://cloud.example.com
```

- In practice, OpenCloud should be treated as depending on a restored config directory.
- For rebuilds, assume the reliable path is:
  1. restore `/srv/appdata/opencloud/config` from backup
  2. then start OpenCloud
- Do not assume `opencloud-init` alone fully reproduces a working config from an empty directory in every case.

---

## Dashy notes

- Dashy config lives in the repo at `dashy/conf.yml`.
- It is part of the rebuild path.
- Access URL:

```text
https://home.example.com
```

---

## Security

- Do not commit `.env`
- Rotate any previously exposed credentials
- Rotate DNS provider API credentials if they were ever leaked
- Keep the services Tailscale-only unless you explicitly decide otherwise

Lower priority, optional hardening:

- firewall rules
- fail2ban
- service-by-service review

---

## Next likely additions

Once repo/recovery is stable:

- Home Assistant
- Collabora + WOPI
