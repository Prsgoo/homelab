---
title: Hardlinks and the Media Stack
updated: 2026-09-13
---

# Hardlinks and the Media Stack

## What they are

A hardlink is a second directory entry pointing to the same data on disk. Two filenames, one copy of the data. Deleting either one leaves the other intact - the data is only freed when the last reference is removed.

## Why the media stack uses them

When Sonarr or Radarr imports a completed download, it moves the file from the download directory to the library. If the source and destination are on the same filesystem, the OS can create a hardlink instead of copying - the file appears in both locations instantly, with no disk space used for the second entry.

This is critical for the seeding workflow: after import, the torrent client still seeds from `/torrents/` while the library serves the file from `/media/`. Both paths point to the same data.

## Why it works across LXCs

The media-arr, media-server, and media-dl LXCs are separate containers, but all three mount subdirectories of the same host filesystem:

| LXC | Mount | Host path |
|-----|-------|-----------|
| media-arr | `/media` | `$DATA_ROOT/media-stack/media` |
| media-arr | `/torrents` | `$DATA_ROOT/media-stack/torrents` |
| media-arr | `/usenet` | `$DATA_ROOT/media-stack/usenet` |
| media-server | `/media` (ro) | `$DATA_ROOT/media-stack/media` |
| media-dl | `/torrents` | `$DATA_ROOT/media-stack/torrents` |
| media-dl | `/usenet` | `$DATA_ROOT/media-stack/usenet` |

The host sees all of `$DATA_ROOT/media-stack/` as one filesystem. Hardlinks between `/media` and `/torrents` are cross-directory but same-filesystem - so they work. The LXC boundary is irrelevant; the kernel only cares about the underlying block device.

## What breaks hardlinks

- **Different filesystems**: hardlinks cannot cross filesystem boundaries. If downloads and media were on separate disks or separate LVM volumes with different filesystems, hardlinks would silently fall back to a full copy.
- **Btrfs subvolumes**: each subvolume is treated as a separate filesystem. Hardlinks between subvolumes fail even on the same disk.
- **Docker named volumes**: named volumes live inside the Docker storage driver's own filesystem area - hardlinks between a named volume and `$DATA_ROOT` are not possible.

## Verifying hardlinks are working

After Sonarr/Radarr imports a file, check the link count. A count of 2 means the file has two directory entries (the original download + the library copy):

```bash
stat /media/tv/ShowName/Season\ 01/episode.mkv
# Look for: Links: 2
```

If it shows `Links: 1`, the import used a copy instead of a hardlink. Common causes:
- Sonarr/Radarr import mode set to "Copy" instead of "Hardlink"
- Source and destination paths are on different filesystems

Check the import mode: **Settings → Media Management → Import Mode → Hardlink**.

## Usenet downloads

SABnzbd extracts archives to a completion folder. Unpackerr then moves the extracted files into a location that Sonarr/Radarr can import. As long as all paths stay within `$DATA_ROOT/media-stack/`, hardlinks work the same way.
