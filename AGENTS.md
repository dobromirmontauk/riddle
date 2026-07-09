# AGENTS.md

Development guidance for AI agents working in this repository.

## Repository Layout

- `riddle/` is the Rust diary app. Most app changes belong here.
- `quill/` is the C/C++ takeover display host for Paper Pro. Treat it as a separate backend.
- `drawlab/` and `home/` are AppLoad bundles/demos. Do not modify them for riddle-specific work unless the task explicitly says so.

## Build Targets

- Paper Pro remains the default target.
- reMarkable 2 support is experimental and AppLoad/qtfb-only. Do not route rM2 through the takeover/quill path.
- From `riddle/`, use:
  - `make setup-rm2`
  - `make test`
  - `make build-rm2-qtfb`
  - `make bundle-rm2-qtfb`
  - `make install-rm2-qtfb RM2_SSH=root@10.11.99.1`
- On Linux, the rM2 cross-build prefers `arm-linux-gnueabihf-gcc`.
- On macOS, the rM2 cross-build uses Zig via `cargo-zigbuild`.

## Verification

- Run `cargo test` from `riddle/` after Rust changes.
- Run `make build-rm2-qtfb` from `riddle/` when changing rM2 build, qtfb, display geometry, or input parsing.
- `cargo fmt --check` may fail on existing upstream formatting. Do not reformat unrelated files just to satisfy rustfmt.

## Contribution Style

- Keep patches upstreamable and narrowly scoped.
- Preserve existing script-based project patterns. Prefer app-local scripts under `riddle/` or `riddle/scripts/`.
- Avoid changing Paper Pro takeover behavior when working on rM2 qtfb support.
- Do not commit local artifacts such as `.toolchains/`, `patches/`, `target/`, or staged bundles under `dist/`.
