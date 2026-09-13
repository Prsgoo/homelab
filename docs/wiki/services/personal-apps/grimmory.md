---
title: Grimmory
updated: 2026-09-13
---

# Grimmory

Self-hosted digital library for managing and reading ebooks. Java Spring Boot backend with Angular frontend, MariaDB for metadata storage.

## Details

| Setting | Value |
|---------|-------|
| LXC | CT 600 (personal-apps) |
| Image | `ghcr.io/grimmory-tools/grimmory:latest` |
| DB Image | `lscr.io/linuxserver/mariadb:11.4.5` |
| Port | 6060 |
| UID/GID | 1600 (grimmory / personal-apps) |
| Data | `/data/grimmory/data` → `$DATA_ROOT/config/personal-apps/grimmory/data` |
| DB | `/data/grimmory/db` → `$DATA_ROOT/config/personal-apps/grimmory/db` |
| Books | `/books` → `$DATA_ROOT/media-stack/media/books` |
| BookDrop | `/data/grimmory/bookdrop` → `$DATA_ROOT/config/personal-apps/grimmory/bookdrop` |
| Komodo stack | `grimmory` |
| Route | `https://grimmory.<your-domain>` (admin-only) |

## Env Variables (stack .env)

```
GRIMMORY_DB_PASSWORD=<value>
GRIMMORY_DB_ROOT_PASSWORD=<value>
```

## Key Takeaways

- BookDrop is a watched folder - drop any ebook file there and Grimmory imports and categorizes it automatically
- Books live on the shared media pool (`media-stack/media/books`), readable from both the media-arr LXC and personal-apps
- `DISK_TYPE=LOCAL` is required - the container will not work without it
- `API_DOCS_ENABLED=false` disables the Swagger UI (unnecessary in production)
- MariaDB healthcheck must use `mariadb-admin ping` - the linuxserver image does not have `healthcheck.sh`
- Grimmory waits for `service_healthy` on the DB, so a slow MariaDB init delays the whole stack
- Java/Spring Boot cold start takes 3-5 minutes - the container will be unhealthy during that time, that is normal
- Metadata is stored in MariaDB, not written back into the epub files

## Metadata

Grimmory fetches metadata from Google Books and Open Library automatically on import via BookDrop.

To manually fetch or update metadata for an existing book:
1. Open the book and click the edit/detail panel
2. Go to the **Match** tab
3. Enter the ISBN (preferred) and hit search
4. Select the result and apply

Books from Anna's Archive often have malformed epub metadata (`dc:creator` as `Lastname, Firstname, Translator` in a single field, garbage identifiers). If Grimmory can't find metadata after import:
- Open the book's Match tab and search by ISBN
- Or edit metadata manually in the Edit tab - the correct data from the Grimmory UI is stored in MariaDB regardless of what's in the epub

## Troubleshooting

**Container never becomes healthy / keeps restarting**

Check that MariaDB came up first:
```bash
docker logs grimmory-db --tail 20
docker logs grimmory --tail 30
```

If the DB healthcheck is failing, the `grimmory` container will not start. Wait for the DB to report healthy before expecting the app to respond.

**Books directory not writable / no books visible**

The `/books` bind mount maps to `$DATA_ROOT/media-stack/media/books` on the host. The directory must be owned (or at least readable) by UID 1600 on the host. The idmap in CT 600 passes UID 1600 through 1:1 to the host, so host ownership should also be 1600.

**File permission errors in data directory**

The container runs as UID 1600 internally. The host path `$DATA_ROOT/config/personal-apps/grimmory/` must be owned by 1600:1600 on the host (passed through 1:1 via idmap).

```bash
chown -R 1600:1600 $DATA_ROOT/config/personal-apps/grimmory/
```
