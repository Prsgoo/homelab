---
title: Personal Apps LXC (CT 600)
updated: 2026-08-05
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
| RAM | 2048MB |
| Cores | 2 |
| IP | <personal-apps-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT/config/personal-apps` | `/data` |

## idmap

```
lxc.idmap: u 0 100000 1000
lxc.idmap: u 1000 1000 500
lxc.idmap: u 1500 101500 64036
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 1000 500
lxc.idmap: g 1500 101500 64036
```

Container UIDs 1000–1499 map 1:1 to host UIDs 1000–1499.

## Komodo

| Setting | Value |
|---------|-------|
| Server | personal-apps |
| Address | `wss://<personal-apps-ip>:8120` |
| Root directory | `/data/komodo` |

Note: Periphery connection may be refused - verify Periphery is installed before expecting Komodo connectivity.

## Services

→ [personal apps](../services/personal-apps/_index.md) - Actual Budget
