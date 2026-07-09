#!/usr/bin/env bash
# Refuse to use an rM2 AppLoad install unless its recorded AppLoad build matches
# the tablet model and current OS version.
#
# Usage:
#   ./scripts/check-rm2-appload-compat.sh root@10.11.99.1
#
# Environment:
#   RM2_SSH=root@10.11.99.1
#   RM2_APPLOAD_DIR=/home/root/xovi/exthome/appload
#   RM2_ALLOW_UNKNOWN_MODEL=1
#   RM2_ALLOW_STALE_APPLOAD_MARKER=1
set -euo pipefail

RM2_SSH="${1:-${RM2_SSH:-root@10.11.99.1}}"
RM2_APPLOAD_DIR="${RM2_APPLOAD_DIR:-/home/root/xovi/exthome/appload}"
MARKER="$RM2_APPLOAD_DIR/.riddle-appload-compat"

remote_sh() {
    ssh "$RM2_SSH" "$@"
}

expected_compat() {
    case "$1" in
        3.2[6-7].*|3.2[6-7]) echo "os-3.26-3.27-appload-v0.5.3" ;;
        3.28.*|3.28) echo "os-3.28-appload-pr59" ;;
        *) echo "" ;;
    esac
}

echo "Checking rM2 AppLoad compatibility on $RM2_SSH..."

model="$(remote_sh "cat /proc/device-tree/model 2>/dev/null | tr -d '\\000' || true")"
echo "Tablet model: ${model:-unknown}"
if [ "${RM2_ALLOW_UNKNOWN_MODEL:-0}" != "1" ]; then
    case "$model" in
        *"reMarkable 2"*|*"reMarkable 2.0"*) ;;
        *)
            cat >&2 <<EOF
Refusing to continue: this does not look like a reMarkable 2.
Set RM2_ALLOW_UNKNOWN_MODEL=1 to override.
EOF
            exit 1
            ;;
    esac
fi

osver="$(remote_sh "grep -oE '[0-9.]+' /usr/share/remarkable/update.conf 2>/dev/null | head -n1 || true")"
echo "reMarkable OS: ${osver:-unknown}"
expected="$(expected_compat "$osver")"
if [ -z "$expected" ]; then
    cat >&2 <<EOF
Refusing to continue: reMarkable OS ${osver:-unknown} is not in this repo's
supported AppLoad matrix.

Supported pairings:
  - OS 3.26.x-3.27.x: released AppLoad v0.5.3
  - OS 3.28.x: beta AppLoad from rm-appload PR #59
EOF
    exit 1
fi

remote_sh "test -d '$RM2_APPLOAD_DIR'" || {
    echo "missing $RM2_APPLOAD_DIR; install xovi/AppLoad first" >&2
    exit 1
}

if ! remote_sh "test -f '$MARKER'"; then
    cat >&2 <<EOF
Refusing to continue: missing AppLoad compatibility marker:
  $MARKER

Run ./scripts/setup-rm2-appload.sh so the tablet gets the right AppLoad build
for OS $osver and records the checked pairing.
EOF
    exit 1
fi

marker="$(remote_sh "cat '$MARKER'")"
marker_os="$(printf '%s\n' "$marker" | sed -n "s/^RM2_OS_VERSION='\\(.*\\)'$/\\1/p" | head -n1)"
marker_compat="$(printf '%s\n' "$marker" | sed -n "s/^APPLOAD_COMPAT='\\(.*\\)'$/\\1/p" | head -n1)"
marker_kind="$(printf '%s\n' "$marker" | sed -n "s/^APPLOAD_KIND='\\(.*\\)'$/\\1/p" | head -n1)"

if [ "$marker_compat" != "$expected" ]; then
    cat >&2 <<EOF
Refusing to continue: installed AppLoad does not match this tablet OS.

Current OS:        ${osver:-unknown}
Expected pairing: $expected
Marker OS:         ${marker_os:-unknown}
Marker AppLoad:    ${marker_compat:-unknown}
Marker kind:       ${marker_kind:-unknown}

Run ./scripts/setup-rm2-appload.sh again to install the correct AppLoad build.
EOF
    exit 1
fi

if [ "$marker_os" != "$osver" ] && [ "${RM2_ALLOW_STALE_APPLOAD_MARKER:-0}" != "1" ]; then
    cat >&2 <<EOF
Refusing to continue: AppLoad was installed for OS ${marker_os:-unknown}, but
the tablet currently reports OS ${osver:-unknown}.

Even within the same compatibility family, AppLoad hooks are tied to the tablet
UI build. Rerun ./scripts/setup-rm2-appload.sh after OS upgrades.
Set RM2_ALLOW_STALE_APPLOAD_MARKER=1 only after verifying this exact OS build.
EOF
    exit 1
fi

echo "AppLoad compatibility OK: $marker_compat"
