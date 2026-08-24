# IoT - Homebridge + Zigbee2MQTT + Mosquitto

## What you'll end up with

A single Docker LXC (CT 201) running three services: Mosquitto as the MQTT broker, Zigbee2MQTT bridging a USB Zigbee dongle to MQTT, and Homebridge exposing everything to Apple HomeKit. Zigbee devices appear in the Home app without any cloud dependency.

---

## Prerequisites

- Komodo running
- Traefik running
- A Zigbee USB dongle (e.g. Sonoff Zigbee 3.0, ConBee II) plugged into the Proxmox host

---

## 1. Identify the Zigbee dongle

On the Proxmox host:

```bash
ls /dev/ttyUSB*
# or
dmesg | grep -i usb | tail -20
```

Note the device path - typically `/dev/ttyUSB0`. If it's different, update the `dev0` entry in `ct201-iot.sh` before running it.

---

## 2. Create the LXC

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value |
|---------|-------|
| CT ID | 201 |
| Hostname | iot |
| Cores | 2 |
| RAM | 1024 MB |
| Disk | 8 GB |
| IP | <iot-ip>/24 |

---

## 3. Run the CT script

```bash
cd /opt/proxmox-admin
bash scripts/ct201-iot.sh
```

This creates service users on the host (`homebridge`, `zigbee2mqtt`, `mosquitto`, all in the `iot` group GID 1200), sets directory ownership, applies the idmap, and passes the Zigbee dongle through via a `dev0` entry:

```
dev0: /dev/ttyUSB0,gid=1200,uid=0
```

This is the correct passthrough method for LXCs - `lxc.cgroup2.devices.allow` + `lxc.mount.entry` doesn't work reliably on cgroupv2.

---

## 4. Deploy the IoT stack via Komodo

Add CT 201 as a server in Komodo (`wss://<iot-ip>:8120`), then deploy the `iot` stack. No secrets required - no `.env` file needed for this stack.

The stack starts three containers: `mosquitto`, `zigbee2mqtt`, and `homebridge`.

---

## 5. Configure Zigbee2MQTT

Open Zigbee2MQTT at `https://zigbee.home.example.com:<admin-port>`.

On first start, Zigbee2MQTT reads its config from `/data/zigbee2mqtt/configuration.yaml`. The important settings:

```yaml
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mqtt      # Docker container name for Mosquitto

serial:
  port: /dev/ttyUSB0       # must match the dev0 passthrough path

frontend:
  enabled: true
  port: 8080
```

**Pair devices:**

1. In the Zigbee2MQTT UI → **Permit join** → enable (auto-disables after 255 seconds)
2. Put your Zigbee device into pairing mode (varies by device - usually hold a button)
3. The device appears in the UI under **Devices**

!!! warning "Back up `configuration.yaml`"
    The Zigbee network key is stored in this file. If you lose it, you'll need to re-pair all devices. Back it up after initial setup.

---

## 6. Configure Homebridge

Open Homebridge at `https://homebridge.home.example.com:<admin-port>`.

Homebridge runs with `network_mode: host` - required for mDNS/Bonjour to work across the LAN so Apple Home can discover it. This means it binds to the LXC's IP directly.

**Connect to MQTT** (for Zigbee devices):

Install the `homebridge-z2m` plugin (Zigbee2MQTT integration):

1. **Plugins → Search**: `homebridge-z2m`
2. Install it, then configure the MQTT server as `localhost:1883` (Homebridge uses host network, so Mosquitto is reachable on localhost)

**Add to Apple Home:**

1. Open the Home app on iPhone/iPad
2. Tap **+** → **Add Accessory** → **More options**
3. Scan the QR code shown on the Homebridge dashboard, or enter the 8-digit pairing code

All Zigbee devices will appear as HomeKit accessories after Homebridge syncs with Zigbee2MQTT via MQTT.

---

## Day-2 operations

### Adding new Zigbee devices

Enable **Permit join** in Zigbee2MQTT UI, put the device in pairing mode. New devices appear automatically in Homebridge (with `homebridge-z2m`).

### Updating services

In Komodo UI: **Stacks → iot → Deploy**. Pulls latest images for all three services.

### Checking MQTT traffic

```bash
pct exec 201 -- docker exec -it mosquitto mosquitto_sub -t '#' -v
```

This subscribes to all MQTT topics - useful for verifying device messages are flowing.

---

## Troubleshooting

**Zigbee2MQTT can't open serial port**

1. Confirm the dongle is plugged in: `ls /dev/ttyUSB*` on the Proxmox host
2. Confirm the `dev0` entry in `/etc/pve/lxc/201.conf` matches the actual device path
3. Inside CT 201: `ls -la /dev/ttyUSB0` - should exist and be owned by GID 1200

**Homebridge not appearing in Apple Home**

Homebridge requires `network_mode: host` for mDNS. Confirm it's set in the compose. If the pairing code doesn't work, try resetting the pairing: Homebridge UI → **Settings → Reset HomeKit** → re-pair.

**Device paired in Zigbee2MQTT but not showing in Homebridge**

1. Confirm `homebridge-z2m` plugin is installed and configured with the correct MQTT server (`localhost:1883`)
2. Restart Homebridge: Homebridge UI → **Restart**
3. Check the Homebridge logs for plugin errors

**Zigbee devices dropping off**

Usually interference or range. Check signal strength in Zigbee2MQTT UI → **Devices** → click a device → **Link quality**. Mains-powered Zigbee devices act as routers and extend range - add a plug-in switch or bulb to improve coverage.
