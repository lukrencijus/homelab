#!/bin/bash
# Weekly TRIM of LXC container filesystems on the LVM-thin pool.
# The host fstrim.timer only trims host filesystems; container volumes
# need pct fstrim so deleted blocks return to the thin pool and the SSD.
set -uo pipefail

for id in $(pct list | awk 'NR>1 {print $1}'); do
    if [ "$(pct status "$id")" = "status: running" ]; then
        echo "[$(date)] fstrim CT $id"
        pct fstrim "$id" || echo "fstrim failed for CT $id"
    fi
done
