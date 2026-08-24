---
title: Minecraft Wings LXC (CT 401)
updated: 2026-08-05
---

# Minecraft Wings LXC (CT 401)

Pterodactyl Wings node - runs Minecraft game server containers. Managed by game-panel (CT 400), not by Komodo.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 401 |
| Hostname | minecraft-wings |
| Template | Debian 13 standard |
| rootfs | 16GB |
| RAM | 20480MB |
| Cores | 6 |
| IP | <wings-ip> |
| onboot | no |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

20GB RAM: Wings daemon (~500MB) + modded server allocations (12–14GB each). Adjust with `pct set 401 -memory <MB>` while stopped.

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT/config/minecraft-wings` | `/data` |
| mp1 | `$DATA_ROOT/minecraft/volumes` | `/var/lib/pterodactyl/volumes` |
| mp2 | `$DATA_ROOT/minecraft/backups` | `/var/lib/pterodactyl/backups` |

Game world data is on the minecraft pool (mp1, mp2) - survives rootfs loss.

## idmap

Not required - Wings and Docker game containers run as root.

## Bind Mount Ownership

Wings runs as root - bind mount root needs host UID 100000 access:

```bash
chown 100000:100000 $DATA_ROOT/config/minecraft-wings
chmod 755 $DATA_ROOT/config/minecraft-wings
chown 100000:100000 $DATA_ROOT/minecraft/volumes
chmod 755 $DATA_ROOT/minecraft/volumes
```

## Komodo

Not registered. Game server containers are managed exclusively by Pterodactyl Wings → game-panel. Do not add Komodo Periphery here.

## Tailscale

Wings uses its Tailscale IP as the node FQDN - friends with Tailscale access reach game ports directly.

| Setting | Value |
|---------|-------|
| Tailscale IP | <wings-ts-ip> |
| Flags | `--accept-routes=false --accept-dns=false` |

TUN device entry in `/etc/pve/lxc/401.conf`:
```
dev0: /dev/net/tun,gid=0,uid=0
```

## Services

→ [minecraft wings](../services/minecraft-wings/_index.md) - Pterodactyl Wings
