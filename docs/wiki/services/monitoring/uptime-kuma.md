---
title: Uptime Kuma
updated: 2026-08-05
---

# Uptime Kuma

LXC: [monitoring](../../lxcs/monitoring.md) (CT 202) - uptime and service health monitoring.

## Instance

| Setting | Value |
|---------|-------|
| Port | 3001 |
| Config | `/data/uptime-kuma/` |
| URL | `https://kuma.home.example.com:<admin-port>` |
| Managed as | Komodo stack `monitoring` |

## Monitors

21 HTTP monitors covering: Traefik, Komodo, Glance, Pi-hole, FileBrowser, Grafana, Prometheus, Sonarr, Radarr, Prowlarr, Bazarr, Seerr, Dispatcharr, Jellystat, Jellyfin, Ultrafeeder, Piaware, FR24, Zigbee2MQTT, Homebridge, Actual Budget.

Bulk import file: `stacks/monitoring/uptime-kuma-monitors.json`

## DNS Requirement

Uptime Kuma must resolve `*.home.example.com` - add a DNS override in the compose file:

```yaml
services:
  uptime-kuma:
    dns:
      - <pihole-ip>
```

Without this, DNS fails because the container runs on CT 202 which gets DNS from the host resolver, not Pi-hole.

## Traefik Dashboard Monitor

Monitor URL: `https://traefik.home.example.com:<admin-port>/dashboard/`

The trailing slash is required - `/dashboard` without the slash returns 301, and Uptime Kuma may flag the redirect as a failure depending on its follow-redirect setting.

## Notifications

Configure in **Settings → Notifications**. Kuma supports many providers (Telegram, Pushover, email, webhooks, and more). Once a notification provider is saved, assign it to individual monitors from each monitor's edit screen.

Each monitor can have multiple notification providers assigned. Notifications fire on status change (up → down and down → up).

## Settings

- Primary Base URL: `https://kuma.home.example.com:<admin-port>` - used in notification links
