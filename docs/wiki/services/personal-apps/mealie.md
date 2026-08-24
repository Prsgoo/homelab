---
title: Mealie
updated: 2026-08-17
---

# Mealie

Self-hosted recipe manager with meal planning and shopping list generation.

## Details

| Setting | Value |
|---------|-------|
| LXC | CT 600 (personal-apps) |
| Image | `ghcr.io/mealie-recipes/mealie:latest` |
| Port | 9000 |
| Data | `/data/mealie` → `$DATA_ROOT/config/personal-apps/mealie` |
| Komodo stack | `mealie` |
| Route | `https://mealie.home.example.com:<admin-port>` (admin-only) |

## Key Takeaways

- SQLite by default - no separate database container needed
- `ALLOW_SIGNUP=false` - create your account on first login, then signups are closed
- Default credentials on first run: `changeme@example.com` / `MyPassword` - change immediately
