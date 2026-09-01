---
title: Traefik
updated: 2026-08-05
---

# Traefik

LXC: [management lxc](../../lxcs/management-lxc.md) (CT 100) - reverse proxy for all internal services.
See [internal https](../../infrastructure/internal-https.md) for the HTTPS/cert architecture and entrypoint design.

## Instance

| Setting | Value |
|---------|-------|
| Version | v3 |
| Dashboard | `https://traefik.home.example.com/dashboard/` (trailing slash required) |
| Static config | `/data/config/management/traefik/traefik.yml` |
| Dynamic config dir | `/data/config/management/traefik/config/` (hot-reloaded) |
| ACME storage | `/data/config/management/traefik/acme/acme.json` (must be `600`) |
| Managed as | Komodo stack `traefik` |

## Entrypoints

| Name | Port | Purpose |
|------|------|---------|
| `web` | `:80` | HTTP (unused - no services on HTTP) |
| `websecure` | `:443` | User-facing services |
| `admin` | `:<admin-port>` | Admin tools - restricted to `tag:admin` via Tailscale ACL |

## Active Routes

**User-facing (`:443`)** - accessible to all Tailscale tags:

| Domain | Backend | Service |
|--------|---------|---------|
| `glance.home.example.com` | :8081 | Glance |
| `seerr.home.example.com` | <media-arr-ip>:5055 | Seerr |
| `jellyfin.home.example.com` | <media-server-ip>:8096 | Jellyfin |
| `game-panel.home.example.com` | <panel-ip>:80 | Pterodactyl Panel |

**Admin-only (`:<admin-port>`)** - `admin-only` middleware applied:

| Domain | Backend | Service |
|--------|---------|---------|
| `traefik.home.example.com:<admin-port>` | :8080 | Traefik dashboard |
| `komodo.home.example.com:<admin-port>` | :9120 | Komodo UI |
| `pihole.home.example.com:<admin-port>` | <pihole-ip>:80 | Pi-hole admin |
| `files.home.example.com:<admin-port>` | :8082 | FileBrowser |
| `grafana.home.example.com:<admin-port>` | <monitoring-ip>:3000 | Grafana |
| `prometheus.home.example.com:<admin-port>` | <monitoring-ip>:9090 | Prometheus |
| `kuma.home.example.com:<admin-port>` | <monitoring-ip>:3001 | Uptime Kuma |
| `sonarr.home.example.com:<admin-port>` | <media-arr-ip>:8989 | Sonarr |
| `radarr.home.example.com:<admin-port>` | <media-arr-ip>:7878 | Radarr |
| `prowlarr.home.example.com:<admin-port>` | <media-arr-ip>:9696 | Prowlarr |
| `bazarr.home.example.com:<admin-port>` | <media-arr-ip>:6767 | Bazarr |
| `dispatcharr.home.example.com:<admin-port>` | <media-arr-ip>:9191 | Dispatcharr |
| `jellystat.home.example.com:<admin-port>` | <media-server-ip>:3000 | Jellystat |
| `downloads.home.example.com:<admin-port>` | <media-dl-ip>:8080 | qBittorrent |
| `sabnzbd.home.example.com:<admin-port>` | <media-dl-ip>:8085 | SABnzbd |
| `adsb.home.example.com:<admin-port>` | <ultrafeeder-ip>:8080 | Ultrafeeder/tar1090 |
| `piaware.home.example.com:<admin-port>` | <ultrafeeder-ip>:8081 | Piaware |
| `fr24.home.example.com:<admin-port>` | <ultrafeeder-ip>:8754 | FlightRadar24 |
| `zigbee.home.example.com:<admin-port>` | <iot-ip>:8080 | Zigbee2MQTT |
| `homebridge.home.example.com:<admin-port>` | <iot-ip>:8581 | Homebridge |
| `budget.home.example.com:<admin-port>` | <personal-apps-ip>:5006 | Actual Budget |
| `mealie.home.example.com:<admin-port>` | <personal-apps-ip>:9000 | Mealie |
| `freshrss.home.example.com:<admin-port>` | <personal-apps-ip>:8080 | FreshRSS |

Route files live in `/data/config/management/traefik/config/`. Traefik hot-reloads on file change - no restart needed.

## Docker Configuration Note

`userland-proxy: false` is required in `/etc/docker/daemon.json` on CT 100. Without it Docker NATs all connections to the bridge gateway, masking real client IPs and breaking `ipAllowList` middleware.

## Adding a New Route

Create `/data/config/management/traefik/config/<service>.yml` on CT 100. Use:
- `websecure` entrypoint + `tls: {}` for user-facing services
- `admin` entrypoint + `admin-only` middleware for admin tools

No DNS or cert changes needed - the wildcard cert covers all `*.home.example.com` subdomains automatically.

## Key Takeaways

- Trailing slash required on dashboard URL - bare root returns 404
- File-based routing only - no Docker label auto-discovery across LXCs
- `userland-proxy: false` must remain in daemon.json or `ipAllowList` breaks
- Route files hot-reload - no Traefik restart needed after adding/editing a route file
