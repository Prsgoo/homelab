---
title: Zigbee2MQTT
updated: 2026-08-05
---

# Zigbee2MQTT

LXC: [iot](../../lxcs/iot.md) (CT 201) - Zigbee coordinator bridge that exposes Zigbee devices to Home Assistant or MQTT clients.

## Instance

| Setting | Value |
|---------|-------|
| Port | 8080 |
| Config | `/data/zigbee2mqtt/` |
| UID/GID | 1201:1201 |
| Device | `/dev/ttyUSB0` (Zigbee dongle) |
| URL | `https://zigbee.home.example.com:<admin-port>` |
| Managed as | Komodo stack `iot` |

## Device Passthrough

The Zigbee USB dongle is passed through via the `dev0` device entry in CT 201's config (cgroup allow + mount entry). See [iot](../../lxcs/iot.md) for the exact config block.

## Mosquitto Connection

```yaml
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mqtt  # Docker container name
```

Zigbee2MQTT connects to Mosquitto via the Docker bridge network using the container name `mqtt`.

## Network Note

Zigbee2MQTT is on the Docker bridge (not `network_mode: host`). It reaches Mosquitto by container name; Homebridge on host network reaches Mosquitto on localhost. Both work - they hit the same Mosquitto instance.

## Key Takeaways

- Zigbee network key is stored in `/data/zigbee2mqtt/configuration.yaml` - back this file up before re-pairing devices
- `permit_join` defaults to `false`; enable in the UI to add new devices
