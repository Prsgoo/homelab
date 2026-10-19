---
title: Media Read Services
updated: 2026-09-29
---

# Media Read Services (CT 303)

→ [CT 303 spec](../../lxcs/media-read.md)

## Suwayomi

Manga downloader and server. Downloads from online sources (MangaDex, Weeb Central, etc.), stores as CBZ archives, and serves via OPDS.

| Setting | Value |
|---------|-------|
| Image | `ghcr.io/suwayomi/suwayomi-server:latest` |
| Port | 4567 |
| UID | 1000 (hardcoded - see [exceptions](../standards/service-uid-exceptions.md)) |
| GID | 1300 (`media`) |
| Config | `/data/suwayomi` → `/home/suwayomi/.local/share/Tachidesk` |
| Downloads | `/manga` |

**Download path**: Go to Settings > Downloads and set the path to `/manga`. CBZ format enabled via `DOWNLOAD_AS_CBZ=true` env var.

**Download structure**: Suwayomi organizes downloads as `/manga/mangas/<Source Name>/<Manga Title>/<Chapter>.cbz`. In Grimmory, add each source subfolder (`/library/manga/mangas/<Source Name>/`) as a separate folder within the manga library.

**OPDS**: Suwayomi exposes an OPDS feed at `http://<server-ip>:4567/api/opds/v1.2/catalog` - reading apps can connect here and read chapters on-demand without downloading.

**DNS override**: Suwayomi uses `dns: [1.1.1.1, 8.8.8.8]` in compose to bypass Pi-hole, which blocks some manga source domains.
