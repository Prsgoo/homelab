---
title: User/Group Scheme
updated: 2026-07-31
---

# User/Group Scheme

## Pattern

Every service LXC follows the same rule:
- One **shared group** per access domain (controls access to shared data on $DATA_ROOT)
- One **user per service** (isolates each service to its own config directory only)
- Services run with `PUID`/`PGID` env vars in docker-compose (most LinuxServer.io images support this natively)

This means Radarr can write to its own config dir and to the shared movies folder, but cannot touch Sonarr's config. Jellyfin can read the full media library but cannot write to any config folder.

> Before creating any user or group, read [lxc idmap](lxc-idmap.md) - the Proxmox unprivileged LXC UID remapping affects how host-side ownership must be set up.

---

## Shared Groups

These GIDs **must be identical on the host and inside every LXC** that accesses the same $DATA_ROOT subdirectory. The host filesystem only sees numbers - if two LXCs use different GIDs for `media`, cross-container permissions break.

GIDs are set to the start of the UID range for that domain, so the numbering is self-consistent: IoT UIDs start at 1200 → iot GID is 1200, etc.

| GID  | Group            | Purpose                                      | Used by             |
| ---- | ---------------- | -------------------------------------------- | ------------------- |
| 1200 | `iot`            | IoT service shared data                      | iot (CT 201)        |
| 1210 | `ultrafeeder`    | ADS-B feeder data (single-service group)     | ultrafeeder (CT 200) only |
| 1300 | `media`          | Shared media library (movies, TV, downloads) | CT 300 (media-arr), CT 301 (media-server), CT 302 (media-dl), CT 303 (media-read), CT 600 (personal-apps - grimmory) |
| 1400 | `gaming`         | Game server data                             | future game LXCs    |
| 1600 | `personal-apps`  | Personal app config access                   | CT 600 (personal-apps) |

Create on host and in every LXC that needs the group:
```bash
groupadd -g 1200 iot
groupadd -g 1300 media
groupadd -g 1400 gaming
groupadd -g 1600 personal-apps
```

---

## Per-Service User UID Ranges

UID ranges mirror the LXC ID convention - the category is immediately readable from the number.

| UID Range | Category | Mirrors LXC Range |
|-----------|----------|-------------------|
| 1100–1199 | Infrastructure | 100–199 |
| 1200–1299 | IoT & monitoring | 200–299 |
| 1300–1399 | Media & storage | 300–399 |
| 1400–1499 | Game servers | 400–499 |
| 1600–1699 | Personal apps | 600–699 |

---

## Per-Service Users

These only need to exist inside their own LXC **and on the host** (required for bind mount ownership - see [lxc idmap](lxc-idmap.md)).

| UID  | User          | Service     | Primary GID    | Extra Groups | LXC         |
| ---- | ------------- | ----------- | -------------- | ------------ | ----------- |
| 1200 | `homebridge`  | Homebridge  | 1200 (`iot`)   | -            | docker-iot  |
| 1201 | `zigbee2mqtt` | Zigbee2MQTT | 1200 (`iot`)   | -            | docker-iot  |
| 1202 | `mosquitto`   | Mosquitto   | 1200 (`iot`)   | -            | docker-iot  |
| 1210 | `ultrafeeder` | Ultrafeeder | 1210 (`ultrafeeder`) | -        | ultrafeeder |
| 1300 | `sonarr`      | Sonarr      | 1300 (`media`) | -            | CT 300 (media-arr) |
| 1301 | `radarr`      | Radarr      | 1300 (`media`) | -            | CT 300 (media-arr) |
| 1302 | `prowlarr`    | Prowlarr    | 1300 (`media`) | -            | CT 300 (media-arr) |
| 1303 | `bazarr`      | Bazarr      | 1300 (`media`) | -            | CT 300 (media-arr) |
| 1304 | `seerr`       | Seerr       | 1300 (`media`) | -            | CT 300 (media-arr) - UID unused, see [exceptions](service-uid-exceptions.md) |
| 1305 | `unpackerr`   | Unpackerr   | 1300 (`media`) | -            | CT 300 (media-arr) |
| 1306 | `recyclarr`   | Recyclarr   | 1300 (`media`) | -            | CT 300 (media-arr) |
| 1307 | `dispatcharr` | Dispatcharr | 1300 (`media`) | -            | CT 300 (media-arr) - UID unused, see [exceptions](service-uid-exceptions.md) |
| 1308 | `flaresolverr` | FlareSolverr | 1300 (`media`) | -           | CT 300 (media-arr) - UID unused, see [exceptions](service-uid-exceptions.md) |
| 1310 | `jellyfin`    | Jellyfin    | 1300 (`media`) | -            | CT 301 (media-server) |
| 1311 | `jellystat`   | Jellystat   | 1300 (`media`) | -            | CT 301 (media-server) - named volume, no bind mount, see [exceptions](service-uid-exceptions.md) |
| 1320 | `qbittorrent` | qBittorrent | 1300 (`media`) | -            | CT 302 (media-dl)  |
| 1321 | `sabnzbd`     | SABnzbd     | 1300 (`media`) | -            | CT 302 (media-dl)  |
| 1330 | `suwayomi`    | Suwayomi    | 1300 (`media`) | -            | CT 303 (media-read) - UID unused, see [exceptions](service-uid-exceptions.md) |
| 1331 | `komga`       | Komga       | 1300 (`media`) | -            | CT 303 (media-read) |
| 1332 | `komf`        | Komf        | 1300 (`media`) | -            | CT 303 (media-read) |
| 1001 | `actual-budget` | Actual Budget | private (1001)         | -          | CT 600 (personal-apps) - UID hardcoded in image, see [exceptions](service-uid-exceptions.md) |
| 1600 | `grimmory`      | Grimmory      | 1600 (`personal-apps`) | 1300 (`media`) | CT 600 (personal-apps) |
| 1601 | `grocy`         | Grocy         | 1600 (`personal-apps`) | -          | CT 600 (personal-apps) |
| 1602 | `mealie`        | Mealie        | 1600 (`personal-apps`) | -          | CT 600 (personal-apps) - reserved, unused, see [exceptions](service-uid-exceptions.md) |
| 1603 | `freshrss`      | FreshRSS      | 1600 (`personal-apps`) | -          | CT 600 (personal-apps) - reserved, unused, see [exceptions](service-uid-exceptions.md) |

> Zigbee USB dongle access: the device is owned by group `iot` (GID 1200) via the Proxmox `dev0` config (`gid=1200`). zigbee2mqtt accesses it through its primary `iot` group membership - no `dialout` needed. See [lxc idmap](lxc-idmap.md) for why `dialout` (GID 20) cannot be used in an unprivileged LXC.

Create a service user (run on host and inside the LXC):
```bash
useradd -u <UID> -g <primary-group> -s /bin/false -d /nonexistent <name>
```

---

## Adding a New Service

1. Pick the next available UID in the correct range (check the table above)
2. Decide which shared group it needs - check the GIDs table above and add a new entry if a new domain is needed (current: iot=1200, media=1300, gaming=1400)
3. Add a row to the table above
4. Create the user on the **host** (required for bind mount ownership)
5. Create the user inside the target LXC
6. Create the $DATA_ROOT config directory with correct ownership (see [data layout](data-layout.md))
7. Set `PUID`/`PGID` in the service's docker-compose entry
8. Update [data layout](data-layout.md) with the new bind mount

---

## Management LXC - Exception

Komodo Core and Traefik run as root (Docker socket access and port 80/443 binding). The management LXC does not use the per-service user pattern.

What you control at the OS level:
- Create an `admin` system user for SSH access
- Add `admin` to the `docker` group for CLI access without sudo

---

## $DATA_ROOT Directory Permissions Reference

| Path | Owner (UID:GID) | Mode | Who can access |
|------|-----------------|------|----------------|
| `$DATA_ROOT/config/iot/` | `100000:1200` | 750 | container root + iot group traversal |
| `$DATA_ROOT/config/iot/homebridge/` | `1200:1200` | 750 | homebridge only |
| `$DATA_ROOT/config/iot/zigbee2mqtt/` | `1201:1200` | 750 | zigbee2mqtt only |
| `$DATA_ROOT/config/iot/mosquitto/` | `1202:1200` | 750 | mosquitto only |
| `$DATA_ROOT/media-stack/media/movies/` | `root:1300` | 775 | all media group members |
| `$DATA_ROOT/media-stack/media/movies-4k/` | `root:1300` | 775 | all media group members |
| `$DATA_ROOT/media-stack/media/tv/` | `root:1300` | 775 | all media group members |
| `$DATA_ROOT/media-stack/media/anime/` | `root:1300` | 775 | all media group members |
| `$DATA_ROOT/media-stack/media/library/` | `root:1300` | 775 | all media group members + grimmory (supplementary media group) |
| `$DATA_ROOT/media-stack/media/library/books/` | `root:1300` | 775 | all media group members |
| `$DATA_ROOT/media-stack/media/library/comics/` | `root:1300` | 775 | all media group members |
| `$DATA_ROOT/media-stack/media/library/manga/` | `root:1300` | 775 | all media group members |
| `$DATA_ROOT/media-stack/torrents/` | `root:1300` | 775 | all media group members |
| `$DATA_ROOT/config/media-arr/sonarr/` | `1300:1300` | 750 | sonarr only |
| `$DATA_ROOT/config/media-arr/radarr/` | `1301:1300` | 750 | radarr only |
| `$DATA_ROOT/config/media-arr/prowlarr/` | `1302:1300` | 750 | prowlarr only |
| `$DATA_ROOT/config/media-arr/bazarr/` | `1303:1300` | 750 | bazarr only |
| `$DATA_ROOT/config/media-arr/seerr/` | `1000:1000` | 750 | seerr (node user, UID 1000 - ignores PUID/PGID) |
| `$DATA_ROOT/config/media-arr/recyclarr/` | `1306:1300` | 750 | recyclarr only |
| `$DATA_ROOT/config/media-arr/dispatcharr/` | `100000:100000` | 750 | dispatcharr (aio image, container-root - ignores PUID/PGID) |
| `$DATA_ROOT/config/media-server/` | `100000:1300` | 750 | container root traversal + media group |
| `$DATA_ROOT/config/media-server/jellyfin/` | `1310:1300` | 750 | jellyfin only |
| `$DATA_ROOT/config/media-dl/sabnzbd/` | `1321:1300` | 750 | sabnzbd only |
| `$DATA_ROOT/config/media-dl/qbittorrent/` | `1320:1300` | 750 | qbittorrent only |
| `$DATA_ROOT/config/media-read/` | `100000:1300` | 750 | container root traversal + media group |
| `$DATA_ROOT/config/media-read/suwayomi/` | `1000:1300` | 750 | suwayomi (hardcoded UID 1000, see exceptions) |
| `$DATA_ROOT/config/media-read/komga/` | `1331:1300` | 750 | komga only |
| `$DATA_ROOT/config/media-read/komf/` | `1332:1300` | 750 | komf only |
| `$DATA_ROOT/config/personal-apps/actual-budget/` | `1001:1001` | 750 | actual-budget (hardcoded UID 1001) |
| `$DATA_ROOT/config/personal-apps/mealie/` | `100911:100911` | 750 | mealie (internal mealie user UID 911 → host 100911) |
| `$DATA_ROOT/config/personal-apps/grocy/` | `1601:1600` | 750 | grocy only |
| `$DATA_ROOT/config/personal-apps/freshrss/` | `100033:100033` | 750 | freshrss (www-data UID 33 → host 100033) |

---

## Key Takeaways

- GIDs for shared groups must match on the host and in every LXC that shares the same $DATA_ROOT folder
- UID ranges mirror LXC ID ranges - 1200s = IoT, 1300s = media, etc.
- Service users must be created on the **host** as well as inside the LXC - bind mount ownership requires it
- Some images ignore PUID/PGID entirely (Seerr, Dispatcharr, Actual Budget, FreshRSS) - see [service UID exceptions](service-uid-exceptions.md) for the correct host-side ownership for each
- See [lxc idmap](lxc-idmap.md) before creating any LXC with service-owned bind mounts
