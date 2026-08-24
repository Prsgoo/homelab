# ADS-B - Ultrafeeder

## What you'll end up with

An RTL-SDR USB dongle passed through to CT 200, running the Ultrafeeder Docker stack. Live flight tracking at `https://adsb.home.example.com:<admin-port>` (tar1090 map). Data feeding to FlightAware, FlightRadar24, and OpenSky simultaneously. Prometheus metrics for Grafana dashboard 18398.

---

## Prerequisites

- Komodo running
- Traefik running
- An RTL-SDR USB dongle plugged into the Proxmox host (e.g. RTL-SDR Blog V4, FlightAware Pro Stick)
- Feeder accounts registered: [FlightAware](https://flightaware.com), [FlightRadar24](https://www.flightradar24.com/share-your-data), [OpenSky Network](https://opensky-network.org)
- Your receiver's coordinates (latitude, longitude, altitude in meters)

---

## 1. Get your SDR serial number and calibration

Plug in the dongle on the Proxmox host, then:

```bash
apt-get install -y rtl-sdr
rtl_test -t
```

Note the serial number shown. If you have multiple SDRs, set a unique serial with `rtl_eeprom -s <serial>` to avoid order changes after reboot.

PPM calibration: leave at `0` initially. After a few days of data you can fine-tune it - but for ADS-B at 1090 MHz the default is usually fine.

---

## 2. Create the LXC

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value |
|---------|-------|
| CT ID | 200 |
| Hostname | ultrafeeder |
| Cores | 2 |
| RAM | 2048 MB |
| Disk | 8 GB |
| IP | <ultrafeeder-ip>/24 |

---

## 3. Run the CT script

```bash
cd /opt/proxmox-admin
bash scripts/ct200-ultrafeeder.sh
```

This applies the USB passthrough to CT 200. Unlike the Zigbee dongle (which uses `dev0`), the RTL-SDR uses a different passthrough method because Docker needs access to the entire USB bus to enumerate the device:

```
lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/bus/usb dev/bus/usb none bind,optional,create=dir
```

The Docker compose then adds `device_cgroup_rules: 'c 189:* rwm'` to the Ultrafeeder container. Both the LXC-level and container-level rules are required.

---

## 4. Fill in the stack `.env`

```bash
pct exec 200 -- nano /data/komodo/stacks/ultrafeeder/.env
```

| Variable | Value |
|----------|-------|
| `FEEDER_TZ` | Your timezone (e.g. `Europe/Madrid`) |
| `FEEDER_LAT` | Receiver latitude (decimal, e.g. `40.4168`) |
| `FEEDER_LONG` | Receiver longitude (decimal, e.g. `-3.7038`) |
| `FEEDER_ALT_M` | Receiver altitude in meters above sea level |
| `FEEDER_NAME` | Display name for your feeder |
| `ADSB_SDR_SERIAL` | SDR serial number from step 1 |
| `ADSB_SDR_PPM` | PPM offset (use `0` initially) |
| `ULTRAFEEDER_UUID` | Generate at [UUID generator](https://www.uuidgenerator.net/) |
| `PIAWARE_FEEDER_ID` | Your FlightAware claim code |
| `FR24_SHARING_KEY` | Your FlightRadar24 sharing key |
| `OPENSKY_USERNAME` | Your OpenSky username |
| `OPENSKY_SERIAL` | Your OpenSky feeder serial |

**Getting feed keys:**

- **FlightAware**: After registering, go to your account → My ADS-B → claim a new feeder → copy the claim code into `PIAWARE_FEEDER_ID`
- **FlightRadar24**: [fr24feed signup](https://www.flightradar24.com/share-your-data) → sharing key is emailed to you
- **OpenSky**: Register a sensor at [opensky-network.org/my-sensor](https://opensky-network.org/my-sensor) - serial is assigned after registration

---

## 5. Deploy via Komodo

Add CT 200 as a server in Komodo (`wss://<ultrafeeder-ip>:8120`), then deploy the `ultrafeeder` stack.

!!! warning "Use the `:telegraf` image tag"
    The compose must use `ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder:telegraf`, not `:latest`. The `:latest` tag dropped Telegraf support - port 9273 (readsb Prometheus metrics) won't bind without it, which breaks Grafana dashboard 18398.

After deploy, open `https://adsb.home.example.com:<admin-port>` - the tar1090 map should appear. Aircraft will start showing up within 30�60 seconds if the SDR is receiving signals.

---

## 6. Verify feeding

Check each feed status:

- **FlightAware**: `https://piaware.home.example.com:<admin-port>` - shows connection status and message rate
- **FlightRadar24**: `https://fr24.home.example.com:<admin-port>` - shows feed status
- **OpenSky**: [opensky-network.org/receiver-profile](https://opensky-network.org/receiver-profile) - may take up to 24h to appear

---

## 7. Add to Prometheus (optional)

Ultrafeeder exposes metrics on two ports. These are already in `prometheus.yml` under the `ultrafeeder` job:

| Port | Metrics |
|------|---------|
| `9273` | readsb stats: aircraft count, message rate, signal quality |
| `9274` | feed stats per aggregator |

After deploying the `node-exporter-ultrafeeder` stack, reload Prometheus config:

```bash
curl -X POST http://<monitoring-ip>:9090/-/reload
```

Then in Grafana, import dashboard **18398** and set the `$host` variable to `ultrafeeder`.

---

## Day-2 operations

### Updating Ultrafeeder

In Komodo UI: **Stacks → ultrafeeder → Deploy**. Pulls the latest image and restarts.

!!! warning "Pin the `:telegraf` tag"
    Don't let it pull `:latest` - always use `ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder:telegraf`. `:latest` dropped Telegraf support, which breaks port 9273 and the Grafana dashboard.

### Adding a new feed aggregator

Add an entry to `ULTRAFEEDER_CONFIG` in the `.env` file:

```
adsb,feed.adsbexchange.com,30005,beast_reduce_plus_out;mlat,feed.adsbexchange.com,31090,39000
```

Redeploy the stack via Komodo to apply.

### Checking message rate / signal quality

tar1090 map → click the stats icon in the bottom left. Good message rates depend heavily on antenna placement - outdoor or attic placement with a 1090 MHz antenna significantly outperforms indoor.

### USB device changed bus path

If you re-plug the dongle or change USB ports, the bus path changes but the serial number doesn't. The LXC config mounts the whole `/dev/bus/usb` directory, so no LXC config change is needed. Just redeploy the stack in Komodo so Docker re-enumerates the device.

---

## Troubleshooting

**tar1090 map loads but shows no aircraft**

1. Check the SDR is detected inside CT 200: `pct exec 200 -- docker exec ultrafeeder rtl_test -t`
2. Confirm the serial number in `.env` matches the actual device: `pct exec 200 -- docker exec ultrafeeder rtl_eeprom`
3. Check the LXC passthrough is active: `pct exec 200 -- ls /dev/bus/usb/`

**Port 9273 not responding (Prometheus scrape failing)**

The image tag must be `:telegraf`. Check: `pct exec 200 -- docker inspect ultrafeeder | grep Image`.

**Feeds not connecting**

Check container logs for each feed service:

```bash
pct exec 200 -- docker logs piaware --tail 50
pct exec 200 -- docker logs fr24feeder --tail 50
```

Common causes: wrong sharing key, firewall blocking outbound connections, or feed site temporarily down.
