# Build status

## ww7.24 public prerelease and local installation

16 October 2026. Built and installed `0.8.7-ww7.24` / `20261016.24`.
Exact application source: `4819e5371e6f20215773b34a12fbfdcff61bbd23`.

- Functional suite: **152 passed, 0 failed, 0 skipped, no runtime warnings**.
  Performance cases excluded (`GASMASK_SKIP_PERFORMANCE=1`). Result:
  `build/TestResults-20261016T070425Z.xcresult`. Storage: 28 assertions;
  native sanitizer/peer fixtures: 240 assertions.
- A displayed Combined has one conflict counter, in Included Files, scoped to its
  own sources. Native fixture interaction opened the detail sheet while a different
  Local list was active: Combined had two conflicting domains, the active Local
  list had one, and no second conflict counter appeared in the footer. Details
  visibly retained Local/Remote source names, line numbers and within-file versus
  between-file labels. The native sheet assertion passed after inspection.
- A conflict inherited from one source still counts once in Combined. Identical
  repeated mappings, comments and separate IPv4/IPv6 mappings remain excluded.
- General's captured fixture window fits all three checkboxes horizontally.
  Icon/Color/Preview:/Apply flow directly without a right-alignment spacer; the
  caption and preview help say `Finder uses default icon.`. Frozen artwork
  verification passed for all 28 renditions.
- Editor and Included Files explicitly use small overlay scrollers with autohide.
  On this workstation the native default already preferred overlay; its regular
  width was 17 pt and small width 15 pt. No global scroll preference was changed.
- Gitleaks on the new application commit: no findings. Local code graph refreshed.

Verified archive:
`dist/0.8.7-ww7.24-4819e5371e6f/gas_mask_0.8.7-ww7.24_4819e5371e6f_universal.zip`.
SHA-256: `b759eeb53a0f8eaf5dd65a7adbb40341ce1a2a066ca855595516645221910d2e`.
All three executables contain arm64+x86_64, pass strict local signatures and use
only system dynamic dependencies. The unchanged writer bytes match the compiled
pin and the isolated root acceptance evidence from ww7.22; root tests were not
repeated for this UI-only pass. App/ZIP include only factory profiles/defaults,
without owner profiles, settings, backups, receipts or credentials.

The installed bundle matches the verified archive. Profiles, preference files and
effective defaults were preserved. System hosts bytes, inode, ownership, mode,
ACL and flags were unchanged. Previous app/data backup:
`~/Library/Application Support/ww7/Gas Mask Backups/2026-10-16T070951Z-ww7.24/`.
Private receipt: `build/install-ww7.24-receipt.json`. The installed app remains
closed. Installation did not activate profiles or write the system hosts file.
After explicit owner authorization, all product changes and release notes were
pushed to GitHub main. [GitHub CI 38872154375](https://github.com/ww7/gas-mask-ng/actions/runs/38872154375)
passed the functional suite and universal build at
`7a48bac79ca11c3cf6aa410fc44f2c984b5c9980`. The runner reported Node-runtime
and macOS-capacity annotations; neither was an application test failure.

Published [ww7.24](https://github.com/ww7/gas-mask-ng/releases/tag/v0.8.7-ww7.24)
as a prerelease with the exact verified ZIP, BUILD-INFO.json and SHA256SUMS.
All three downloaded GitHub assets matched local bytes; an anonymous public ZIP
download also matched the SHA-256 above. Only factory defaults are included.
Local ad-hoc signatures only, without Developer ID/notarization.

The sole previous GitHub release, ww7.22, was removed at the owner's request
only after ww7.24 became public. The prior description/assets were backed up and
checked locally in ignored `build/release-backups/github-before-ww7.24/`.
The ww7.22 Git tag and complete commit ancestry remain. A fresh public API check
listed only ww7.24 and returned 404 for the old release. Private delivery receipt:
`build/ww7-24-github-delivery-receipt.json`.

## ww7.23 installed local UI build

16 October 2026. Built and installed `0.8.7-ww7.23` / `20261016.23`.
Exact application source: `51fd0e340b0d0fbad52e72ee65b9c08d853db85a`.

- Functional suite: **151 passed, 0 failed, 0 skipped, no runtime warnings**.
  Performance cases excluded (`GASMASK_SKIP_PERFORMANCE=1`), not rerun for this UI
  pass. Result: `build/TestResults-20261016T060844Z.xcresult`. Storage: 28 assertions;
  native sanitizer/peer fixtures: 240 assertions.
- Conflicts include within-list and cross-file differences, canonical IPv6, aliases,
  comments, identical repeats and repeated Combined references. A domain counts
  once; IPv4/IPv6 are separate. Fixture checks keep active and displayed lists
  distinct. Native UI click opened Active Fixture details for its two IPs/lines
  while another list remained selected; the fixture assertion passed afterward.
- General's horizontal rows were visually reviewed on isolated test defaults.
  Mask/Heritage → Balloon/Bandera changed only preview before Apply; defaults
  remained Mask/Heritage. Apply persisted Balloon/Bandera and the confirmation
  appeared. Explicit Dock redraw and post-activation override restoration added.
- Search rendering places the source name directly next to text, with no visible
  line-number column. Existing native Return/search navigation and regex tests
  passed. Cached search over 100,001 lines took about 0.067 seconds.
- The primary app/Finder icon now exactly matches approved Mask/Heritage. All
  **28** primary/menu/Dock renditions match frozen source bytes. Dynamic Finder
  custom-icon mutation is deliberately absent: the temporary signed-bundle
  experiment failed strict signature verification with FinderInfo/resource forks.
  No helper signature check or bundle integrity rule was weakened.
- Gitleaks on the new commit: no findings. Local code graph refreshed.

Verified archive: `dist/0.8.7-ww7.23-51fd0e340b0d/gas_mask_0.8.7-ww7.23_51fd0e340b0d_universal.zip`.
SHA-256: `927e423ffff4bec79433952543d590138b653c52f386678e2ce0ac9dc892ccbd`. Three executables each contain arm64+x86_64,
strict local signatures pass, only system dynamic dependencies remain, and the
exact helper hash still matches both its main-executable pin and the writer
previously tested on disposable macOS. Factory defaults only: no owner profiles,
settings, backups, receipts or credentials in the app/ZIP.

Installation matched the verified bundle. Profiles/settings and effective defaults
were preserved; system hosts bytes, inode, ownership, mode, ACL and flags were
unchanged. The previous app/data remain under
`~/Library/Application Support/ww7/Gas Mask Backups/2026-10-16T061253Z-ww7.23/`.
Private receipt: `build/install-ww7.23-receipt.json`. The app remains closed after
installation. No profile activation or live system-file write was used for QA.
This pass does not push source or upload a new release; the latest public release
remains ww7.22. Local ad-hoc signatures only, without Developer ID/notarization.

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
