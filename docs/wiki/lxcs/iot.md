---
title: IoT LXC (CT 201)
updated: 2026-08-05
---

# IoT LXC (CT 201)

Smart home hub. Runs Homebridge, Zigbee2MQTT, and Mosquitto via Docker.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 201 |
| Hostname | iot |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 1024MB |
| Cores | 2 |
| IP | <iot-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT/config/iot` | `/data` |

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

## UID/GID Scheme

| UID:GID | Service |
|---------|---------|
| 1200:1200 | Homebridge |
| 1201:1200 | Zigbee2MQTT |
| 1202:1200 | Mosquitto |

Pre-create bind mount subdirs and chown on the host before first start:

```bash
chown -R 1200:1200 $DATA_ROOT/config/iot/homebridge/
chown -R 1201:1200 $DATA_ROOT/config/iot/zigbee2mqtt/
chown -R 1202:1200 $DATA_ROOT/config/iot/mosquitto/
```

## Device Passthrough (Zigbee Dongle)

Zigbee USB dongle (`/dev/ttyUSB0`) passed via Proxmox native `dev` config in `/etc/pve/lxc/201.conf`:

```
dev0: /dev/ttyUSB0,gid=1200,uid=0
```

Use `dev0` - not `lxc.cgroup2.devices.allow + lxc.mount.entry`. The manual cgroup approach does not properly register character devices in the allowlist, causing permission denied even for root inside the LXC.

## Networking

Homebridge uses `network_mode: host` (required for mDNS/Bonjour). Zigbee2MQTT and Mosquitto use the Docker bridge and reach each other by container name.

## Komodo

| Setting | Value |
|---------|-------|
| Server | iot |
| Address | `wss://<iot-ip>:8120` |
| Root directory | `/data/komodo` |

## Services

→ [iot](../services/iot/_index.md) - Homebridge, Zigbee2MQTT, Mosquitto
