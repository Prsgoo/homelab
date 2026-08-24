---
title: Ultrafeeder Stack
updated: 2026-08-05
---

# Ultrafeeder Stack

LXC: [ultrafeeder](../../lxcs/ultrafeeder.md) (CT 200) - ADS-B receiver and flight data aggregator.

## Services

| Container | Purpose | Port |
|-----------|---------|------|
| ultrafeeder | Core decoder, tar1090 map, readsb | 8080 (map), 9273/9274 (metrics) |
| piaware | Feeds FlightAware | - |
| fr24feeder | Feeds Flightradar24 | 8754 (status) |
| opensky | Feeds OpenSky Network | - |

## Instance

| Setting | Value |
|---------|-------|
| Compose | `stacks/ultrafeeder/compose.yaml` |
| Managed as | Komodo stack `ultrafeeder` on server `ultrafeeder` |
| Komodo root | `/data/komodo` |
| tar1090 | `https://adsb.home.example.com:<admin-port>` |
| Piaware status | `https://piaware.home.example.com:<admin-port>` |
| FR24 status | `https://fr24.home.example.com:<admin-port>` |

## Key Env Vars

| Variable | Purpose |
|----------|---------|
| `READSB_DEVICE_TYPE` | `rtlsdr` |
| `READSB_RTLSDR_DEVICE` | SDR serial number |
| `FEEDER_LAT` / `FEEDER_LONG` / `FEEDER_ALT_M` | Receiver coordinates |
| `FEEDER_TZ` | Timezone |
| `PIAWARE_FEEDER_ID` | FlightAware claim code |
| `FR24_SHARING_KEY` | Flightradar24 key |
| `OPENSKY_USERNAME` / `OPENSKY_SERIAL` | OpenSky credentials |
| `ULTRAFEEDER_CONFIG` | Aggregator endpoint list (MLAT + ADSB Beast) |

## Prometheus Metrics

Ultrafeeder exposes metrics on two ports:
- `:9273` - readsb stats (aircraft count, message rate, signal quality)
- `:9274` - telegraf-style metrics (feed stats per aggregator)

Image: `ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder:telegraf`

Use `:telegraf`, not `:latest` - `:latest` dropped Telegraf and port 9273 never binds without it. Port 9274 (readsb built-in) works with any tag but covers only basic aggregate counts, not enough for dashboard 18398.

Prometheus job name: `ultrafeeder`

## Grafana Dashboard

Dashboard ID: **18398** (Ultrafeeder ADS-B)

Setup checklist after import:
1. Set datasource to the local Prometheus instance
2. Variable `$host` → select `ultrafeeder`
3. Heatmap panels require Grafana 9+ "heatmap" visualization type
4. If heatmap shows blank: check CT 200's Grafana data source access - Grafana must reach `<ultrafeeder-ip>:9273` directly; add an ACL entry if needed

## Adding New Aggregators

Add entries to `ULTRAFEEDER_CONFIG` in the compose env:
```
adsb,feed.adsbexchange.com,30005,beast_reduce_plus_out;mlat,feed.adsbexchange.com,31090,39000
```

Restart the ultrafeeder container after editing env vars. Komodo handles this via `DeployStack`.

## Key Takeaways

- USB passthrough uses `lxc.cgroup2.devices.allow` + `lxc.mount.entry` at the LXC level AND `device_cgroup_rules` in the compose - both are required; see [ultrafeeder](../../lxcs/ultrafeeder.md)
- Image must be `docker-adsb-ultrafeeder:telegraf` - `:latest` dropped Telegraf, breaking port 9273
- OpenSky registration requires submitting the feeder's serial to the OpenSky network before it appears on the leaderboard
