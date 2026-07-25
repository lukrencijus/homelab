# 🦇 Homelab

[![Proxmox VE](https://img.shields.io/badge/Hypervisor-Proxmox%20VE%209.1-orange?logo=proxmox&logoColor=white)](https://www.proxmox.com)
[![OS](https://img.shields.io/badge/OS-Debian%2013%20%28Trixie%29-D12149?logo=debian&logoColor=white)](https://www.debian.org)
[![Tailscale](https://img.shields.io/badge/VPN-Tailscale-blue?logo=tailscale&logoColor=white)](https://tailscale.com)
[![Status](https://img.shields.io/badge/Status-Active%20%2F%20Production-success)](#)

## Hardware

| Component | Specification | Details |
| :--- | :--- | :--- |
| **Host Machine** | Lenovo ThinkCentre M800 SFF | Corporate desktop repurposed as a home server |
| **CPU** | Intel Core i5-6500 @ 3.20GHz | 4 Cores / 4 Threads |
| **Memory** | 24 GB DDR4 @ 2133 MHz | Multi-channel setup |
| **System Drive** | Samsung 870 EVO 250GB SSD | Dedicated VM / LXC boot drive |
| **Storage Pool** | 2 x Seagate BarraCuda 2TB HDD | Mirrored storage pool |

## Software Stack & Hosted Services

| Service / Application   | Role & Description                                                             |
| :---------------------- | :----------------------------------------------------------------------------- |
| **Proxmox VE**          | The main hypervisor, runs all virtual machines and LXC containers      |
| **Ubuntu Server**       | Linux operating system for playing around, sandbox           |
| **Tailscale**           | Simple VPN to securely connect to homelab from anywhere               |
| **Nginx Proxy Manager** | Reverse proxy handling internal domain-name routing |
| **Pi-hole**             | DNS sinkhole for ad-blocking and local hostname resolution        |
| **TrueNAS SCALE**       | NAS OS managing ZFS pools and file shares   |
| **Immich**              | Self-hosted photo and video backup platform                  |
| **Jellyfin**            | Media server for streaming movie and TV show collection               |
| **Jellyseerr**          | Nice UI for requesting new movies and TV shows       |
| **Portainer**           | Docker web UI, makes managing containers incredibly simple      |
| **qBittorrent**         | Torrent client for downloading files                 |
| **Prowlarr**            | Manages indexers and feeds them to Sonarr and Radarr        |
| **Sonarr**              | Automated agent to find, download, and organize TV shows          |
| **Radarr**              | Automated agent to find, download, and organize movies              |
| **Bazarr**              | Automatically downloads subtitles for media library            |
| **Prometheus**          | Scrapes and stores metrics from servers and containers              |
| **Grafana**             | Creates clean dashboards to visualize server stats and performance  |

## Repository Structure

```
proxmox/
  scripts/          Host scripts: LXC auto-updates, host config backup, nag removal
  README.md         What runs when (cron + backup schedule)
docker/
  media-stack/      Compose for the *arr stack, qBittorrent behind gluetun VPN
  monitoring/       Compose + configs for Prometheus, Grafana, Alertmanager
```

Secrets (VPN credentials, webhook URLs) are kept out of git, see `.env.example` files.
