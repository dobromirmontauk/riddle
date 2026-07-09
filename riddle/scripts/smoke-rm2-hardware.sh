#!/usr/bin/env bash
# Hardware smoke test for the experimental rM2 AppLoad/qtfb build.
#
# This test copies the bundle to a temporary AppLoad app directory, asks you to
# launch it from the tablet, verifies the process is running, asks you to write
# on the screen, then removes the temporary app on exit. It does not start
# takeover mode and does not modify boot/system services.
#
# Usage:
#   ./scripts/smoke-rm2-hardware.sh root@10.11.99.1
#
# Environment:
#   RM2_SSH=root@10.11.99.1
#   RM2_APPLOAD_DIR=/home/root/xovi/exthome/appload
#   RM2_ALLOW_STALE_APPLOAD_MARKER=1
#                          Skip exact OS marker check after manual review.
#   RM2_SMOKE_KEEP=1       Keep the temp app directory for debugging.
#   RM2_SMOKE_NONINTERACTIVE=1
#                          Only run binary checks; skip UI launch/confirmation.
set -euo pipefail

cd "$(dirname "$0")/.."

RM2_SSH="${1:-${RM2_SSH:-root@10.11.99.1}}"
RM2_APPLOAD_DIR="${RM2_APPLOAD_DIR:-/home/root/xovi/exthome/appload}"
APP_ID="riddle-rm2-smoke-$(date +%s)"
REMOTE_DIR="$RM2_APPLOAD_DIR/$APP_ID"

cleanup() {
    if [ "${RM2_SMOKE_KEEP:-0}" = "1" ]; then
        echo "Keeping $RM2_SSH:$REMOTE_DIR"
        return
    fi
    echo "Cleaning up $RM2_SSH:$REMOTE_DIR"
    ssh "$RM2_SSH" "pkill -f '$REMOTE_DIR/riddle' >/dev/null 2>&1 || true; rm -rf '$REMOTE_DIR'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

need_bundle() {
    if [ ! -x target/armv7-unknown-linux-gnueabihf/release/riddle ]; then
        echo "missing rM2 binary; run make build-rm2-qtfb first" >&2
        exit 1
    fi
    if [ ! -d dist/riddle-rm2 ]; then
        ./scripts/make-rm2-qtfb-bundle.sh
    fi
}

need_bundle

echo "Checking tablet access..."
RM2_APPLOAD_DIR="$RM2_APPLOAD_DIR" ./scripts/check-rm2-appload-compat.sh "$RM2_SSH"

echo "Installing temporary smoke app $APP_ID..."
ssh "$RM2_SSH" "rm -rf '$REMOTE_DIR'; mkdir -p '$REMOTE_DIR'"
scp -O -r dist/riddle-rm2/. "$RM2_SSH:$REMOTE_DIR/"

echo "Patching manifest id to avoid colliding with a real install..."
ssh "$RM2_SSH" "sed -i \
    -e 's/\"id\": \"riddle-rm2\"/\"id\": \"$APP_ID\"/' \
    -e 's/\"name\": \"The Diary\"/\"name\": \"The Diary Smoke Test\"/' \
    '$REMOTE_DIR/external.manifest.json'"

echo "Verifying executable format on tablet..."
ssh "$RM2_SSH" "test -x '$REMOTE_DIR/riddle'; file '$REMOTE_DIR/riddle'"

echo "Verifying binary starts on tablet..."
ssh "$RM2_SSH" "cd '$REMOTE_DIR' && ./riddle --version"

echo "Verifying oracle-test error path does not crash..."
ssh "$RM2_SSH" "cd '$REMOTE_DIR' && ./riddle --oracle-test /tmp/nonexistent-riddle-smoke.png >/tmp/riddle-smoke.out 2>/tmp/riddle-smoke.err; code=\$?; cat /tmp/riddle-smoke.err; test \$code -ne 139"

if [ "${RM2_SMOKE_NONINTERACTIVE:-0}" != "1" ]; then
    cat <<EOF

Interactive check:
  1. On the tablet, open AppLoad.
  2. Tap Reload.
  3. Launch "The Diary Smoke Test".
EOF
    read -r -p "Press Enter after the smoke-test app is open on the tablet..."

    echo "Checking that the smoke-test app is running..."
    ssh "$RM2_SSH" "pgrep -af '$REMOTE_DIR/riddle' >/tmp/riddle-smoke-pgrep && cat /tmp/riddle-smoke-pgrep"

    cat <<'EOF'

Now write this on the tablet:
  smoke test

Then rest the pen and wait for the diary to drink the ink. A successful UI
check means:
  - your pen strokes appeared in the app,
  - the page changed after the idle pause,
  - either a reply appeared, or a clear oracle/network/key error appeared.

EOF
    read -r -p "Did the UI behave as described? [y/N] " ok
    case "$ok" in
        y|Y|yes|YES) ;;
        *)
            echo "Interactive smoke test was not confirmed." >&2
            exit 1
            ;;
    esac
fi

cat <<EOF
Smoke test passed.

Covered:
  - SSH access
  - AppLoad directory exists
  - temporary bundle copy
  - rM2 executable format
  - binary startup on real hardware
  - oracle-test failure path exits without segfault
  - AppLoad UI launch, pen input, and visible response/error confirmation
  - automatic cleanup

Not covered:
  - automated visual inspection
EOF
