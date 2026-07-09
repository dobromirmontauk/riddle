#!/usr/bin/env bash
# Build the draft rm-appload PR #59 arm32 AppLoad artifact for reMarkable OS 3.28.
#
# Output:
#   dist/appload-pr59-3.28-arm32.tar.gz
#
# Requirements:
#   docker
#
# This uses the same container/toolchain pattern as rm-appload's release
# workflow, but checks out PR #59 ("support for 3.28") and builds arm32.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${RM2_APPLOAD_328_TARBALL:-dist/appload-pr59-3.28-arm32.tar.gz}"
BUILD_ROOT="${RM2_APPLOAD_BUILD_ROOT:-dist/appload-pr59-build}"
SRC="$BUILD_ROOT/rm-appload"
XOVI="$BUILD_ROOT/xovi"
IMAGE="${RM2_APPLOAD_TOOLCHAIN_IMAGE:-eeems/remarkable-toolchain:latest-rm1}"

if ! command -v docker >/dev/null 2>&1; then
    echo "missing docker; install Docker or build PR #59 another way" >&2
    exit 1
fi

mkdir -p "$BUILD_ROOT" "$(dirname "$OUT")"

if [ ! -d "$SRC/.git" ]; then
    git clone https://github.com/asivery/rm-appload.git "$SRC"
fi
git -C "$SRC" fetch origin pull/59/head:pr-59-3.28
git -C "$SRC" checkout pr-59-3.28

if [ ! -d "$XOVI/.git" ]; then
    git clone https://github.com/asivery/xovi.git "$XOVI"
fi

docker run --rm \
    -v "$PWD/$SRC:/work" \
    -v "$PWD/$XOVI:/xovi" \
    -w /work \
    "$IMAGE" \
    bash -lc 'set -euo pipefail
        export XOVI_REPO=/xovi
        apt-get update
        apt-get install -y qt6-base-dev
        ln -sf /usr/lib/qt6/libexec/rcc /usr/local/bin/rcc
        . /opt/codex/*/*/environment-setup-*
        cd xovi
        ./make.sh
        cd ../shim
        rm -rf build
        mkdir build
        cd build
        cmake ..
        make
        cd /work
        rm -rf result-pr59-arm32
        mkdir -p result-pr59-arm32/shims
        cp xovi/appload.so result-pr59-arm32/
        cp shim/build/qtfb-shim.so shim/build/qtfb-shim-32bit.so result-pr59-arm32/shims/
        file result-pr59-arm32/appload.so
        tar -czf appload-pr59-3.28-arm32.tar.gz -C result-pr59-arm32 .
    '

cp "$SRC/appload-pr59-3.28-arm32.tar.gz" "$OUT"
echo "built: $OUT"
