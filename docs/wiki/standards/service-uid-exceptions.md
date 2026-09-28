---
title: Service UID Exceptions
updated: 2026-09-13
---

# Service UID Exceptions

Most services follow the [UID/GID scheme](user-group-scheme.md): a reserved UID in the correct range, PUID/PGID env vars, bind mount owned by that UID on the host. The services below deviate from this pattern because their images hardcode an internal user or ignore PUID/PGID entirely.

---

## Suwayomi - suwayomi user (1000:1000)

**Why:** The Suwayomi image hardcodes an internal `suwayomi` user at UID 1000. It does not support PUID/PGID.

**UID 1330** is reserved in the scheme but unused.

**Host-side ownership:**
```bash
# CT 303 (media-read) - UID 1000 falls in the 1:1 passthrough range (1000–1499), so host UID = 1000
# GID 1300 (media) is needed for write access to /manga
chown -R 1000:1300 $DATA_ROOT/config/media-read/suwayomi/
```

**What to set:**
- `user: "1000:1300"` in compose - overrides GID to media group so Suwayomi can write to `/manga`
- Config dir owned `1000:1300` on host
- After first boot, set download path to `/manga` in Suwayomi Settings > Downloads

---

## Seerr - node (1000:1000)

**Why:** The Seerr image is a Node.js app that runs as the built-in `node` user (UID 1000). It does not read PUID/PGID.

**UID 1304** is reserved in the scheme but unused.

**Host-side ownership:**
```bash
# CT 300 media-arr - UID 1000 falls in the 1:1 passthrough range (1000–1499), so host UID = 1000
chown -R 1000:1000 $DATA_ROOT/config/media-arr/seerr/
```

**What to set:**
- No PUID/PGID in compose
- Pre-create config dir owned `1000:1000` on host

---

## Dispatcharr - root

**Why:** The AIO image (`DISPATCHARR_ENV=aio`) bundles backend, frontend, and EPG processor in a single container and runs the whole stack as root. PUID/PGID are ignored.

**UID 1307** is reserved in the scheme but unused.

**Host-side ownership:**
```bash
# Runs as container root (UID 0) → host UID 100000 via idmap
chown -R 100000:100000 $DATA_ROOT/config/media-arr/dispatcharr/
```

**What to set:**
- No PUID/PGID in compose
- Config dir owned `100000:100000` on host

---

## Actual Budget - actual (1001:1001)

**Why:** The Actual Budget image hardcodes an internal `actual` user at UID 1001. It does not support PUID/PGID. The UID falls outside both the media range (1300s) and the personal-apps range (1600s).

**Host-side ownership:**

CT 600 (personal-apps) has an idmap that passes UIDs 1000–1699 through 1:1 to the host. So container UID 1001 = host UID 1001.

```bash
chown -R 1001:1001 $DATA_ROOT/config/personal-apps/actual-budget/
```

**What to set:**
- No PUID/PGID in compose
- Config dir owned `1001:1001` on host

---

## FreshRSS - www-data (33:33)

**Why:** The FreshRSS image runs as `www-data` (UID 33), a standard web server user. No PUID/PGID support.

**Host-side ownership:**

CT 600 uses the same 1:1 passthrough idmap for UIDs 1000–1699, but UID 33 falls in the default remapped range (0–999 → 100000+). Container UID 33 → host UID 100033.

```bash
chown -R 100033:100033 $DATA_ROOT/config/personal-apps/freshrss/
```

**What to set:**
- No PUID/PGID in compose
- Config dir owned `100033:100033` on host

---

## Mealie - mealie user (911:911)

**Why:** The official Mealie image (`ghcr.io/mealie-recipes/mealie`) runs as an internal `mealie` user at UID 911. It does not support PUID/PGID. The UID falls outside both the media range (1300s) and the personal-apps range (1600s).

**UID 1602** is reserved in the scheme but unused.

**Host-side ownership:**
```bash
# CT 600 (personal-apps) - UID 911 falls in the 0-999 range → host UID 100911 via idmap
chown -R 100911:100911 $DATA_ROOT/config/personal-apps/mealie/
```

**What to set:**
- No PUID/PGID in compose
- Config dir owned `100911:100911` on host

---

## FlareSolverr - stateless (no config mount)

**Why:** FlareSolverr is a stateless Cloudflare bypass proxy. It has no PUID/PGID support and requires no persistent config directory - there is nothing to bind-mount.

**UID 1308** is reserved in the scheme but unused.

**What to set:**
- No PUID/PGID in compose
- No config bind mount; no host-side directory to chown
- UID 1308 system user is still created on the host and inside CT 300 for normalization

---

## Jellystat - named volume

**Why:** Jellystat stores its database in a named Docker volume rather than a bind mount. UID 1311 is reserved in the scheme but there is no host-side directory to own.

**Implication:** The data survives container restarts but not rootfs recreation. If CT 301 is rebuilt from scratch, the named volume is lost. Back up before any rootfs changes:

```bash
docker exec jellystat-db pg_dump -U jellystat jellystat > jellystat-backup.sql
```

---

## Management LXC - root

Komodo Core and Traefik run as root (Docker socket access, ports 80/443). CT 100 does not use the per-service user pattern at all. See [user/group scheme](user-group-scheme.md) for context.
