---
title: Ultrafeeder LXC (CT 200)
updated: 2026-08-05
---

# Ultrafeeder LXC (CT 200)

ADS-B receiver. Runs the ultrafeeder Docker stack with an RTL-SDR USB dongle for flight tracking.

## Specs

| Setting | Value |
|---------|-------|
| CT ID | 200 |
| Hostname | ultrafeeder |
| Template | Debian 13 standard |
| rootfs | 8GB |
| RAM | 2048MB |
| Cores | 2 |
| IP | <ultrafeeder-ip> |
| onboot | yes |
| Unprivileged | yes |
| Features | nesting=1, keyctl=1 |

## Bind Mounts

| Mount | Host Path | Container Path |
|-------|-----------|---------------|
| mp0 | `$DATA_ROOT/config/ultrafeeder` | `/data` |

## idmap

Not required - Docker services use default UIDs; no bind-mounted config paths require specific ownership.

## Device Passthrough (RTL-SDR)

The RTL-SDR USB dongle is passed through via cgroup rules in `/etc/pve/lxc/200.conf`:

```
lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/bus/usb dev/bus/usb none bind,optional,create=dir
```

This passes the entire `/dev/bus/usb` directory (needed for USB device enumeration). The Docker compose then adds `device_cgroup_rules: 'c 189:* rwm'` to the container.

The USB bus path (`/dev/bus/usb/XXX/YYY`) changes if the USB hub is replugged - the LXC config doesn't need updating since it mounts the whole bus directory, but the Docker compose may need the serial number updated.

## Komodo

| Setting | Value |
|---------|-------|
| Server | ultrafeeder |
| Address | `wss://<ultrafeeder-ip>:8120` |
| Root directory | `/data/komodo` |

After any Periphery restart, Komodo requires manual key-trust in Servers → ultrafeeder.

## Services

→ [ultrafeeder](../services/ultrafeeder/_index.md) - Ultrafeeder, Piaware, FR24, OpenSky
