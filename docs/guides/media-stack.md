# Media Stack

## What you'll end up with

A complete self-hosted media pipeline across three LXCs: Sonarr and Radarr managing your library in CT 300, qBittorrent and SABnzbd downloading in CT 302, and Jellyfin serving everything in CT 301. All three containers write to the same physical directories on the data disk using a shared GID - no NFS, no copies, hardlinks throughout.

Seerr sits on CT 300 as the request frontend, connecting Jellyfin and the \*arr stack so you can search for and request content from one place.

---

## Prerequisites

- Komodo running
- Traefik running (for service access via subdomain)
- Data disk mounted at `$DATA_ROOT` with media directories created by `host-prep.sh`

---

## How the cross-CT file sharing works

This is the most important thing to understand before deploying. Three separate LXCs all need read/write access to the same directories on the host (`$DATA_ROOT/media-stack/`).

The solution: a `media` group with GID `1300` that exists on the Proxmox host. Each relevant CT uses an `lxc.idmap` override that maps GID 1300 → 1300 (1:1, no offset). So:

- Sonarr (CT 300) runs as GID 1300 → maps to host GID 1300 ?
- qBittorrent (CT 302) runs as GID 1300 → maps to host GID 1300 ?
- Jellyfin (CT 301) runs as GID 1300 → maps to host GID 1300 ?

All three read and write the same files on the host. No network layer. See [Architecture → Cross-CT File Sharing](../architecture.md) for the full explanation.

The CT scripts handle all the idmap, bind mount, and directory ownership setup automatically.

---

## 1. Create the LXCs

All three are Docker LXCs:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| CT | Name | Cores | RAM | Disk | IP |
|----|------|-------|-----|------|----|
| 300 | media-arr | 4 (limit 2) | 4096 MB | **16 GB** | <media-arr-ip> |
| 301 | media-server | 4 (limit 3) | 4096 MB | 8 GB | <media-server-ip> |
| 302 | media-dl | 2 (limit 2) | 1024 MB | 8 GB | <media-dl-ip> |

!!! warning "CT 300 needs 16 GB rootfs"
    Dispatcharr's all-in-one image is ~3.9 GB alone. With all services, CT 300 fills up fast. 16 GB is the minimum to have headroom for updates.

---

## 2. Run the CT scripts

```bash
cd /opt/proxmox-admin
bash scripts/ct300-media-arr.sh
bash scripts/ct301-media-server.sh
bash scripts/ct302-media-dl.sh
```

Each script creates the service users and groups on the host, sets directory ownership, configures idmap, applies bind mounts, and installs Periphery.

---

## 3. Fill in stack secrets

The Unpackerr service in `media-arr` needs Sonarr and Radarr API keys to unpack completed downloads. These go in the stack `.env`:

```bash
pct exec 300 -- nano /data/komodo/stacks/media-arr/.env
```

| Variable | Where to get it |
|----------|----------------|
| `SONARR_URL` | `http://<media-arr-ip>:8989` |
| `SONARR_API_KEY` | Sonarr → Settings → General → API Key |
| `RADARR_URL` | `http://<media-arr-ip>:7878` |
| `RADARR_API_KEY` | Radarr → Settings → General → API Key |

You can deploy the stack first and add these after Sonarr and Radarr are running.

The `media-server` stack needs credentials for Jellystat (the Jellyfin analytics service):

```bash
pct exec 301 -- nano /data/komodo/stacks/media-server/.env
```

| Variable | Value |
|----------|-------|
| `POSTGRES_PASSWORD` | Random strong password for the Jellystat database |
| `JWT_SECRET` | Random secret for Jellystat JWT tokens |

---

## 4. Deploy stacks via Komodo

Add the servers to Komodo first (CT 300, 301, 302), then deploy:

| Server | Stack | Notes |
|--------|-------|-------|
| media-arr | `media-arr` | Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Dispatcharr, Unpackerr |
| media-server | `media-server` | Jellyfin, Jellystat |
| media-dl | `media-dl` | qBittorrent, SABnzbd |

---

## 5. Configure Prowlarr (indexers)

Prowlarr is the indexer manager - it pushes indexer configs to Sonarr and Radarr so you don't configure indexers in each app separately.

1. Open Prowlarr at `https://prowlarr.home.example.com:<admin-port>`
2. **Settings → Apps → Add Application**: add Sonarr and Radarr with their local URLs and API keys
3. **Indexers → Add Indexer**: add your indexers
4. Prowlarr automatically syncs them to Sonarr and Radarr

---

## 6. Configure Sonarr and Radarr

**Download client** (both apps, Settings → Download Clients → Add):

| Setting | Value |
|---------|-------|
| Type | qBittorrent |
| Host | `<media-dl-ip>` |
| Port | `8080` |
| Category | `sonarr` (Sonarr) / `radarr` (Radarr) |

Use the LAN IP - Sonarr and Radarr are in CT 300, qBittorrent is in CT 302, so Docker container names don't work.

**Hardlinks** (Settings → Media Management):

Enable **Use Hardlinks Instead of Copy**. This is critical - without hardlinks, every completed download gets copied to the library, doubling your disk usage. With hardlinks, the file exists once on disk with two directory entries (one in `/torrents/`, one in `/media/`), and qBittorrent can continue seeding while the file is "in" the library.

Hardlinks work here because `/torrents/` (mounted in CT 302) and `/media/` (mounted in CT 300 and CT 301) all come from the same host filesystem (`$DATA_ROOT/`).

---

## 7. Configure qBittorrent

Open at `https://downloads.home.example.com:<admin-port>`.

**Categories** (right-click in category list → Add category):

| Category | Save path |
|----------|-----------|
| `sonarr` | `/torrents/tv/` |
| `radarr` | `/torrents/movies/` |

**Seeding limits** (Settings → BitTorrent):

- Ratio limit: `1.0`
- When ratio reached: **Pause** (not Remove - lets you review before deletion)

**DNS override**: qBittorrent uses external DNS (`1.1.1.1`, `8.8.8.8`) in the compose file - Pi-hole blocks many tracker domains, so qBittorrent must bypass it.

---

## 8. Configure Jellyfin

Open at `https://jellyfin.home.example.com` and complete the setup wizard.

**Libraries** (Dashboard → Libraries → Add Media Library):

| Library name | Path | Content type |
|-------------|------|--------------|
| TV | `/media/tv` | Shows |
| Anime | `/media/anime` | Shows |
| Movies | `/media/movies` | Movies |
| Movies 4K | `/media/movies-4k` | Movies |

Keep Movies and Movies 4K as separate libraries - merging them loses the quality distinction that Seerr uses for routing requests.

---

## 9. Configure Seerr

Seerr is the request portal - users search for content and request it, which creates tasks in Sonarr/Radarr.

1. Open Seerr at `https://seerr.home.example.com`
2. **Settings → Jellyfin**: connect with `http://<media-server-ip>:8096` (LAN IP, not through Traefik) and a Jellyfin API key
3. **Settings → Sonarr**: `http://<media-arr-ip>:8989`
4. **Settings → Radarr**: `http://<media-arr-ip>:7878`

Use LAN IPs for all connections - everything is on the same network, and going through Traefik adds unnecessary overhead.

---

## Day-2 operations

### Updating services

Update one at a time to avoid filling CT 300's rootfs:

```bash
pct exec 300 -- bash -c 'cd /data/komodo/stacks/media-arr && docker compose pull sonarr && docker compose up -d sonarr && docker image prune -f'
```

Or use Komodo UI: deploy the stack, which pulls all images at once - be aware this can consume significant temp space.

### Checking library health

- Sonarr/Radarr: **System → Status** shows health checks for indexers and download clients
- Jellyfin: **Dashboard → Libraries → Scan All Libraries** after adding new content

### Freeing disk space

After torrents finish seeding, Sonarr/Radarr can delete them from qBittorrent. Configure in each app under Settings → Download Clients → check "Remove Completed Downloads".

---

## Troubleshooting

**Permission denied writing to `/media/` or `/torrents/`**

Check that the idmap is correctly applied. Inside CT 300:

```bash
docker exec sonarr id
# Expected: uid=1300 gid=1300

ls -la /media/
# Expected: drwxrwxr-x ... 1300 1300 tv
```

If the GID doesn't match, the CT script may not have run, or the idmap needs to be re-applied (stop the CT, verify `/etc/pve/lxc/300.conf` has the idmap block, start again).

**Hardlinks not working**

Verify Sonarr/Radarr and qBittorrent are all reading/writing from the same host filesystem. Check the bind mounts: CT 300 must have `/media` and `/torrents` mounted from `$DATA_ROOT/media-stack/`, and CT 302 must have `/torrents` from the same path.

Test: `pct exec 300 -- stat /torrents/tv/somefile.mkv` and `pct exec 300 -- stat /media/tv/Show/somefile.mkv` - the inode number should be identical if hardlinks are working.

**qBittorrent not receiving downloads from Sonarr/Radarr**

Confirm Sonarr/Radarr are using the IP `<media-dl-ip>:8080` (not a Docker container name). Container names don't work across LXC boundaries.
