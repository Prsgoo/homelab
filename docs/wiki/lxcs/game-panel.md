---
title: Game Panel LXC (CT 400)
updated: 2026-08-05
---

# Game Panel LXC (CT 400)

Pterodactyl Panel - web frontend for managing game server nodes. Native install (no Docker).

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 400 |
| Hostname | game-panel |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 1024MB |
| Swap | 512MB |
| Cores | 2 |
| IP | <panel-ip> |
| onboot | no |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

onboot is disabled - start manually when game servers are needed.

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT/config/panel` | `/data` |

## idmap

Not required - Pterodactyl Panel uses system users (www-data, mysql) without the 1000–1499 service UID scheme.

## Bind Mount Ownership

CT 400 uses no idmap, so host UID = container UID + 100000.

| Path (host) | Owner (host) | Mode | Notes |
|-------------|-------------|------|-------|
| `$DATA_ROOT/config/panel/` | `100000:100000` | 755 | Container root; 755 lets www-data traverse |
| `$DATA_ROOT/config/panel/.env` | `100000:100033` | 640 | www-data (UID 33 → host 100033) needs read |
| `$DATA_ROOT/config/panel/storage/` | `100033:100033` | 775 | www-data owns and writes here |
| `$DATA_ROOT/config/panel/mysql/` | `100999:100999` | 755 | MariaDB (UID 999 → host 100999) |

## Komodo

Binary Periphery only (no Docker on this LXC). Pterodactyl is not managed via Komodo stacks.

| Setting | Value |
|---------|-------|
| Server | game-panel |
| Address | `wss://<panel-ip>:8120` |

## Tailscale

| Setting | Value |
|---------|-------|
| Tailscale IP | <panel-ts-ip> |
| Flags | `--accept-routes=false --accept-dns=false` |

TUN device entry in `/etc/pve/lxc/400.conf`:
```
dev0: /dev/net/tun,gid=0,uid=0
```

## Services

→ [game panel](../services/game-panel/_index.md) - Pterodactyl Panel
