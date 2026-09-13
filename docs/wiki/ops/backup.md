---
title: Backup
updated: 2026-09-13
---

# Backup

!!! warning "Not yet implemented"
    No backup strategy is in place. This article is a placeholder.

## Scope

What needs to be backed up:

| Data | Location | Notes |
|------|----------|-------|
| Service config | `$DATA_ROOT/config/` | All bind-mounted container config dirs |
| Media library | `$DATA_ROOT/media-stack/media/` | Large - probably exclude or back up separately |
| Books | `$DATA_ROOT/media-stack/media/books/` | Part of media pool, smaller |
| Proxmox host config | `/etc/pve/` | LXC configs, storage config |
| Stack .env files | Komodo stacks | Passwords and API keys - critical |

## What disaster recovery already covers

The [disaster recovery guide](disaster-recovery.md) covers rebuilding the entire Proxmox host from scratch. It assumes the data disk (`$DATA_ROOT`) survives. If both the OS disk and data disk are lost simultaneously, there is currently no recovery path.
