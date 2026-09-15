# Proxmox host

Scripts, config and scheduled jobs on the Proxmox VE host (`batcave`).

## Scripts

| Script | Installed as | Purpose |
| :--- | :--- | :--- |
| [update-lxcs.sh](scripts/update-lxcs.sh) | `/usr/local/bin/` | Updates all LXC containers via their native package manager (from [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE), MIT) |
| [backup-host-config.sh](scripts/backup-host-config.sh) | `/usr/local/sbin/` | Tars up host config (`/etc/pve`, network, storage, cron, systemd units, local scripts, ssh, apt sources) plus package/disk state to the TrueNAS NFS share, keeps last 8 |
| [pve-remove-nag.sh](scripts/pve-remove-nag.sh) | `/usr/local/bin/` | Removes the subscription nag from the web and mobile UI |
| [pct-fstrim.sh](scripts/pct-fstrim.sh) | `/usr/local/sbin/` | Runs `pct fstrim` on all running LXC containers so deleted blocks return to the thin pool and SSD (the host `fstrim.timer` only covers host filesystems) |
| [truenas-watchdog.sh](scripts/truenas-watchdog.sh) | `/usr/local/sbin/` | Pings the TrueNAS VM every minute; after 4 min unreachable it force-restarts VM 101 (bounded timeouts, SIGKILL fallback, 30 min cooldown) |
| [finance-update](scripts/finance-update) | `/usr/local/bin/` | Shortcut that runs the finance app updater inside LXC 109 |

## Config

| File | Purpose |
| :--- | :--- |
| [systemd/system/truenas-watchdog.{service,timer}](config/etc/systemd/system) | Runs the watchdog every 60s |
| [sysctl.d/99-vhost-compaction-safety.conf](config/etc/sysctl.d/99-vhost-compaction-safety.conf) | `vm.min_free_kbytes=512MB` so the VM network thread never stalls in direct compaction |
| [sysctl.d/99-nfs-backup-safety.conf](config/etc/sysctl.d/99-nfs-backup-safety.conf) | Caps dirty page cache so big NFS writes (backups) can't starve memory reclaim |
| [sysctl.d/99-tailscale.conf](config/etc/sysctl.d/99-tailscale.conf) | IP forwarding for Tailscale |
| [modprobe.d/zfs.conf](config/etc/modprobe.d/zfs.conf) | Caps ZFS ARC on the host |
| [fstab.nfs](config/etc/fstab.nfs) | NFS mounts from TrueNAS (soft mounts + automount) |
| [pve/storage.cfg](config/etc/pve/storage.cfg) | Proxmox storage: local, LVM-thin, TrueNAS NFS backup target |

Host metrics come from `prometheus-node-exporter` (:9100, Debian package) and
[smartctl_exporter](https://github.com/prometheus-community/smartctl_exporter) (:9633, systemd service),
both scraped by the [monitoring stack](../docker/monitoring).

## Schedule

| When | Job |
| :--- | :--- |
| Every minute | `truenas-watchdog.timer` checks the TrueNAS VM |
| Sat 02:30 | Host config backup → TrueNAS (`/etc/cron.d/backup-host-config`) |
| Sat 03:00 | vzdump snapshot backup of all guests except TrueNAS → NFS share, zstd, 40 MB/s limit, keep last 3 (Proxmox backup job) |
| Sun 00:00 | `update-lxcs.sh` updates all LXC containers (root crontab) |
| Mon ~00:13 | Host `fstrim.timer` trims host filesystems (systemd default, weekly) |
| Mon 01:00 | `pct-fstrim.sh` trims all LXC volumes (`/etc/cron.d/pct-fstrim`) |
| 1st of month 04:00 | Host reboot (root crontab) |
