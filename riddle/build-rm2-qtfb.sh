#!/usr/bin/env bash
# Build the windowed AppLoad/qtfb flavor for reMarkable 2.
#
# This target is 32-bit ARM Linux. Install the Rust target with:
#   rustup target add armv7-unknown-linux-gnueabihf
# and provide a compatible linker, usually arm-linux-gnueabihf-gcc or the
# toolchain from Toltec / the reMarkable SDK.
set -euo pipefail
cd "$(dirname "$0")"

LINKER=${RIDDLE_RM2_LINKER:-arm-linux-gnueabihf-gcc}
export CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABIHF_LINKER="$LINKER"

cargo build --release --target armv7-unknown-linux-gnueabihf --features rm2 "$@"

OUT=target/armv7-unknown-linux-gnueabihf/release
echo "built: $OUT/riddle (rm2 qtfb; linker: $LINKER)"
