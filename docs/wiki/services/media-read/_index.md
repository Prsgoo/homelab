---
title: Media Read Services
updated: 2026-09-29
---

# Media Read Services (CT 303)

→ [CT 303 spec](../../lxcs/media-read.md)

## Suwayomi

Manga downloader and reader. Downloads from online sources, stores as CBZ archives.

| Setting | Value |
|---------|-------|
| Image | `ghcr.io/suwayomi/suwayomi-server:latest` |
| Port | 4567 |
| UID | 1000 (hardcoded - see [exceptions](../standards/service-uid-exceptions.md)) |
| GID | 1300 (`media`) |
| Config | `/data/suwayomi` → `/home/suwayomi/.local/share/Tachidesk` |
| Downloads | `/manga` |

**Download path**: After first boot, go to Settings > Downloads and set the path to `/manga`. Enable CBZ format (also set via `DOWNLOAD_AS_CBZ=true` env var).

## Komga

Manga library server and OPDS catalog.

| Setting | Value |
|---------|-------|
| Image | `gotson/komga:latest` |
| Port | 25600 |
| UID:GID | `1331:1300` |
| Config | `/data/komga` |
| Library | `/manga` (read-only) |

**Library setup**: After first boot, add `/manga` as a library in Komga's web UI. Komga scans CBZ files and generates metadata.

**OPDS feed**: `http://komga.home.<domain>/opds/v1.2/catalog` - use this in Aidoku or any OPDS reader.

## Komf

Metadata enricher. Connects to Komga and writes `ComicInfo.xml` into CBZ archives using AniList, MangaUpdates, and MAL as sources.

| Setting | Value |
|---------|-------|
| Image | `sndxr/komf:latest` |
| UID:GID | `1332:1300` |
| Config | `/data/komf` |

**Komga connection**: configured via `KOMF_KOMGA_BASE_URI`, `KOMF_KOMGA_USERNAME`, `KOMF_KOMGA_PASSWORD` env vars in compose `.env`.

Komf runs as a background service and processes libraries automatically. It can also be triggered via its REST API.
