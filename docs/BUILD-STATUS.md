# Build status

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
