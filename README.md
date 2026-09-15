# 🦇 Homelab

[![Proxmox VE](https://img.shields.io/badge/Hypervisor-Proxmox%20VE%209.2-orange?logo=proxmox&logoColor=white)](https://www.proxmox.com)
[![OS](https://img.shields.io/badge/OS-Debian%2013%20%28Trixie%29-D12149?logo=debian&logoColor=white)](https://www.debian.org)
[![Tailscale](https://img.shields.io/badge/VPN-Tailscale-blue?logo=tailscale&logoColor=white)](https://tailscale.com)
[![Status](https://img.shields.io/badge/Status-Active%20%2F%20Production-success)](#)

## Hardware

| Component | Specification | Details |
| :--- | :--- | :--- |
| **Host Machine** | Lenovo ThinkCentre M800 SFF | Corporate desktop repurposed as a home server |
| **CPU** | Intel Core i5-6500 @ 3.20GHz | 4 Cores / 4 Threads, HD Graphics 530 (Quick Sync) |
| **Memory** | 24 GB DDR4 @ 2133 MHz | Multi-channel setup |
| **System Drive** | Samsung 870 EVO 250GB SSD | Proxmox root + LVM-thin pool for VM / LXC disks |
| **Storage Pool** | 2 x Seagate BarraCuda 2TB HDD (SMR) | ZFS mirror, disks passed through to the TrueNAS VM |

## Software Stack & Hosted Services

| Service / Application   | Role & Description                                                  |
| :---------------------- | :------------------------------------------------------------------ |
| **Proxmox VE**          | The main hypervisor, runs all virtual machines and LXC containers   |
| **TrueNAS SCALE**       | NAS OS managing the ZFS pool, serves NFS shares to the host         |
| **Tailscale**           | Simple VPN to securely connect to homelab from anywhere             |
| **Nginx Proxy Manager** | Reverse proxy handling internal domain-name routing                 |
| **Pi-hole**             | DNS sinkhole for ad-blocking and local hostname resolution          |
| **Immich**              | Self-hosted photo and video backup platform (Quick Sync transcoding)|
| **Jellyfin**            | Media server for movies and TV shows (Quick Sync transcoding)       |
| **Seerr**               | Nice UI for requesting new movies and TV shows (Jellyseerr successor)|
| **Vaultwarden**         | Self-hosted Bitwarden-compatible password manager                   |
| **Stirling-PDF**        | Web toolbox for merging, splitting and converting PDFs              |
| **Finance app**         | My own [finance-web-app](https://github.com/lukrencijus/finance-web-app) (Next.js), self-hosted |
| **Portainer**           | Docker web UI, makes managing containers incredibly simple          |
| **qBittorrent**         | Torrent client, routed through a gluetun VPN tunnel                 |
| **Prowlarr**            | Manages indexers and feeds them to Sonarr and Radarr                |
| **Sonarr**              | Automated agent to find, download, and organize TV shows            |
| **Radarr**              | Automated agent to find, download, and organize movies              |
| **Bazarr**              | Automatically downloads subtitles for media library                 |
| **Prometheus**          | Scrapes metrics and probes every service, alerts via Discord        |
| **Grafana**             | Creates clean dashboards to visualize server stats and performance  |
| **Ubuntu Server**       | Linux sandbox for playing around (normally stopped)                 |

## Guests

| ID | Type | Name | Resources | Runs |
| :--- | :--- | :--- | :--- | :--- |
| 101 | VM  | TrueNAS | 2 vCPU, 10 GB | TrueNAS SCALE, both HDDs passed through |
| 102 | LXC | pihole | 1 core, 256 MB | Pi-hole |
| 103 | LXC | immich | 4 cores, 6 GB | Immich, iGPU passed through |
| 104 | LXC | nginxproxymanager | 1 core, 256 MB | Nginx Proxy Manager |
| 105 | LXC | jellyfin | 4 cores, 4 GB | Jellyfin, iGPU passed through |
| 106 | LXC | docker | 2 cores, 4 GB | [media-stack](docker/media-stack) via Portainer |
| 107 | LXC | docker2 | 2 cores, 2 GB | [monitoring](docker/monitoring) via Portainer |
| 108 | LXC | ubuntu | 2 cores, 512 MB | Sandbox |
| 109 | LXC | finance | 2 cores, 2 GB | Finance app |
| 110 | LXC | vaultwarden | 1 core, 512 MB | Vaultwarden |
| 111 | LXC | stirling-pdf | 2 cores, 2 GB | Stirling-PDF |

Most LXCs were created with [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE).

## Repository Structure

```
proxmox/
  scripts/          Host scripts: LXC updates, config backup, fstrim, TrueNAS watchdog
  config/etc/       Host config: systemd units, sysctl tuning, NFS mounts, storage, ZFS
  README.md         What runs when (cron, timers, backup schedule)
lxc/                Config applied inside every container
docker/
  media-stack/      Compose for the *arr stack, qBittorrent behind gluetun VPN
  monitoring/       Compose + configs for Prometheus, Alertmanager, Blackbox, Grafana
docs/
  architecture.md   How storage, NFS and backups fit together
```

Secrets (VPN credentials, webhook URLs) are kept out of git, see `.env.example` files.
