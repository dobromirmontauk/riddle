# TODO — reMarkable 2 (qtfb) support

Status of the experimental rM2 path. See [README-RM2.md](README-RM2.md) for the
full flow and details. Background: a full install session got riddle built,
pushed, and xovi installed on an rM2, but hit a hard upstream blocker (below).

## 🚧 Blocker: AppLoad does not support reMarkable OS 3.28

No released AppLoad works on OS **3.28+**. AppLoad hooks a main-UI QML node that
the 3.28 UI refactor removed, so it panics and **crash-loops xochitl** during
xovi startup:

```
Couldn't resolve the hashed identifier ... required by AppLoad hooks in main UI
fatal runtime error: failed to initiate panic, error 9, aborting
```

This is upstream, not a riddle bug:
- rm-appload #62 — this exact error / root cause: https://github.com/asivery/rm-appload/issues/62
- rm-appload #59 — the only 3.28 fix, an **unmerged beta** PR: https://github.com/asivery/rm-appload/pull/59
- Vellum pins AppLoad to `remarkable-os >=3.26 <3.28`.

The test device is on **3.28.0.157**, so The Diary cannot launch there yet,
regardless of our bundle.

### Options (pick one) — [ ] not yet done

- [ ] **Downgrade the tablet to OS 3.27.x** — AppLoad v0.5.3 works there as
      released. Lowest-risk path to a working diary today.
- [ ] **Build `appload.so` from PR #59's `3.28` branch**
      (`rmitchellscott/rm-appload@3.28`) — needs the xovi toolchain + reMarkable
      SDK; beta quality; breaks on OS ≤3.27. No prebuilt asset exists.
- [ ] **Wait** for a tagged AppLoad release after 3.28 goes GA.

## ✅ Done (committed to this branch)

- Build + bundle the rM2 qtfb binary (`make build-rm2-qtfb` / `bundle-rm2-qtfb`).
- Fixed `oracle.env` never loading: added `scripts/appload-launch-rm2.sh`
  (qtfb launch wrapper) and pointed the manifest at it. Verified the wrapper
  ships in `dist/riddle-rm2/`.
- `setup-rm2-appload.sh` now builds the qt-resource-rebuilder **hashtab**
  (previously missing — AppLoad needs it) and refuses to auto-start xovi on
  unsupported OS.
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
