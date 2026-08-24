---
title: Mosquitto
updated: 2026-08-05
---

# Mosquitto

LXC: [iot](../../lxcs/iot.md) (CT 201) - MQTT broker used by Homebridge and Zigbee2MQTT.

## Instance

| Setting | Value |
|---------|-------|
| Port (MQTT) | 1883 |
| Port (WebSocket) | 9002 |
| Config | `/data/mosquitto/` |
| UID/GID | 1202:1202 |
| Managed as | Komodo stack `iot` |

No authentication configured - broker is LAN-internal only. Homebridge reaches it on localhost (host network), Zigbee2MQTT reaches it by container name on the Docker bridge.
