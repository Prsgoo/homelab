---
title: FreshRSS
updated: 2026-09-01
---

# FreshRSS

Self-hosted RSS reader and aggregator.

## Details

| Setting | Value |
|---------|-------|
| LXC | CT 600 (personal-apps) |
| Image | `freshrss/freshrss:latest` |
| Port | 8080 |
| Data | `/data/freshrss` → `$DATA_ROOT/config/personal-apps/freshrss` |
| Komodo stack | `freshrss` |
| Route | `https://freshrss.<your-domain>:8443` (admin-only) |

## Key Takeaways

- SQLite by default - no separate database container needed
- Auto-refresh every 30 min via `CRON_MIN=*/30`
- Data dir must be owned by host UID `100033` (www-data, UID 33 inside LXC) before first start: `chown -R 100033:100033 $DATA_ROOT/config/personal-apps/freshrss`
- Supports Google Reader and Fever APIs for mobile client compatibility (NetNewsWire, FeedMe, etc.)
