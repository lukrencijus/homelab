# Architecture

## Storage

```
                ┌──────────────── Proxmox host ────────────────┐
  870 EVO SSD → │ root + LVM-thin: all VM/LXC disks            │
                │                                              │
  2x 2TB HDD ───┼──► VM 101 TrueNAS (ZFS mirror "HDD2000")     │
  (passthrough) │        │ NFS v4.2                            │
                │        ▼                                     │
                │   host mounts /mnt/immich, /mnt/jellyfin*,   │
                │               /mnt/pve/backup-truenas        │
                │        │ bind mounts (mpX)                   │
                │        ▼                                     │
                │   LXC 103 immich, LXC 105 jellyfin           │
                └──────────────────────────────────────────────┘
```

- The HDDs are passed straight into the TrueNAS VM, which owns the ZFS pool.
- TrueNAS exports photos, movies, TV shows and a backup dataset over NFS.
- The **host** mounts the shares and bind-mounts them into the LXCs, so the
  containers stay unprivileged and don't need NFS clients of their own.
- Downloads land on a 30 GB SSD volume inside LXC 106 first, then the *arr apps
  move finished media to the NAS.

### Why the extra safety config

The NAS is a VM on the same host that consumes its shares, and the disks are
SMR (slow, bursty writes). That loop needs some guard rails:

| Guard | Where |
| :--- | :--- |
| `soft` NFS mounts with timeouts, so a hung NAS returns errors instead of blocking forever | [fstab.nfs](../proxmox/config/etc/fstab.nfs), [storage.cfg](../proxmox/config/etc/pve/storage.cfg) |
| Dirty page cap, so large writes can't pile up GBs of unflushed NFS data | [99-nfs-backup-safety.conf](../proxmox/config/etc/sysctl.d/99-nfs-backup-safety.conf) |
| Higher `min_free_kbytes`, so the VM's network thread never waits on NFS during memory compaction | [99-vhost-compaction-safety.conf](../proxmox/config/etc/sysctl.d/99-vhost-compaction-safety.conf) |
| Watchdog that restarts only the TrueNAS VM if it stops answering | [truenas-watchdog.sh](../proxmox/scripts/truenas-watchdog.sh) |
| Backups rate-limited (40 MB/s) and TrueNAS excluded from vzdump | [proxmox/README.md](../proxmox/README.md#schedule) |

## Backups

| What | How | Where |
| :--- | :--- | :--- |
| All guests except TrueNAS | vzdump snapshot, weekly, keep 3 | TrueNAS NFS |
| Host config | `backup-host-config.sh`, weekly, keep 8 | TrueNAS NFS |
| Config in this repo | git | GitHub |

## Hardware transcoding

The i5-6500 iGPU (`/dev/dri/renderD128`, `/dev/dri/card0`) is passed into the
Immich and Jellyfin LXCs and used through VAAPI / Quick Sync. Skylake can
hardware-decode H.264 and 8-bit HEVC, but **not 10-bit HEVC**, so 4K HDR files
still mostly use the CPU.

## Remote access

Tailscale runs on the host as a subnet router for the LAN, so remote devices
reach services by the same addresses they use at home.
