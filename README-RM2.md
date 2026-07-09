# Riddle on reMarkable 2

This branch adds experimental reMarkable 2 support for Riddle through
AppLoad/qtfb. It does not use the Paper Pro takeover/quill backend.

## Safety Model

The rM2 path is a windowed AppLoad app:

- Installs app files under `/home/root/xovi/exthome/appload/riddle-rm2/`.
- Uses AppLoad's qtfb framebuffer via `QTFB_KEY`.
- Does not replace `xochitl`.
- Does not install a persistent `riddle` service.
- Does not modify bootloader, partitions, or firmware.

The experimental AppLoad setup helper installs xovi/AppLoad under
`/home/root/xovi` and starts xovi once. It deliberately does not enable boot
persistence on rM2. After a reboot, start xovi manually:

```sh
ssh root@10.11.99.1 '/home/root/xovi/start'
```

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

This downloads upstream arm32 release artifacts, installs them under
`/home/root/xovi`, starts xovi once, and writes this rollback script:

```sh
ssh root@10.11.99.1 '/home/root/riddle-rm2-appload-rollback.sh'
```

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

## Start the App

On the tablet:

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
