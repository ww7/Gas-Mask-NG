# Build status

## ww7.21 local security candidate

16 October 2026. Source prepared for `0.8.7-ww7.21` / `20261016.21`; archive and
installation evidence will be appended after packaging.

- Full `scripts/test.sh`: **166 passed, 0 failed, 0 skipped, no runtime warnings**,
  including the performance suite. Result: `build/TestResults-20261016T033541Z.xcresult`.
- Storage: **28** assertions. Native security: **80** assertions in each of three
  signature configurations (**240** total), with AddressSanitizer/UBSan. Matching
  peers with get-task-allow or disabled library validation are refused.
- Final ACL/stage-parent, nested authorization/cache updates and saved Combined
  order regressions passed; native Clang analysis emitted no diagnostics.
- Remote fixtures cover HTTPS, same-origin/five-hop redirects, oversized header/
  streaming responses, bad UTF-8/hosts/NUL/HTML/empty content, TLS failure,
  conditional 304, last-good caches/timestamps and retry/rearm scheduling.
- All **28** independent icon combinations, relaunch persistence, fallback,
  menu actions/names and unchanged Dock policy passed. Native status-button
  renderings cover light/dark, 1x/2x, with/without names (`build/icon-qa/`).
  All **18** shipped renditions exactly match the approved source bytes.
- Rename tests require the actual native field editor. The desktop declined
  programmatic activation in this run (printed in diagnostics); actual rename,
  blur/submit/cancel and editor-focus assertions passed.
- Xcode analyze completed (`build/security-approved-analysis.log`); legacy non-ARC
  test-fixture retention diagnostics remain. Release scheme analysis requires
  ENABLE_TESTABILITY=YES for its XCTest targets. This is not a zero-warning claim.
- Current-source Gitleaks: no findings. OSV: no advisories for pinned MASShortcut.
  Sparkle/feed/keys, RegexKitLite and VDKQueue are no longer linked. Hardened
  runtime library validation remains enabled.

This is a local **candidate**, without Developer ID/notarization. Disposable-Mac
admin approval/cancellation, crash teardown, old root ACL conversion, physical
Intel and sleep/wake/login-item acceptance remain before a stable public release.
No owner profile or live hosts file was used by fixtures. See
[SECURITY-BOUNDARIES.md](SECURITY-BOUNDARIES.md). Publication needs separate approval.

## Previous ww7.20 baseline

16 October 2026. Installed local build `0.8.7-ww7.20`, internal build `20261016.20`.

The editor default/reset size is 11 pt; explicit user font preferences are retained.
Unsaved list names use italics, with the active checkmark unchanged. Remote update
shortcuts are customizable, migrated from the legacy format when necessary, and
shown in all-Remote menu actions. The scheduler retires old timers and re-arms
after successful or failed downloads and interval changes.

Find in All Lists has optional regex, compact one-line results, debouncing and
worker-side cached snapshots. Three cached queries over 100,001 lines took about
0.08 seconds. Cold files are not read from the SwiftUI body. Help groups the global
shortcut note with the shortcut list. Donate points to UNITED24.

The app/About icon now derives from the actual menu-bar alpha silhouette, traced
into a vector and rendered yellow on blue. No generated replacement mask is used.
Report Issue, Home Page and manual update links point at `ww7/gas-mask-ng`.
Sparkle was upgraded to 2.10.0 after advisory checks; application auto-updates
remain disabled. The login helper launches `open` with arguments without a shell.

136 functional XCTest cases passed without failures or runtime warnings, plus 28
standalone migration assertions. The wall-clock editor performance suite was
excluded. Native Help and literal/regex search UI were reviewed using synthetic
fixtures. See [evidence](verification/2026-10-16-public-readiness.json) and
[stable-release gates](PUBLIC-RELEASE.md). No live profile or system-hosts activation
was used for acceptance.

Universal Release passed. Extracted ZIP signature verified; all seven Mach-O
binaries contain arm64 and x86_64. Packaged source:
`761f199a6fdcaf572e39add51a66962a821fb5ab`.
Archive SHA256: `485bd7e7fae90f1ae5df6b64097c4ead168de7476a7e49d300a6b8751470ae88`.

Installed ww7.20 over ww7.19 in `/Applications/Gas Mask.app`, matching the archive.
Profile/settings file hashes, effective preferences and `/etc/hosts` were unchanged.
Previous app and data backup:
`~/Library/Application Support/ww7/Gas Mask Backups/2026-10-16T000220Z-ww7.20/`.
Receipt: `build/install-ww7.20-receipt.json`. The app was not launched after install.
Public source and preserved PR ancestry are now on GitHub; Forgejo remains a mirror
remote, with no new release upload in this pass.
No stable public release or Homebrew cask has been published.

The first GitHub CI run selected the macOS 15 image's default Xcode 16 and failed
at compile time because `ToolbarSpacer` requires the macOS 26 SDK. The workflow
now uses `macos-26` (Xcode 26), while the app deployment target remains macOS 13.
CI results are tracked separately from the verified local installation.

GitHub CI [run 38827995962](https://github.com/ww7/gas-mask-ng/actions/runs/38827995962)
passed functional tests and the universal Release build on macOS 26 / Xcode 26.6,
at `e4cc728fcd1d7f44f582b71b98fdc80951aa7a50`. An earlier run passed 135/136 tests:
the rename fixture attempted editing in a non-key, inactive window. It now
establishes the normal foreground-click precondition and waits for the actual
field editor with a bounded timeout. This changed the test harness, not the app.
The local one-test recheck passed, with an AppKit test-activation QoS diagnostic
recorded in the evidence. GitHub also warns that checkout v4's Node 20 metadata is
being run on Node 24; the warning did not fail the job. No zero-warning CI claim.
