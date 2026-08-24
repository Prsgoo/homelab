---
title: Jellyfin
updated: 2026-08-05
---

# Jellyfin

LXC: [media server](../../lxcs/media-server.md) (CT 301) - media server.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8096 |
| Config | `/data/jellyfin/` |
| UID/GID | 1310:1310 |
| URL | `https://jellyfin.home.example.com` (user-facing, `:443`) |
| Managed as | Komodo stack `media-server` |

## Libraries

| Library | Path | Type |
|---------|------|------|
| TV | `/media/tv/` | Shows |
| Anime | `/media/anime/` | Shows |
| Movies | `/media/movies/` | Movies |
| Movies 4K | `/media/movies-4k/` | Movies |

Keep Movies and Movies 4K as separate libraries - merging them hides the quality distinction and complicates Seerr's request routing.

## Live TV

| Setting | Value |
|---------|-------|
| Tuner type | HDHomeRun |
| Tuner URL | `http://<media-arr-ip>:9191/hdhr` |
| Guide type | XMLTV |
| Guide URL | `http://<media-arr-ip>:9191/output/epg/` |

Trailing slash on the guide URL is required. After reordering channels in Dispatcharr, remove and re-add both tuner and guide in Jellyfin to rebuild the channel map.

## Remote Access

Jellyfin is on the LAN only (<media-server-ip>). Remote access is via Tailscale - CT 100 acts as the subnet router, advertising `<your-ip-range>`. Tailscale clients reach Jellyfin through the Traefik route on CT 100.

Add the Tailscale IP of CT 100 to Jellyfin's Published Server URIs if needed for direct client detection.

## Seerr Integration

Seerr connects via `http://<media-server-ip>:8096` (direct LAN, not through Traefik). Configure the Jellyfin API key in Seerr → Settings → Media Servers.

## Key Takeaways

- Movies and Movies 4K must remain separate libraries - do not merge
- Live TV guide URL requires trailing slash on `/output/epg/`
- After channel reorder in Dispatcharr: remove + re-add tuner and guide in Jellyfin
- Hardware transcoding not configured - CT 301 has no `/dev/dri` passthrough
