---
title: Grocy
updated: 2026-09-22
---

# Grocy

Self-hosted grocery management, price tracking, and household task manager.

## Details

| Setting | Value |
|---------|-------|
| LXC | CT 600 (personal-apps) |
| Image | `lscr.io/linuxserver/grocy:latest` |
| Port | 9241 |
| UID/GID | 1601 / 1600 (`personal-apps`) |
| Data | `/data/grocy` → `$DATA_ROOT/config/personal-apps/grocy` |
| Komodo stack | `grocy` |
| Route | `https://grocy.<your-domain>:<admin-port>` (admin-only) |

## Config

`/config/data/config.php` inside the container. Grocy reads it on every page load, no restart needed.

Non-default settings worth applying:

| Setting | Value | Why |
|---------|-------|-----|
| `CURRENCY` | `EUR` (or your currency) | Currency display |
| `DEFAULT_LOCALE` | `es` (or your locale) | Language default |
| `FEATURE_FLAG_BATTERIES` | `false` | Unused for most setups |
| `FEATURE_FLAG_EQUIPMENT` | `false` | Unused for most setups |
| `stock_auto_decimal_separator_prices` | `true` | Locale-aware decimal input |

Note: the currency setting is not exposed in the Grocy UI in current versions — config.php is the only way to set it.

## Key Takeaways

- Default credentials: `admin` / `admin` — change on first login
- Add supermarkets under Settings → Stores before logging purchases
- Price tracking builds from purchase history — data accumulates over shopping trips, not instantly
- iOS companion app: **Grocy Mobile** (by supergeorg) on the App Store — free, barcode scanning, iPad-native
