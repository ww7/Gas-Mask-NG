# Build status

## ww7.22 public prerelease candidate

16 October 2026. Version `0.8.7-ww7.22` / `20261016.22`.
Exact packaged application source: `219c16baaaf982795dc356808e9674aea3621039`.

- Final `scripts/test.sh`: **167 passed, 0 failed, 0 skipped, no runtime warnings**.
  Result: `build/TestResults-20261016T044510Z.xcresult`. Storage: **28** assertions;
  native sanitizer/peer checks: **80 × 3 = 240** assertions.
- Actual root acceptance **passed** on a disposable macOS 26.6.2 arm64 VM.
  Native approval/cancel, same-session reuse, legacy ACL conversion, root:wheel
  0644/empty ACL, crash EOF cleanup, fresh sessions and intervening-edit CAS
  conflict all passed. Wrong PID/CDHash, malformed requests, initial timeout,
  symlink and hard-link targets were refused. The release app also activated
  a synthetic list through the native administrator dialog. No owner data was
  copied into the guest; host hosts content and permissions were never changed.
  Reproduction: `Tests/IsolatedMac/README.md`;
  [sanitized evidence](verification/2026-10-16-isolated-root-acceptance.json).
- **14** shared Icon × Dock palette combinations, persistence/migration/fallback,
  template light/dark/1x/2x renderings and unchanged Dock visibility policy passed.
  Native guest UI confirmed the two aligned controls, exact preview, and immediate
  Mask → Balloon changes in both Dock and menu bar.
- Combined diagnostic text now explicitly describes cross-file address-set
  differences; identical repeats and IPv4/IPv6 pairs are not conflicts.
- The initial editor is presented after AppKit finishes launching, with activation
  deferred across an accessory-to-regular registration change. Guest UI actions
  through remote display required observing completion before the next action;
  no claim that remote-display latency itself is an application defect.

Verified universal ZIP:
`dist/0.8.7-ww7.22-219c16baaaf9/gas_mask_0.8.7-ww7.22_219c16baaaf9_universal.zip`.
SHA-256: `1ab5e613c9f479ee1591b96324cfd6d2fcf62e409f9a55f04d4c90fff51a04ab`.
All three executables are arm64+x86_64 with local hardened-runtime ad-hoc
signatures and only system dynamic dependencies. The packaged writer hash
exactly matches both the main executable pin and the writer tested as root.
ZIP inspection permits only repository default.hst/default preferences; no owner
lists/settings, backups, VM credentials or installation receipts are included.
BUILD-INFO.json includes the isolated evidence; SHA256SUMS covers both assets.

The owner authorized GitHub push and release publication after the isolated root
checks. Distribution remains a **prerelease**, without Developer ID/notarization;
physical Intel and sleep/wake/login/uninstall lifecycle checks remain open.
Earlier candidate statements below describe their historical state only.

Installed ww7.22 in `/Applications/Gas Mask.app`, byte-identical to the verified
archive. Profiles/settings files and effective defaults match the pre-install
backup. Host `/etc/hosts` contents, inode, ownership, mode and ACL are unchanged.
The app remains closed after installation. Previous app/data are backed up under
`~/Library/Application Support/ww7/Gas Mask Backups/2026-10-16T044842Z-ww7.22/`.
Private receipt: `build/install-ww7.22-receipt.json` (not a public asset).

## ww7.21 local security candidate

16 October 2026. Built and installed `0.8.7-ww7.21` / `20261016.21`.
Exact application source: `1814a9f1a9c670592556f83a813b9e9f630d3d84`.

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
- Xcode analyze completed (`build/security-delivery-analysis.log`); legacy non-ARC
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

Verified release archive:
`dist/0.8.7-ww7.21-1814a9f1a9c6/gas_mask_0.8.7-ww7.21_1814a9f1a9c6_universal.zip`.
SHA-256: `16a1f2b8dd40a5f9aa1f301f719b9c3f6b72b12a99f26839c151061d5b5666d0`.
Three Mach-O executables (app, session writer, login launcher) each contain arm64
and x86_64, carry local hardened-runtime signatures, and depend only on system
dynamic libraries. The exact packaged writer hash matches the executable's pin.
Archive inspection found only the repository default.hst and default preferences;
no owner lists, preferences, receipts or backups. Legal notices and GPL source
reference are included. BUILD-INFO.json and SHA256SUMS accompany the ZIP.

Installed bundle is byte-identical to the verified extracted archive. Profiles,
effective defaults, preference files, and system hosts contents/permissions were
unchanged. The app remains closed; no profile was activated. Original ww7.20 and
its data backup remain under `~/Library/Application Support/ww7/Gas Mask Backups/2026-10-16T032102Z-ww7.21/`;
the final replacement backup/receipt is under the `2026-10-16T034037Z-ww7.21/`
sibling. Local receipt: `build/install-ww7.21-receipt.json`. Earlier intermediate
ZIPs in dist are marked superseded. These backups/receipts are never release assets.
No source push or release upload was performed. Later documentation-only commits
may follow the packaged source revision; they do not change the installed code.

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
