---
title: Pterodactyl Panel
updated: 2026-08-05
---

# Pterodactyl Panel

LXC: [game panel](../../lxcs/game-panel.md) (CT 400) - web frontend for managing game servers.

## Instance

| Setting | Value |
|---------|-------|
| Port | 80 (Apache) |
| Panel dir | `/opt/pterodactyl-panel/` (symlink → `/data/panel`) |
| PHP | 8.4-FPM |
| Web server | Apache2 |
| URL | `https://game-panel.home.example.com` (user-facing, `:443`) |
| Tailscale | `http://<panel-ts-ip>` |
| Managed as | Komodo Periphery binary (no Docker) |

CT 400 runs Apache + PHP directly (no Docker). Komodo manages the binary Periphery agent only.

## Database

| Setting | Value |
|---------|-------|
| Engine | MariaDB |
| Data dir | `/data/mysql/` (bind-mounted from host) |
| Ownership | `999:999` (MySQL container UID) |

## Bind Mount Ownership

| Path | Owner | Notes |
|------|-------|-------|
| `/data/panel/` | `33:33` (www-data) | Panel application files |
| `/data/mysql/` | `999:999` | MariaDB data directory |

## Permission Requirements

1. `php artisan` commands must run as `www-data` - running as root creates root-owned cache files that break the web server
2. Bind-mounted files cannot be edited with tools that use atomic rename (e.g. `sed -i`) - edit in-place
3. After reinstall: re-run `php artisan key:generate` and `php artisan p:environment:setup`
4. After composer update: run `php artisan optimize:clear` as www-data
5. `.env` must be owned `www-data:www-data` with mode `640`

## Traefik Route

`stacks/game-panel/traefik-route.yml` on CT 100.

## Key Takeaways

- Panel `artisan` commands always as `www-data`: `sudo -u www-data php artisan <cmd>`
- Database bind mount ownership is `999:999` - not the CT 400 idmap scheme
- CT 400 `onboot = no` - start manually when needed
