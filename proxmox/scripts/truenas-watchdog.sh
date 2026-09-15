#!/bin/bash
# truenas-watchdog.sh - detects the TrueNAS VM (101) going unreachable over
# the network and restarts just that VM, instead of requiring a full host
# reboot. Other guests depend on its NFS shares, so a hung NAS stalls them too.
#
# Runs every 60s via truenas-watchdog.timer. State kept in /run (tmpfs),
# so it resets naturally on host reboot.

set -u

TRUENAS_IP="192.168.8.5"
VMID="101"
STATE_DIR="/run/truenas-watchdog"
FAIL_COUNT_FILE="$STATE_DIR/fail_count"
LAST_ACTION_FILE="$STATE_DIR/last_action_epoch"
LOG_FILE="/var/log/truenas-watchdog.log"

# Consecutive failed checks (1/min) before acting: 4 min sustained outage.
# Short multi-second write-latency spikes on the SMR disks should NOT
# trigger a restart.
FAIL_THRESHOLD=4

# Minimum seconds between auto-restarts, so a still-broken VM doesn't get
# restart-looped. After one attempt we just keep logging.
COOLDOWN_SECONDS=1800

mkdir -p "$STATE_DIR"
[ -f "$FAIL_COUNT_FILE" ] || echo 0 > "$FAIL_COUNT_FILE"

log() {
    local msg="$1"
    logger -t truenas-watchdog -p "daemon.${2:-info}" "$msg"
    echo "$(date -Is) $msg" >> "$LOG_FILE"
}

if ping -c1 -W3 "$TRUENAS_IP" >/dev/null 2>&1; then
    prev=$(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0)
    if [ "$prev" -ge "$FAIL_THRESHOLD" ]; then
        log "TrueNAS ($TRUENAS_IP) reachable again after $prev failed check(s) — recovered on its own."
    fi
    echo 0 > "$FAIL_COUNT_FILE"
    exit 0
fi

count=$(( $(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$FAIL_COUNT_FILE"
log "TrueNAS ($TRUENAS_IP) unreachable — consecutive failed check #$count." warning

if [ "$count" -lt "$FAIL_THRESHOLD" ]; then
    exit 0
fi

now=$(date +%s)
last_action=$(cat "$LAST_ACTION_FILE" 2>/dev/null || echo 0)
elapsed=$(( now - last_action ))

if [ "$elapsed" -lt "$COOLDOWN_SECONDS" ]; then
    log "Threshold reached but still in cooldown (${elapsed}s since last action, need ${COOLDOWN_SECONDS}s) — alerting only, NOT restarting again." err
    exit 0
fi

log "TrueNAS unreachable for >= ${FAIL_THRESHOLD} min — restarting VM $VMID now (qm stop --skiplock, then qm start)." err
echo "$now" > "$LAST_ACTION_FILE"

# A hung guest usually doesn't answer the guest agent either, so a graceful
# qm shutdown just wastes time. qm stop already escalates
# ACPI -> SIGTERM -> SIGKILL on its own.
#
# qm stop MUST be wrapped in a timeout: if the host-side vhost-net thread for
# the VM is stuck in D state (e.g. memory compaction waiting on NFS writeback
# to this very VM), qm stop can block forever. Every step below is bounded,
# and each outcome is logged.
QM_STOP_TIMEOUT=90
QM_START_TIMEOUT=120

vm_pid() {
    local f="/var/run/qemu-server/${VMID}.pid"
    [ -r "$f" ] && cat "$f" 2>/dev/null || true
}

kvm_pid="$(vm_pid)"

if timeout "$QM_STOP_TIMEOUT" qm stop "$VMID" --skiplock >>"$LOG_FILE" 2>&1; then
    log "qm stop of VM $VMID returned cleanly."
else
    rc=$?
    if [ "$rc" -eq 124 ]; then
        log "qm stop of VM $VMID TIMED OUT after ${QM_STOP_TIMEOUT}s -- falling back to SIGKILL." err
    else
        log "qm stop of VM $VMID failed (rc=$rc) -- falling back to SIGKILL." err
    fi

    # Fall back to killing QEMU directly. Note: if the QEMU/vhost threads are
    # wedged in uninterruptible sleep (D state) inside the kernel, even SIGKILL
    # will not reap them until the I/O they wait on completes -- that case is
    # detected and reported below so it is visible in the log instead of silent.
    if [ -n "$kvm_pid" ] && kill -0 "$kvm_pid" 2>/dev/null; then
        kill -9 "$kvm_pid" 2>>"$LOG_FILE"
        for _ in $(seq 1 20); do
            kill -0 "$kvm_pid" 2>/dev/null || break
            sleep 1
        done
        if kill -0 "$kvm_pid" 2>/dev/null; then
            state=$(awk '{print $3}' "/proc/$kvm_pid/stat" 2>/dev/null || echo "?")
            log "SIGKILL did NOT reap QEMU pid $kvm_pid (state=$state) -- VM 101 is wedged in the kernel; a host reboot is likely required. NOT attempting qm start." err
            echo 0 > "$FAIL_COUNT_FILE"
            exit 1
        fi
        log "QEMU pid $kvm_pid killed after qm stop failed."
        # qm may still consider the VM locked/running after an out-of-band kill.
        timeout 30 qm unlock "$VMID" >>"$LOG_FILE" 2>&1 || true
    else
        log "No live QEMU pid found for VM $VMID -- proceeding to start." err
    fi
fi

sleep 5

if timeout "$QM_START_TIMEOUT" qm start "$VMID" >>"$LOG_FILE" 2>&1; then
    log "qm start of VM $VMID returned cleanly."
else
    rc=$?
    if [ "$rc" -eq 124 ]; then
        log "qm start of VM $VMID TIMED OUT after ${QM_START_TIMEOUT}s -- manual intervention needed." err
    else
        log "qm start of VM $VMID failed (rc=$rc) -- manual intervention needed." err
    fi
fi

log "Auto-restart of VM $VMID completed. Watch dmesg/qm status to confirm it comes back healthy." err

# reset the fail counter so we don't immediately re-trigger while it boots
echo 0 > "$FAIL_COUNT_FILE"
