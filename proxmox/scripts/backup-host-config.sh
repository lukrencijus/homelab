#!/bin/bash
# Weekly Proxmox host configuration backup -> TrueNAS NFS share.
# Guests are covered by vzdump; this captures everything vzdump does NOT:
# host network/storage/job config, sysctl tweaks, ssh keys, apt sources.
set -euo pipefail

DEST_ROOT=/mnt/pve/backup-truenas
DEST=$DEST_ROOT/host-config
KEEP=8
STAMP=$(date +%Y-%m-%d_%H%M)
OUT=$DEST/host-config-$(hostname)-$STAMP.tar.gz

# Never write into an empty mountpoint directory if the NFS share is down.
if ! mountpoint -q "$DEST_ROOT"; then
    echo "ERROR: $DEST_ROOT is not mounted, aborting" >&2
    exit 1
fi
mkdir -p "$DEST"

# Extra state that isn't a plain config file
META=$(mktemp -d)
trap 'rm -rf "$META"' EXIT
pveversion -v          > "$META/pveversion.txt"
dpkg --get-selections  > "$META/dpkg-selections.txt"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,SERIAL > "$META/lsblk.txt"
lvs > "$META/lvs.txt" 2>&1
vgs > "$META/vgs.txt" 2>&1

tar czf "$OUT" \
    --absolute-names \
    --ignore-failed-read \
    /etc/pve \
    /etc/network/interfaces /etc/network/interfaces.d \
    /etc/sysctl.conf /etc/sysctl.d \
    /etc/vzdump.conf \
    /etc/hosts /etc/hostname /etc/resolv.conf \
    /etc/fstab \
    /etc/ssh /root/.ssh \
    /etc/cron.d /etc/crontab \
    /etc/apt/sources.list /etc/apt/sources.list.d \
    /etc/default/grub /etc/modprobe.d /etc/modules \
    /etc/lvm/lvm.conf \
    /etc/systemd/journald.conf.d \
    "$META"

# Rotate: keep newest $KEEP archives
ls -1t "$DEST"/host-config-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f

echo "OK: $(du -h "$OUT" | cut -f1) -> $OUT"
