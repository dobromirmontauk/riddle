#!/usr/bin/env bash
# Stage a reMarkable 2 AppLoad/qtfb bundle into dist/riddle-rm2/.
set -euo pipefail
cd "$(dirname "$0")/.."

BIN=target/armv7-unknown-linux-gnueabihf/release/riddle
[ -f "$BIN" ] || { echo "build first: ./build-rm2-qtfb.sh" >&2; exit 1; }

rm -rf dist/riddle-rm2
mkdir -p dist/riddle-rm2
install -m 755 "$BIN" dist/riddle-rm2/riddle
install -m 644 external.rm2-qtfb.manifest.json dist/riddle-rm2/external.manifest.json
install -m 644 icon.png oracle.env.example settings.schema.json dist/riddle-rm2/

echo "staged: $(du -sh dist/riddle-rm2 | cut -f1) in dist/riddle-rm2/"
echo "copy with: scp -O -r dist/riddle-rm2 root@10.11.99.1:/home/root/xovi/exthome/appload/riddle-rm2/"
