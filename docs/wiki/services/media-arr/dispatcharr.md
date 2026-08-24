---
title: Dispatcharr
updated: 2026-08-05
---

# Dispatcharr

LXC: [media arr](../../lxcs/media-arr.md) (CT 300) - IPTV channel manager and EPG aggregator for Jellyfin Live TV.

## Instance

| Setting | Value |
|---------|-------|
| Port | 9191 |
| Config | `/data/dispatcharr/` |
| Image | `ghcr.io/dispatcharr/dispatcharr:latest` |
| URL | `https://dispatcharr.home.example.com:<admin-port>` |
| Managed as | Komodo stack `media-arr` |

The AIO image is used (`DISPATCHARR_ENV=aio` in compose env). It bundles the backend, frontend, and EPG processor in one container. The AIO image runs as root - `PUID`/`PGID` are ignored. Config dir is owned `100000:100000` (host-side, due to idmap).

## Jellyfin Integration

Dispatcharr presents itself to Jellyfin as two endpoints:

| Endpoint | URL | Purpose |
|----------|-----|---------|
| HDHomeRun tuner | `http://<media-arr-ip>:9191/hdhr` | Channel stream source |
| XMLTV guide | `http://<media-arr-ip>:9191/output/epg/` | EPG data |

The `/output/epg/` trailing slash is required - Jellyfin sends it with the slash; Dispatcharr returns 404 without it.

After reordering channels in Dispatcharr: remove and re-add both the tuner and guide in Jellyfin to rebuild the channel map.

## EPG Sources

| Source ID | Coverage |
|-----------|---------|
| `US2` | US channels |
| `UK1` | UK channels |
| `JP1` | Japanese channels |
| `PLEX1` | Plex free channels |
| `IL1` | Israeli channels |

Sources are configured in Dispatcharr's EPG settings. Channels without a free EPG source can be mapped manually.

## Channel Matching

Dispatcharr auto-matches streams to EPG entries by name. For mismatches: select a channel → EPG tab → search and assign manually. Logo URLs can be set per-channel.
