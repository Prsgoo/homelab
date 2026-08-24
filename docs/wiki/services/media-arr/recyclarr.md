---
title: Recyclarr
updated: 2026-08-05
---

# Recyclarr

LXC: [media arr](../../lxcs/media-arr.md) (CT 300) - syncs TRaSH Guides quality profiles and custom formats to Sonarr/Radarr.

## Instance

| Setting | Value |
|---------|-------|
| Config | `/data/recyclarr/` |
| UID/GID | 1306:1306 |
| Schedule | Cron, 3am daily |
| Managed as | Komodo stack `media-arr` |

## v8 Config Syntax

Recyclarr v8 removed template includes. Use inline `trash_ids` lists instead:

```yaml
# v8 - correct
quality_profiles:
  - name: HD-1080p
    qualities:
      - name: Bluray-1080p
    custom_formats:
      - trash_ids:
          - b124be9b146540f359e97f34b5e66fdb
```

Running `recyclarr config list-templates` lists available template names (use for reference only - do not `include` them in v8).
