# Build status

16 October 2026. Candidate `0.8.7-ww7.20`, internal build `20261016.20`.

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

Universal packaging and installation evidence will be appended after verification.
No stable public release or Homebrew cask has been published.
