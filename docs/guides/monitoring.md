# Monitoring - Prometheus, Grafana, Uptime Kuma

## What you'll end up with

Prometheus scraping metrics from every CT (via node-exporter) plus the Proxmox host itself (via pve-exporter). Grafana with dashboards for node resources, Proxmox hardware, and ADS-B stats. Uptime Kuma watching all services with a status page.

---

## Prerequisites

- Komodo running
- Traefik running
- All other CTs already set up (node-exporters deploy alongside each CT's stack)

---

## 1. Create the LXC

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)
```

| Setting | Value |
|---------|-------|
| CT ID | 202 |
| Hostname | monitoring |
| Cores | 2 |
| RAM | 1024 MB |
| Disk | 8 GB |
| IP | <monitoring-ip>/24 |

---

## 2. Run the CT script

```bash
cd /opt/proxmox-admin
bash scripts/ct202-monitoring.sh
```

---

## 3. Pre-create the Grafana data directory

Grafana runs as UID 472 inside its container. Due to CT 202's idmap, this maps to host UID `100472`. The bind-mounted data directory must be pre-owned before starting the stack, or Grafana fails to write its database.

```bash
mkdir -p $DATA_ROOT/config/monitoring/grafana
chown -R 100472:100472 $DATA_ROOT/config/monitoring/grafana
```

---

## 4. Create the PVE API token

pve-exporter needs a Proxmox API token to read host metrics. Create a dedicated PVE user for this:

In the Proxmox web UI → **Datacenter → Permissions → Users → Add**:

| Field | Value |
|-------|-------|
| User ID | `pve-exporter@pve` |
| Realm | `pve` |

Then **Permissions → API Tokens → Add**:

| Field | Value |
|-------|-------|
| User | `pve-exporter@pve` |
| Token ID | `metrics` |
| Privilege separation | **off** |

Save the token UUID - you'll put it in `pve.yml`.

Then assign the `PVEAuditor` role at the datacenter level: **Permissions → Add → User Permission**:
- Path: `/`
- User: `pve-exporter@pve`
- Role: `PVEAuditor`

---

## 5. Push monitoring config files

The Prometheus config and pve-exporter config are not managed through Komodo - push them directly:

```bash
pct exec 202 -- mkdir -p /data/pve-exporter

pct push 202 stacks/monitoring/prometheus.yml /data/prometheus.yml
pct push 202 stacks/monitoring/pve.yml /data/pve-exporter/pve.yml
pct exec 202 -- chmod 644 /data/prometheus.yml /data/pve-exporter/pve.yml
```

Then edit `pve.yml` inside CT 202 to fill in the token:

```bash
pct exec 202 -- nano /data/pve-exporter/pve.yml
```

```yaml
default:
  user: pve-exporter@pve
  token_name: metrics
  token_value: <token-uuid-from-step-4>
  verify_ssl: false
  privsep: false
```

!!! warning "`privsep: false` is required"
    The default `privsep: true` spawns a privilege-separation subprocess that fails in an LXC (can't set resource limits). Without `privsep: false`, pve-exporter exits silently and Prometheus gets no Proxmox metrics.

---

## 6. Deploy the monitoring stack via Komodo

Add CT 202 as a server in Komodo (`wss://<monitoring-ip>:8120`), then deploy the `monitoring` stack.

The stack runs Prometheus, Grafana, Uptime Kuma, and pve-exporter as a single compose. After deploy:

- Prometheus: `https://prometheus.home.example.com:<admin-port>`
- Grafana: `https://grafana.home.example.com:<admin-port>`
- Uptime Kuma: `https://kuma.home.example.com:<admin-port>`

---

## 7. Deploy node-exporters on all CTs

Node-exporter runs on each CT as a separate Komodo stack named `node-exporter-<ct-name>` (e.g. `node-exporter-monitoring`, `node-exporter-media-arr`). The CT scripts already placed the compose file in each CT's stacks directory.

In Komodo, add and deploy a `node-exporter-<name>` stack on each server you want to monitor. All node-exporters listen on port `9100`. Prometheus is already configured to scrape all of them in `prometheus.yml`.

---

## 8. Add Grafana dashboards

Log into Grafana (`admin` / `admin`, then change the password).

Go to **Dashboards → Import** and add by ID:

| Dashboard ID | Name |
|-------------|------|
| `1860` | Node Exporter Full |
| `10347` | Proxmox VE via pve-exporter |
| `18398` | Ultrafeeder ADS-B |

For each import, set the datasource to `Prometheus` (your local instance).

For dashboard `18398`, after import: set the `$host` variable to `ultrafeeder`. If heatmap panels show blank, confirm Grafana can reach `<ultrafeeder-ip>:9273` directly from CT 202.

---

## 9. Import Uptime Kuma monitors

Log into Uptime Kuma and import the monitor list from the repo:

**Settings → Backup → Import Backup** → upload `stacks/monitoring/uptime-kuma-monitors.json`.

This creates HTTP monitors for all services. The monitors use `*.home.example.com` hostnames - they need the `dns:` override in the compose to resolve them:

```yaml
services:
  uptime-kuma:
    dns:
      - <pihole-ip>
```

This is already in the compose file. Without it, the container uses the host resolver instead of Pi-hole and can't resolve internal domains.

!!! note "Traefik dashboard monitor"
    The Traefik monitor URL must be `https://traefik.home.example.com:<admin-port>/dashboard/` - with the trailing slash. Without it, Traefik returns a 301 redirect, and Uptime Kuma may flag it as down depending on redirect settings.

---

## Day-2 operations

### Reloading Prometheus config

After editing `prometheus.yml`, reload without restart:

```bash
curl -X POST http://<monitoring-ip>:9090/-/reload
```

!!! warning "Edit prometheus.yml in-place"
    Use `nano` or `vi` - don't use tools that do atomic saves (write to temp, then rename). Prometheus binds to the file's inode, not its path; atomic-save tools replace the inode and Prometheus silently keeps serving the old config.

### Updating dashboards

Grafana dashboards imported from Grafana.com can be updated in place: **Dashboard → Settings → Save Dashboard** after editing, or re-import over the existing ID.

### Adding a new scrape target

Edit `/data/prometheus.yml` in CT 202, add the target to the relevant job, and reload Prometheus.

---

## Troubleshooting

**Grafana fails to start / can't write database**

Check ownership of the Grafana data directory on the host:

```bash
ls -la $DATA_ROOT/config/monitoring/grafana/
# Expected owner: 100472
```

If not, fix it: `chown -R 100472:100472 $DATA_ROOT/config/monitoring/grafana/`

**pve-exporter returning no data / Proxmox dashboard empty**

1. Confirm `privsep: false` is in `pve.yml`
2. Confirm the token UUID is correct
3. Test directly: `curl "http://<monitoring-ip>:9221/pve?target=<server-ip>"` - should return Prometheus metrics

**Uptime Kuma monitors showing down for internal domains**

Confirm the compose has `dns: - <pihole-ip>` under `uptime-kuma`. Without it, the container can't resolve `*.home.example.com`.

**ADS-B dashboard (18398) showing blank heatmaps**

The image must be `ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder:telegraf` - `:latest` dropped Telegraf support and port 9273 won't bind. Also confirm Grafana can reach `<ultrafeeder-ip>:9273` from CT 202.
