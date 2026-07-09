# Riddle on reMarkable 2

This branch adds experimental reMarkable 2 support for Riddle through
AppLoad/qtfb. It does not use the Paper Pro takeover/quill backend.

> ⚠️ **Known issue — OS 3.28 breaks AppLoad.** No released AppLoad works on
> reMarkable OS **3.28+**: AppLoad hooks a main-UI QML node removed by the 3.28
> UI refactor, so it panics and **crash-loops xochitl** during xovi startup
> (`Couldn't resolve the hashed identifier ... required by AppLoad hooks in main
> UI`). This is upstream (rm-appload
> [#62](https://github.com/asivery/rm-appload/issues/62); the only fix is the
> unmerged beta PR [#59](https://github.com/asivery/rm-appload/pull/59)), not a
> riddle bug. Options: build `appload.so` from PR #59's `3.28` branch (beta),
> **downgrade to OS 3.27.x** (AppLoad v0.5.3 works there), or wait for a tagged
> release. `setup-rm2-appload.sh` detects the OS and refuses to auto-start xovi
> on 3.28+.
>
> Supported today: **OS 3.26–3.27** with `rm-xovi-extensions v19-23052026` +
> AppLoad `v0.5.3` (both pinned in `scripts/setup-rm2-appload.sh`).

## Safety Model

The rM2 path is a windowed AppLoad app:

- Installs app files under `/home/root/xovi/exthome/appload/riddle-rm2/`.
- Uses AppLoad's qtfb framebuffer via `QTFB_KEY`.
- Does not replace `xochitl`.
- Does not install a persistent `riddle` service.
- Does not modify bootloader, partitions, or firmware.

The experimental AppLoad setup helper installs xovi/AppLoad under
`/home/root/xovi` and builds the qt-resource-rebuilder hashtab. It deliberately
does **not** enable boot persistence, and does **not** start xovi (see below).

**xovi cannot be started reliably over SSH.** `xovi/start` writes its
`LD_PRELOAD` systemd drop-in onto a tmpfs; on this device each SSH session runs
in a private mount namespace, so that mount never reaches PID 1 and the preload
is silently dropped (xochitl restarts with no xovi). Start xovi from the
**tablet's own context** instead — recommended: install
[xovi-tripletap](https://github.com/rmitchellscott/xovi-tripletap) and
triple-press the power button. A reboot returns the tablet to clean stock.

> Do **not** hand-write a persistent `00-xovi.conf` on disk to force the
> preload: it works, but xovi then loads on every boot, and if any extension
> crashes xochitl (e.g. AppLoad on 3.28) you get a **bootloop**. xovi is
> tethered by design.

## Prerequisites

- reMarkable 2 with root SSH access.
- A host machine running Linux or macOS.
- On macOS, Homebrew is recommended because `make setup-rm2` installs Zig with
  `brew install zig`.

The examples below use USB networking:

```sh
root@10.11.99.1
```

Replace that with your tablet's Wi-Fi SSH target if needed.

## One-Time Host Setup

From the repo root:

```sh
cd riddle
make setup-rm2
```

Linux prefers `arm-linux-gnueabihf-gcc`. macOS uses Zig through
`cargo-zigbuild`.

Direct script equivalents are available when you do not want to use Make:

```sh
./build-rm2-qtfb.sh
./scripts/make-rm2-qtfb-bundle.sh
```

## One-Time Tablet AppLoad Setup

If `/home/root/xovi/exthome/appload` already exists, skip this section.

Check:

```sh
ssh root@10.11.99.1 'test -d /home/root/xovi/exthome/appload && echo AppLoad found || echo AppLoad missing'
```

Install experimental arm32 xovi + AppLoad:

```sh
cd riddle
make setup-appload-rm2 RM2_SSH=root@10.11.99.1
```

Direct script:

```sh
./scripts/setup-rm2-appload.sh root@10.11.99.1
```

For OS 3.28, first build the beta AppLoad artifact from upstream PR #59:

```sh
cd riddle
make build-appload-pr59-rm2
make setup-appload-rm2 RM2_SSH=root@10.11.99.1
```

Direct script:

```sh
./scripts/build-rm2-appload-pr59.sh
./scripts/setup-rm2-appload.sh root@10.11.99.1
```

That writes `dist/appload-pr59-3.28-arm32.tar.gz` and uses it automatically on
OS 3.28+. This is a beta path: PR #59 is unmerged and explicitly breaking for
OS <=3.27.

This downloads upstream arm32 release artifacts, installs them under
`/home/root/xovi`, builds the qt-resource-rebuilder hashtab (required by
AppLoad; runs the GUI briefly), and writes this rollback script:

```sh
ssh root@10.11.99.1 '/home/root/riddle-rm2-appload-rollback.sh'
```

It does not start xovi — do that from the tablet (see
[Safety Model](#safety-model)). On OS 3.28+ it also refuses to start xovi even
if asked (set `RM2_ALLOW_UNSUPPORTED_OS=1` to override, at your own risk).

If `/home/root/xovi` already exists, the setup script backs it up and stops.
To replace it after reviewing the backup message:

```sh
cd riddle
RM2_FORCE_XOVI_OVERWRITE=1 make setup-appload-rm2 RM2_SSH=root@10.11.99.1
```

## Build and Install Riddle

```sh
cd riddle
make install-rm2-qtfb RM2_SSH=root@10.11.99.1
```

Direct script:

```sh
./scripts/install-rm2-qtfb.sh root@10.11.99.1
```

This runs tests, builds the rM2 binary, stages `dist/riddle-rm2`, and copies it
to:

```text
/home/root/xovi/exthome/appload/riddle-rm2/
```

## Oracle key (oracle.env)

AppLoad launches the app named by `"application"` in the bundle manifest. The
rM2 manifest points at **`appload-launch-rm2.sh`**, a wrapper that sources
`oracle.env` (the API key) and then `exec`s the `riddle` binary with `QTFB_KEY`
inherited. Without that wrapper the oracle silently falls back to the (usually
absent) pi backend.

`oracle.env` is **not** shipped in the bundle (it holds your key). It must be
`KEY=value` lines — a bare key with no `RIDDLE_OPENAI_KEY=` prefix will not
work:

```sh
RIDDLE_OPENAI_KEY=sk-...
# RIDDLE_OPENAI_BASE=https://api.openai.com/v1   # optional
# RIDDLE_OPENAI_MODEL=gpt-4o-mini                # optional; must be vision-capable
```

Copy it next to the binary on the tablet and lock it down, then verify the
oracle end-to-end (needs the tablet's Wi-Fi — the USB `10.11.99.1` link is
host-only):

```sh
scp -O oracle.env root@10.11.99.1:/home/root/xovi/exthome/appload/riddle-rm2/oracle.env
ssh root@10.11.99.1 'chmod 600 /home/root/xovi/exthome/appload/riddle-rm2/oracle.env; \
  cd /home/root/xovi/exthome/appload/riddle-rm2; \
  set -a; . ./oracle.env; set +a; ./riddle --oracle-test icon.png'
```

## Start the App

First make sure xovi is running (start it from the tablet — see
[Safety Model](#safety-model); it cannot be started over SSH). Then on the
tablet:

1. Open AppLoad.
2. Tap Reload.
3. Tap The Diary.

Do not start the UI with `./riddle` over SSH. The UI needs AppLoad to provide
`QTFB_KEY`. SSH execution is only useful for diagnostics such as:

```sh
ssh root@10.11.99.1 '/home/root/xovi/exthome/appload/riddle-rm2/riddle --version'
```

## Hardware Smoke Test

Run:

```sh
cd riddle
make smoke-rm2-hardware RM2_SSH=root@10.11.99.1
```

Direct script:

```sh
./scripts/smoke-rm2-hardware.sh root@10.11.99.1
```

The smoke test:

- Installs a temporary AppLoad entry named `The Diary Smoke Test`.
- Asks you to launch it from AppLoad.
- Checks over SSH that the process is running.
- Asks you to write `smoke test` with the pen.
- Passes only after you confirm visible UI behavior.
- Removes the temporary AppLoad directory automatically.

Set `RM2_SMOKE_KEEP=1` if you want to keep the temporary install for debugging.

## Recovery

Stop a running Riddle process:

```sh
ssh root@10.11.99.1 'pkill riddle'
```

Remove the Riddle app:

```sh
ssh root@10.11.99.1 'rm -rf /home/root/xovi/exthome/appload/riddle-rm2'
```

Return xovi to stock mode, if the installed xovi bundle supports it:

```sh
ssh root@10.11.99.1 '/home/root/xovi/stock'
```

Rollback the experimental AppLoad setup:

```sh
ssh root@10.11.99.1 '/home/root/riddle-rm2-appload-rollback.sh'
```

Reboot as a last resort:

```sh
ssh root@10.11.99.1 'reboot'
```

## Current Limits

- rM2 support is AppLoad/qtfb only.
- Paper Pro takeover/quill remains Paper Pro-specific.
- AppLoad setup on rM2 is experimental.
- Boot persistence is intentionally not enabled by the rM2 setup helper.
- The smoke test requires human visual confirmation because the host cannot
  inspect the tablet screen or pen strokes automatically.
