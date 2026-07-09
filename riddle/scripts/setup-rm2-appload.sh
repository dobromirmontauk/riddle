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
#   RM2_APPLOAD_328_TARBALL=dist/appload-pr59-3.28-arm32.tar.gz
#                                  Use beta AppLoad build for OS 3.28+.
set -euo pipefail

RM2_SSH="${1:-${RM2_SSH:-root@10.11.99.1}}"
XOVI_TAG="${XOVI_TAG:-v19-23052026}"
APPLOAD_TAG="${APPLOAD_TAG:-v0.5.3}"
XOVI_URL="https://github.com/asivery/rm-xovi-extensions/releases/download/${XOVI_TAG}/xovi-arm32.tar.gz"
APPLOAD_URL="https://github.com/asivery/rm-appload/releases/download/${APPLOAD_TAG}/appload-arm32.zip"
APPLOAD_328_TARBALL="${RM2_APPLOAD_328_TARBALL:-dist/appload-pr59-3.28-arm32.tar.gz}"
APPLOAD_KIND="release"

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

# AppLoad compatibility guard. AppLoad hooks the main-UI QML; that hook target
# was removed/moved in the reMarkable 3.28 UI refactor, so AppLoad v0.5.3
# crash-loops xochitl on 3.28+ ("Couldn't resolve the hashed identifier ...
# required by AppLoad hooks in main UI"). No released AppLoad supports 3.28 yet
# (see rm-appload issues #59/#62; Vellum pins remarkable-os <3.28). We still let
# the install proceed (it is harmless until xovi is started), but we refuse to
# START xovi on an unsupported OS so we never hand the user a bootloop.
osver="$(remote_sh "grep -oE '[0-9.]+' /usr/share/remarkable/update.conf 2>/dev/null | head -n1 || true")"
echo "reMarkable OS: ${osver:-unknown}"
APPLOAD_OS_SUPPORTED=1
case "$osver" in
    3.2[0-7].*|3.2[0-7]) ;;                 # 3.20–3.27: AppLoad v0.5.3 works
    "") APPLOAD_OS_SUPPORTED=0 ;;            # unknown — do not risk auto-start
    *)
        # 3.28+ (and anything newer) — unsupported by released AppLoad.
        APPLOAD_OS_SUPPORTED=0
        if [ -f "$APPLOAD_328_TARBALL" ]; then
            APPLOAD_KIND="pr59-3.28"
            APPLOAD_OS_SUPPORTED=1
            cat >&2 <<EOF

WARNING: reMarkable OS $osver is not supported by released AppLoad.
Using beta AppLoad artifact built from rm-appload PR #59:
  $APPLOAD_328_TARBALL

This is expected to break on OS <=3.27 and is beta quality.
EOF
        else
            cat >&2 <<EOF

WARNING: reMarkable OS $osver is NOT supported by any released AppLoad.
AppLoad v0.5.3 crash-loops xochitl on 3.28+. xovi + the diary bundle will be
installed, but xovi will NOT be auto-started (that is what crashes). Options:
  - run ./scripts/build-rm2-appload-pr59.sh and rerun this setup, or
  - downgrade to OS 3.27.x, or
  - wait for a tagged AppLoad release that supports your OS.
Set RM2_ALLOW_UNSUPPORTED_OS=1 to start xovi anyway (may bootloop the UI;
recover over SSH with the rollback script). See README-RM2.md.
EOF
        fi
        ;;
esac

confirm

fetch "$XOVI_URL" "$WORK/xovi-arm32.tar.gz"
case "$APPLOAD_KIND" in
    pr59-3.28)
        cp "$APPLOAD_328_TARBALL" "$WORK/appload-arm32.tar.gz"
        ;;
    release)
        fetch "$APPLOAD_URL" "$WORK/appload-arm32.zip"
        ;;
esac

echo "Uploading release artifacts..."
remote_put "$WORK/xovi-arm32.tar.gz" "$RM2_SSH:/tmp/xovi-arm32.tar.gz"
case "$APPLOAD_KIND" in
    pr59-3.28)
        remote_put "$WORK/appload-arm32.tar.gz" "$RM2_SSH:/tmp/appload-arm32.tar.gz"
        ;;
    release)
        remote_put "$WORK/appload-arm32.zip" "$RM2_SSH:/tmp/appload-arm32.zip"
        ;;
esac

echo "Installing xovi + AppLoad..."
remote_sh "RM2_FORCE_XOVI_OVERWRITE='${RM2_FORCE_XOVI_OVERWRITE:-0}' APPLOAD_KIND='$APPLOAD_KIND' bash -s" <<'REMOTE'
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
case "$APPLOAD_KIND" in
    pr59-3.28)
        tar -xzf appload-arm32.tar.gz -C appload-arm32-unz
        ;;
    release)
        unzip -oq appload-arm32.zip -d appload-arm32-unz || busybox unzip -o appload-arm32.zip -d appload-arm32-unz
        ;;
esac
cp -f appload-arm32-unz/appload.so /home/root/xovi/extensions.d/
if [ -d appload-arm32-unz/shims ]; then
    cp -rf appload-arm32-unz/shims /home/root/xovi/exthome/appload/
fi
if [ -d appload-arm32-unz/exthome ]; then
    cp -rf appload-arm32-unz/exthome/. /home/root/xovi/exthome/
fi
rm -rf /tmp/appload-arm32-unz /tmp/appload-arm32.zip /tmp/appload-arm32.tar.gz /tmp/xovi-arm32.tar.gz

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

echo "Building qt-resource-rebuilder hashtab (required by AppLoad; runs the GUI briefly)..."
# AppLoad hooks the main UI via qt-resource-rebuilder, which needs a hashtab
# built for THIS exact OS build. Safe on any OS: rebuild_hashtable preloads
# only qt-resource-rebuilder (not AppLoad), so it cannot hit the 3.28 AppLoad
# crash. It stops xochitl and does not restart it, so we start it again after.
if [ -x /home/root/xovi/rebuild_hashtable ]; then
    echo "" | /home/root/xovi/rebuild_hashtable \
        || echo "hashtab build failed; AppLoad will not load until it succeeds" >&2
    systemctl start xochitl 2>/dev/null || true
else
    echo "/home/root/xovi/rebuild_hashtable missing; skipping" >&2
fi

# We intentionally do NOT start xovi here. Over SSH each session gets a private
# mount namespace, so xovi/start's tmpfs systemd drop-in never reaches PID 1 and
# the LD_PRELOAD is silently dropped. xovi must be started from the tablet's own
# context (e.g. xovi-tripletap). See README-RM2.md.

echo "installed"
REMOTE

cat <<EOF
Experimental rM2 AppLoad setup complete (xovi + AppLoad installed, hashtab built).

xovi is NOT running yet, and it CANNOT be started reliably over SSH (each SSH
session gets a private mount namespace, so xovi/start's systemd drop-in never
reaches PID 1). Start it from the tablet instead:
  - Recommended: install xovi-tripletap and triple-press the power button.
    https://github.com/rmitchellscott/xovi-tripletap
  - AppLoad apps live in /home/root/xovi/exthome/appload/ (the diary is
    riddle-rm2/). After xovi is up: open AppLoad, tap Reload, launch The Diary.
EOF
if [ "${APPLOAD_OS_SUPPORTED:-1}" != "1" ] && [ "${RM2_ALLOW_UNSUPPORTED_OS:-0}" != "1" ]; then
cat <<EOF

!! Your OS ($osver) has no released AppLoad support — starting xovi will very
   likely crash-loop xochitl. Do not start xovi until you have a 3.28-capable
   AppLoad (build from rm-appload PR #59) or you downgrade the OS.
EOF
fi
cat <<EOF

Reboot returns the tablet to clean stock (xovi is not persisted). Rollback:
  ssh $RM2_SSH '/home/root/riddle-rm2-appload-rollback.sh'
EOF
