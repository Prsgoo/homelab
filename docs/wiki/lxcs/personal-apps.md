---
title: Personal Apps LXC (CT 600)
updated: 2026-09-13
---

# Personal Apps LXC (CT 600)

Personal tools. All services are admin-only - not shared with other users.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 600 |
| Hostname | personal-apps |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 4096MB |
| Cores | 2 |
| IP | <personal-apps-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT/config/personal-apps` | `/data` |
| mp1 | `$DATA_ROOT/media-stack/media/books` | `/books` |

## UID Scheme

CT 600 uses the 1600–1699 range per the [UID/GID standards](../standards/user-group-scheme.md).

| UID/GID | User | Group | Used by |
|---------|------|-------|---------|
| 1600 | grimmory | personal-apps | Grimmory app + MariaDB |

## idmap

```
lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 700
lxc.idmap: u 1700 101700 63836
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 700
lxc.idmap: g 1700 101700 63836
```

Container UIDs 1000–1699 map 1:1 to host UIDs 1000–1699.

Also requires in `/etc/subuid` and `/etc/subgid` on the Proxmox host:
```
root:1000:700
```

## Komodo

| Setting | Value |
|---------|-------|
| Server | personal-apps |
| Address | `wss://<personal-apps-ip>:8120` |
| Root directory | `/data/komodo` |

## Services

→ [personal apps](../services/personal-apps/_index.md) - Actual Budget, Mealie, FreshRSS, Grimmory
