---
title: LXCs
---

# LXCs

Container specs, bind mounts, idmap, and device passthrough. Service-level config is in [Services](../services/_index.md).

| Article | CT | Description |
|---------|----|-------------|
| [lxc inventory](lxc-inventory.md) | - | Full inventory: all containers, resources, bind mounts |
| [management lxc](management-lxc.md) | 100 | Management node - data pool + minecraft pool bind mounts |
| [pihole](pihole.md) | 101 | DNS LXC - no bind mounts (rootfs only) |
| [ultrafeeder](ultrafeeder.md) | 200 | ADS-B LXC - USB bus passthrough for RTL-SDR |
| [iot](iot.md) | 201 | IoT LXC - idmap, Zigbee dongle passthrough |
| [monitoring](monitoring.md) | 202 | Monitoring LXC - idmap, Grafana UID ownership |
| [media arr](media-arr.md) | 300 | Media management LXC - 16GB rootfs, 4 bind mounts |
| [media server](media-server.md) | 301 | Media server LXC - read-only media mount |
| [media dl](media-dl.md) | 302 | Download LXC - torrents + usenet bind mounts |
| [game panel](game-panel.md) | 400 | Game panel LXC - native install, onboot no |
| [minecraft wings](minecraft-wings.md) | 401 | Minecraft Wings LXC - minecraft pool bind mounts, onboot no |
| [personal apps](personal-apps.md) | 600 | Personal apps LXC |
