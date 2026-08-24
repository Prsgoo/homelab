---
title: Homebridge
updated: 2026-08-05
---

# Homebridge

LXC: [iot](../../lxcs/iot.md) (CT 201) - Apple HomeKit bridge for non-native smart home devices.

## Instance

| Setting | Value |
|---------|-------|
| Port (UI) | 8581 |
| Port (HAP) | 51380 |
| Config | `/data/homebridge/` |
| UID/GID | 1200:1200 |
| Network mode | `host` |
| URL | `https://homebridge.home.example.com:<admin-port>` |
| Managed as | Komodo stack `iot` |

`network_mode: host` is required - mDNS/Bonjour announcements don't cross Docker bridge networks. All other iot services are on the default bridge and reach Homebridge's services via localhost.

## Mosquitto Integration

Homebridge reaches Mosquitto at `mqtt://localhost:1883` (host network shares the port). No Docker network alias needed.
