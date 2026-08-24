---
title: Pterodactyl Wings
updated: 2026-08-05
---

# Pterodactyl Wings

LXC: [minecraft wings](../../lxcs/minecraft-wings.md) (CT 401) - Pterodactyl node daemon. Manages Minecraft server containers.

## Instance

| Setting | Value |
|---------|-------|
| Daemon port | 8080 |
| SFTP port | 2022 |
| Config dir | `/etc/pterodactyl/` (symlink → `/data/pterodactyl/`) |
| Volumes | `$DATA_ROOT/minecraft/volumes/` (bind-mounted) |
| Tailscale IP | `<wings-ts-ip>` |
| Not managed by Komodo | (Wings starts Minecraft containers; Komodo would conflict) |

## Panel Setup

Node settings in the Pterodactyl Panel:

| Setting | Value |
|---------|-------|
| FQDN | `<wings-ts-ip>` (Tailscale IP) |
| SSL | Off |
| Daemon port | 8080 |
| SFTP port | 2022 |

Use the Tailscale IP as FQDN - makes the node reachable to friends on the Tailscale network without port-forwarding.

## Wings Configuration

After setting up the node in the Panel:

```bash
wings configure --panel-url https://game-panel.home.example.com --token <node-token> --node <node-id>
```

This writes `/etc/pterodactyl/config.yml`.

## CORS

In `config.yml`, add allowed origins:

```yaml
allowed_origins:
  - https://game-panel.home.example.com
  - http://<panel-ip>
  - http://<panel-ts-ip>
```

Without the panel's origin in `allowed_origins`, the console websocket is blocked by the browser.

## Systemd Startup Fix

Wings must wait for Tailscale before starting (it binds to the Tailscale IP):

```ini
[Unit]
After=network.target tailscaled.service

[Service]
ExecStartPre=/bin/sleep 10
```

Without the delay, Wings starts before Tailscale assigns the IP and crashes.

## Public Access Options

| Option | Notes |
|--------|-------|
| Friends with Tailscale | Share `tag:minecraft` via Tailscale invite - zero port-forward required |
| Port-forward router | Expose ports 8080 + 2022 + game ports - works but requires ISP with open ports |
| Cloudflare Tunnel | TCP proxying; high latency for game traffic - not recommended |

## Key Takeaways

- CT 401 `onboot = no` - start manually; Minecraft servers are on-demand
- Wings FQDN must be the Tailscale IP so friends can connect without a public IP
- CORS `allowed_origins` must include the Panel URL or browser console breaks
- The systemd sleep delay is required - Wings crashes if Tailscale isn't up yet
