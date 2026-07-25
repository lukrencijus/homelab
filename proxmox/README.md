# Proxmox host

Scripts and scheduled jobs running on the Proxmox VE host (`batcave`).

## Scripts

| Script | Purpose |
| :--- | :--- |
| [update-lxcs.sh](scripts/update-lxcs.sh) | Updates all LXC containers via their native package manager (from [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE), MIT) |
| [backup-host-config.sh](scripts/backup-host-config.sh) | Tars up host config (`/etc/pve`, network, storage, cron, ssh, apt sources) plus package/disk state to the TrueNAS NFS share, keeps last 8 |
| [pve-remove-nag.sh](scripts/pve-remove-nag.sh) | Removes the subscription nag from the web and mobile UI |

## Schedule

| When | Job |
| :--- | :--- |
| Sat 02:30 | Host config backup → TrueNAS (`/etc/cron.d/backup-host-config`) |
| Sat 03:00 | vzdump snapshot backup of all guests → TrueNAS NFS share, zstd, keep last 4 (Proxmox backup job) |
| Sun 00:00 | `update-lxcs.sh` updates all LXC containers |
| 1st of month 04:00 | Host reboot |
