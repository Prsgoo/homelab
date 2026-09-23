---
title: Service UID Exceptions
updated: 2026-09-13
---

# Service UID Exceptions

Most services follow the [UID/GID scheme](user-group-scheme.md): a reserved UID in the correct range, PUID/PGID env vars, bind mount owned by that UID on the host. The services below deviate from this pattern because their images hardcode an internal user or ignore PUID/PGID entirely.

---

## Seerr - node (1000:1000)

**Why:** The Seerr image is a Node.js app that runs as the built-in `node` user (UID 1000). It does not read PUID/PGID.

**UID 1304** is reserved in the scheme but unused.

**Host-side ownership:**

Container UID 1000 maps through the media-arr idmap. Under the default idmap (UIDs 0–999 → 100000+), UID 1000 maps to host UID 101000. Check your specific idmap config for the exact offset.

**What to set:**
- No PUID/PGID in compose
- Pre-create config dir with the correct mapped UID on the host

---

## Dispatcharr - root

**Why:** The AIO image (`DISPATCHARR_ENV=aio`) bundles backend, frontend, and EPG processor in a single container and runs the whole stack as root. PUID/PGID are ignored.

**UID 1308** is reserved in the scheme but unused.

**Host-side ownership:**
```bash
# Runs as container root (UID 0) → remapped by idmap
chown -R <remapped-root-uid>:<remapped-root-gid> $DATA_ROOT/config/media-arr/dispatcharr/
```

**What to set:**
- No PUID/PGID in compose
- Config dir owned by the host UID that container root maps to

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

UID 33 falls in the default remapped range. Under a typical unprivileged LXC idmap, container UID 33 → host UID 100033.

```bash
chown -R 100033:100033 $DATA_ROOT/config/personal-apps/freshrss/
```

**What to set:**
- No PUID/PGID in compose
- Config dir owned `100033:100033` on host (verify against your idmap)

---

## Mealie - root (0:0 in container, remapped on host)

**Why:** The official Mealie image (`ghcr.io/mealie-recipes/mealie`) has broken PUID/PGID support - the `change_user` function was disabled and the container runs as root (UID 0) regardless of env vars set. (Upstream issue #2845, fix merged in #2882 but reliability uncertain - do not rely on it.)

**UID 1602** is reserved in the scheme but unused.

**Host-side ownership:**
```bash
# CT 600 (personal-apps) - UID 0 inside LXC → remapped by idmap (typically host UID 100000)
chown -R <remapped-root-uid>:<remapped-root-gid> $DATA_ROOT/config/personal-apps/mealie/
```

**What to set:**
- No PUID/PGID in compose
- Config dir owned by the host UID that container root maps to

---

## Jellystat - named volume

**Why:** Jellystat stores its database in a named Docker volume rather than a bind mount. UID 1311 is reserved in the scheme but there is no host-side directory to own.

**Implication:** The data survives container restarts but not rootfs recreation. If the LXC is rebuilt from scratch, the named volume is lost. Back up before any rootfs changes:

```bash
docker exec jellystat-db pg_dump -U jellystat jellystat > jellystat-backup.sql
```

---

## Management LXC - root

Komodo Core and Traefik run as root (Docker socket access, ports 80/443). The management LXC does not use the per-service user pattern at all. See [user/group scheme](user-group-scheme.md) for context.
