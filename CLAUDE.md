# CLAUDE.md

See [AGENTS.md](AGENTS.md) for repo development instructions.

For reMarkable 2 setup, build, install, smoke-test, and recovery details, read
[README-RM2.md](README-RM2.md).

Do not bypass the rM2 AppLoad compatibility guards. The setup script records the
checked OS/AppLoad pairing, and install/smoke-test paths must verify it with
`riddle/scripts/check-rm2-appload-compat.sh` before copying or launching apps.
