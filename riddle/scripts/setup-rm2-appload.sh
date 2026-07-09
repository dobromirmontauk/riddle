#!/usr/bin/env bash
# Experimental reMarkable 2 xovi + AppLoad setup.
#
# This assumes root SSH access to the tablet. It installs upstream arm32 xovi
# and AppLoad release artifacts into /home/root/xovi, starts xovi once, and
# writes a rollback script to the tablet.
#
# Usage:
#   ./scripts/setup-rm2-appload.sh root@10.11.99.1
#
# Environment:
#   RM2_SSH=root@10.11.99.1
#   RM2_ASSUME_YES=1              Skip confirmation prompt.
#   RM2_FORCE_XOVI_OVERWRITE=1    Replace existing /home/root/xovi after backup.
#   RM2_ALLOW_UNKNOWN_MODEL=1     Skip the model guard.
set -euo pipefail

RM2_SSH="${1:-${RM2_SSH:-root@10.11.99.1}}"
XOVI_TAG="${XOVI_TAG:-v19-23052026}"
APPLOAD_TAG="${APPLOAD_TAG:-v0.5.3}"
XOVI_URL="https://github.com/asivery/rm-xovi-extensions/releases/download/${XOVI_TAG}/xovi-arm32.tar.gz"
APPLOAD_URL="https://github.com/asivery/rm-appload/releases/download/${APPLOAD_TAG}/appload-arm32.zip"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

need() {
    command -v "$1" >/dev/null 2>&1
}

fetch() {
    local url="$1" out="$2"
    echo "Downloading $(basename "$out")..."
    if need curl; then
        curl -fL --retry 3 -o "$out" "$url"
    elif need wget; then
        wget -O "$out" "$url"
    else
        echo "missing curl or wget" >&2
        exit 1
    fi
}

remote_sh() {
    ssh "$RM2_SSH" "$@"
}

remote_put() {
    scp -O "$@"
}

confirm() {
    [ "${RM2_ASSUME_YES:-0}" = "1" ] && return
    cat <<EOF
This will install experimental arm32 xovi + AppLoad on:
  $RM2_SSH

It writes under /home/root/xovi, starts xovi once, and does not enable boot
persistence. A rollback script will be written to:
  /home/root/riddle-rm2-appload-rollback.sh

Continue? [y/N]
EOF
    read -r answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled."; exit 1 ;;
    esac
}

echo "Checking SSH access..."
remote_sh true

echo "Checking tablet model..."
model="$(remote_sh "cat /proc/device-tree/model 2>/dev/null | tr -d '\\000' || true")"
echo "Tablet model: ${model:-unknown}"
if [ "${RM2_ALLOW_UNKNOWN_MODEL:-0}" != "1" ]; then
    case "$model" in
        *"reMarkable 2"*|*"reMarkable 2.0"*) ;;
        *)
            cat >&2 <<EOF
Refusing to install: this does not look like a reMarkable 2.
Set RM2_ALLOW_UNKNOWN_MODEL=1 to override.
EOF
            exit 1
            ;;
    esac
fi

confirm

fetch "$XOVI_URL" "$WORK/xovi-arm32.tar.gz"
fetch "$APPLOAD_URL" "$WORK/appload-arm32.zip"

echo "Uploading release artifacts..."
remote_put "$WORK/xovi-arm32.tar.gz" "$RM2_SSH:/tmp/xovi-arm32.tar.gz"
remote_put "$WORK/appload-arm32.zip" "$RM2_SSH:/tmp/appload-arm32.zip"

echo "Installing xovi + AppLoad..."
remote_sh "RM2_FORCE_XOVI_OVERWRITE='${RM2_FORCE_XOVI_OVERWRITE:-0}' bash -s" <<'REMOTE'
set -euo pipefail

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP=""

if [ -e /home/root/xovi ]; then
    BACKUP="/home/root/xovi.backup.$STAMP.tar.gz"
    echo "Backing up existing /home/root/xovi to $BACKUP"
    tar -czf "$BACKUP" -C /home/root xovi
    if [ "$RM2_FORCE_XOVI_OVERWRITE" != "1" ]; then
        echo "Existing /home/root/xovi found; backup created."
        echo "Rerun with RM2_FORCE_XOVI_OVERWRITE=1 to replace it."
        exit 2
    fi
    rm -rf /home/root/xovi
fi

tar -xzf /tmp/xovi-arm32.tar.gz -C /home/root
mkdir -p /home/root/xovi/extensions.d /home/root/xovi/exthome/appload

if [ -f /home/root/xovi/inactive-extensions/xovi-message-broker.so ]; then
    mv -f /home/root/xovi/inactive-extensions/xovi-message-broker.so /home/root/xovi/extensions.d/ 2>/dev/null || true
fi

cd /tmp
rm -rf appload-arm32-unz
mkdir appload-arm32-unz
unzip -oq appload-arm32.zip -d appload-arm32-unz || busybox unzip -o appload-arm32.zip -d appload-arm32-unz
cp -f appload-arm32-unz/appload.so /home/root/xovi/extensions.d/
if [ -d appload-arm32-unz/shims ]; then
    cp -rf appload-arm32-unz/shims /home/root/xovi/exthome/appload/
fi
if [ -d appload-arm32-unz/exthome ]; then
    cp -rf appload-arm32-unz/exthome/. /home/root/xovi/exthome/
fi
rm -rf /tmp/appload-arm32-unz /tmp/appload-arm32.zip /tmp/xovi-arm32.tar.gz

cat >/home/root/riddle-rm2-appload-rollback.sh <<EOF
#!/bin/sh
set -eu
/home/root/xovi/stock 2>/dev/null || true
pkill xochitl 2>/dev/null || true
if [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
    rm -rf /home/root/xovi
    tar -xzf "$BACKUP" -C /home/root
    echo "restored $BACKUP"
else
    rm -rf /home/root/xovi
    echo "removed /home/root/xovi"
fi
systemctl restart xochitl 2>/dev/null || true
EOF
chmod +x /home/root/riddle-rm2-appload-rollback.sh

echo "Starting xovi once..."
if [ -x /home/root/xovi/start ]; then
    systemd-run --unit=xovi-rm2-firststart --collect --service-type=oneshot /home/root/xovi/start 2>/dev/null \
        || /home/root/xovi/start
else
    echo "/home/root/xovi/start is missing" >&2
    exit 1
fi

echo "installed"
REMOTE

cat <<EOF
Experimental rM2 AppLoad setup complete.

Next:
  - AppLoad should now appear on the tablet.
  - AppLoad apps live in /home/root/xovi/exthome/appload/.
  - After reboot, start xovi manually with:
      ssh $RM2_SSH '/home/root/xovi/start'

Rollback:
  ssh $RM2_SSH '/home/root/riddle-rm2-appload-rollback.sh'
EOF
