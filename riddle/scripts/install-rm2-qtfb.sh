#!/usr/bin/env bash
# Build and install the experimental reMarkable 2 AppLoad/qtfb bundle.
#
# Usage:
#   ./scripts/install-rm2-qtfb.sh root@10.11.99.1
#
# Environment:
#   RM2_SSH=root@10.11.99.1       Tablet SSH target, used when no arg is given.
#   RM2_APPLOAD_DIR=/home/root/xovi/exthome/appload
#   RIDDLE_RM2_LINKER=...         Override the ARM linker.
#
# This installs host build dependencies on Debian/Ubuntu when possible. It does
# not install xovi/AppLoad on the tablet; install those first.
set -euo pipefail

cd "$(dirname "$0")/.."

# Pick up rustup/cargo in non-login shells after a prior rustup install.
if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.cargo/env"
fi

RM2_SSH="${1:-${RM2_SSH:-root@10.11.99.1}}"
export RM2_SSH
export RM2_APPLOAD_DIR="${RM2_APPLOAD_DIR:-/home/root/xovi/exthome/appload}"

make setup-rm2
make install-rm2-qtfb RM2_SSH="$RM2_SSH" RM2_APPLOAD_DIR="$RM2_APPLOAD_DIR"

cat <<EOF
Installed The Diary for reMarkable 2.

On the tablet:
  1. Open AppLoad.
  2. Tap Reload.
  3. Launch The Diary.

If you need the oracle API key, edit:
  $RM2_SSH:$RM2_APPLOAD_DIR/riddle-rm2/oracle.env
EOF
