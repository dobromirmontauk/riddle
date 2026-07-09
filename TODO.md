# TODO — reMarkable 2 (qtfb) support

Status of the experimental rM2 path. See [README-RM2.md](README-RM2.md) for the
full flow and details. Background: a full install session got riddle built,
pushed, and xovi installed on an rM2, but hit a hard upstream blocker (below).

## 🚧 Blocker: released AppLoad does not support reMarkable OS 3.28

No released AppLoad works on OS **3.28.x**. AppLoad hooks a main-UI QML node that
the 3.28 UI refactor removed, so it panics and **crash-loops xochitl** during
xovi startup:

```
Couldn't resolve the hashed identifier ... required by AppLoad hooks in main UI
fatal runtime error: failed to initiate panic, error 9, aborting
```

This is upstream, not a riddle bug:
- rm-appload #62 — duplicate PR with this exact error / root cause: https://github.com/asivery/rm-appload/pull/62
- rm-appload #59 — the only 3.28 fix, an **unmerged beta** PR: https://github.com/asivery/rm-appload/pull/59
- Vellum pins AppLoad to `remarkable-os >=3.26 <3.28`.

The test device is on **3.28.0.157**. The branch now has a reproducible beta
AppLoad build path from rm-appload PR #59, but it still needs real-hardware
verification on this exact tablet/OS before treating the 3.28 path as working.

### Options (pick one) — [ ] not yet done

- [ ] **Downgrade the tablet to OS 3.27.x** — AppLoad v0.5.3 works there as
      released. Lowest-risk path to a working diary today.
- [x] **Build `appload.so` from PR #59's `3.28` branch**
      (`rmitchellscott/rm-appload@3.28`) — needs the xovi toolchain + reMarkable
      SDK; beta quality; breaks on OS ≤3.27. Built locally using upstream's
      `eeems/remarkable-toolchain:latest-rm1` Docker release path. A reproducible
      script now exists: `riddle/scripts/build-rm2-appload-pr59.sh`.
- [ ] **Wait** for a tagged AppLoad release after 3.28 goes GA.

## 🔬 Crash details (to start debugging)

Environment observed:
- Device: reMarkable 2, OS **3.28.0.157** (`/usr/share/remarkable/update.conf`;
  `/etc/os-release` IMG_VERSION=3.28.0.157, base 5.8.197 "scarthgap").
- xovi: `rm-xovi-extensions` **v19-23052026** (arm32), with `xovi.so`,
  `qt-resource-rebuilder.so`, `xovi-message-broker.so` in `extensions.d/`.
  `xovi.so` confirmed 32-bit ARM (not an arch mismatch).
- AppLoad: **v0.5.3** (arm32), `appload.so` in `extensions.d/`.
- hashtab built for this OS: 20183 entries (so qt-resource-rebuilder is fine).

Reproduce / observe the crash directly (bypasses systemd + the SSH
mount-namespace issue — runs xochitl in the foreground with the preload):

```sh
ssh root@10.11.99.1
systemctl stop xochitl
XOVI_ROOT=/home/root/xovi/services/xochitl.service/ \
  LD_PRELOAD=/home/root/xovi/xovi.so \
  QML_DISABLE_DISK_CACHE=1 \
  /usr/bin/xochitl 2>&1 | head -n 40
# restore the UI afterward:
systemctl start xochitl
```

Observed output (trimmed):

```
[qmldiff]: Set system version to 3.28.0.157
[qmldiff]: Iterating over directory .../exthome/qt-resource-rebuilder/
[qmldiff]: Hashtab loaded! Cached 20183 entries
[qmldiff]: Configured hashtab rules.
called `Result::unwrap()` on an `Err` value: Couldn't resolve the hashed
identifier 4073320026945606142 required by AppLoad hooks in main UI
fatal runtime error: failed to initiate panic, error 9, aborting
```

Root cause / where to look:
- xovi.so and qt-resource-rebuilder load fine; **only AppLoad's main-UI hook
  fails**. So debugging is scoped to AppLoad's QML hook targets vs the 3.28 UI.
- AppLoad's hook lives in `xovi/template/appload.qmd` (compiled into
  `appload.so`). It targets a sidebar/navigator QML node that the 3.28 UI
  refactor moved/removed, so the identifier hash `4073320026945606142` no longer
  resolves. The hashtab is not the problem.
- The fix is a single-file change to `appload.qmd` — see PR #59's diff
  (`rmitchellscott/rm-appload@3.28`) for the updated hook target. Because the
  `.qmd` is compiled into `appload.so`, a source rebuild of AppLoad is required
  (no prebuilt 3.28 asset exists).
- Same class of breakage recurred at prior UI refactors: rm-appload #40 (3.26),
  #48/#49 (3.27).

Recovery if the UI is ever wedged (SSH always works):

```sh
ssh root@10.11.99.1 '/home/root/riddle-rm2-appload-rollback.sh'   # full revert
# or minimally clear any preload drop-in and restart:
ssh root@10.11.99.1 'rm -rf /etc/systemd/system/xochitl.service.d/00-xovi.conf; \
  systemctl daemon-reload; systemctl restart xochitl'
```

## ✅ Done (committed to this branch)

- Build + bundle the rM2 qtfb binary (`make build-rm2-qtfb` / `bundle-rm2-qtfb`).
- Fixed `oracle.env` never loading: added `scripts/appload-launch-rm2.sh`
  (qtfb launch wrapper) and pointed the manifest at it. Verified the wrapper
  ships in `dist/riddle-rm2/`.
- `setup-rm2-appload.sh` now builds the qt-resource-rebuilder **hashtab**
  (previously missing — AppLoad needs it), refuses unsupported AppLoad/OS
  pairings before upload, and writes a compatibility marker checked by
  install/smoke scripts.
- Documented the SSH mount-namespace gotcha (xovi must be started from the
  tablet, not over SSH) and the OS 3.28 break in `README-RM2.md`.
- Verified the oracle path works on-device (`riddle --oracle-test`): reaches the
  configured OpenAI-compatible endpoint and authenticates.

## 📋 Remaining, once on a supported OS

- [ ] Get xovi running from the tablet's own context — install
      [xovi-tripletap](https://github.com/rmitchellscott/xovi-tripletap)
      (triple-press power). `xovi/start` over SSH does not inject.
- [ ] Push the current bundle and launch The Diary via AppLoad (Reload → The Diary).
- [ ] End-to-end verify: write on the page, confirm Tom replies (needs a funded
      key in `oracle.env`).
- [ ] Consider upstreaming the qtfb launch-wrapper pattern.

## 🔐 Housekeeping

- [ ] **Rotate the OpenAI API key** — it was printed in plaintext during the
      install session, so treat it as compromised.
