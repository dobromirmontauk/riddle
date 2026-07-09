#!/bin/sh
# AppLoad (qtfb) entry point for reMarkable 2 — the windowed flavour.
#
# AppLoad launches this script with QTFB_KEY set in the environment; we resolve
# our own install dir, load oracle.env (the API key + oracle settings), then
# exec the riddle binary. QTFB_KEY is inherited, so riddle opens as a qtfb
# window inside xochitl.
#
# Unlike the Paper Pro takeover flavour (see appload-launch.sh /
# riddle-takeover.sh), the rM2 qtfb flavour NEVER stops xochitl — it is purely
# windowed. Without this wrapper the manifest would point straight at the bare
# binary and oracle.env would never be sourced, so the oracle always fell back
# to the (usually absent) pi backend.
set -eu

# Resolve our own dir so the bundle works wherever AppLoad drops it.
HERE=$(cd "$(dirname "$0")" && pwd)

# Oracle config lives next to this script. Format is KEY=value lines, e.g.
#   RIDDLE_OPENAI_KEY=sk-...
# (a bare key with no RIDDLE_OPENAI_KEY= prefix will NOT work). Without it,
# riddle falls back to the pi backend. See oracle.env.example.
if [ -f "$HERE/oracle.env" ]; then
    set -a
    . "$HERE/oracle.env"
    set +a
fi

cd "$HERE"
exec ./riddle "$@"
