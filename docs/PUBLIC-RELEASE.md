# Public release readiness

16 October 2026. Public development home: https://github.com/ww7/gas-mask-ng.
This is a development preview, not a claim of a completed security audit or a
stable public binary release. The original authors and merged PR ancestry remain.

## Verified in this pass

| Boundary | Evidence | Limit |
| --- | --- | --- |
| Functional regressions | 136 XCTest cases passed; zero failures/runtime warnings; 28 standalone storage assertions | Wall-clock editor performance suite excluded; not physical Intel acceptance |
| Static analysis | Xcode analyze completed; legacy dead-store and non-ARC test-fixture retention warnings recorded in evidence | Not a zero-warning result or an exhaustive security audit |
| Current UI changes | Native Help/search inspected on synthetic lists; regex matching and invalid-pattern feedback verified | Owner acceptance remains separate |
| Remote scheduler | Timer fire, all-file scope, unchanged success, failure recovery and interval rescheduling tested with URLProtocol fixtures | No owner's live URL or `/etc/hosts` used |
| Search | 100,001 lines, three cached literal queries: about 0.08 seconds; UTF-16 navigation, regex and in-memory edits tested | Representative benchmark, not a universal latency guarantee |
| Secrets | Gitleaks 8.30.1 current tracked/untracked source snapshot: no findings; all-ref history: 166 non-empty commits scanned, eight findings triaged | Eight upstream XIB serialized Interface Builder keys are false positives; no credential values found; detection is not exhaustive |
| Dependencies | Sparkle updated from 2.9.0 to 2.10.0; OSV commit queries for pinned Sparkle/MASShortcut returned no advisories after upgrade | Advisory databases do not cover every vulnerability or all vendored code |
| Launch helper | Removed `/bin/sh -c` interpolation; `/usr/bin/open` receives an argument array | Login item needs a clean-machine live acceptance check |
| Updater trust | Fork still does not instantiate upstream Sparkle updater; manual link points to GitHub | A new signed appcast/key pair is not provisioned |

Sparkle 2.9.0 was flagged for CVE-2026-47121 and CVE-2026-47122. The upstream
[security advisories](https://github.com/sparkle-project/Sparkle/security/advisories)
and [2.10.0 release](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0)
were checked before upgrading. The old updater was disabled in this fork; that
reduces exposure but does not justify shipping an obsolete framework.

No intentional backdoor was found in the reviewed first-party startup, network,
launch and privileged-write paths. This is a scoped source review, not a proof
that all source and third-party binary behavior is free of malicious behavior.

GitHub CI [run 38827995962](https://github.com/ww7/gas-mask-ng/actions/runs/38827995962)
passed the functional suite and universal Release build on macOS 26 / Xcode 26.6.
The rename fixture explicitly establishes a foreground window before simulating
editing; its earlier inactive-window failure is retained in CI history. Local
one-test rechecking emitted a test-activation QoS diagnostic; evidence records it.
The runner's Node-runtime metadata warning is also recorded, not hidden.

## ww7.21 security candidate

The inherited privileged-write and unbounded/HTTP download paths have been
replaced. See [SECURITY-BOUNDARIES.md](SECURITY-BOUNDARIES.md) for operations,
caller authentication, atomic rollback, cache behavior, and trust limits.
RegexKitLite and VDKQueue are no longer linked: Foundation handles the remaining
logger pattern, and a native DispatchSource watches replacement/recreation.
Their historical sources and original notices remain in Git ancestry.

This candidate deliberately uses no Developer ID or notarization, per the owner's
current distribution policy. Local ad-hoc hardened-runtime signatures are needed
for Apple Silicon integrity and helper identity; they do not authenticate a
publisher. Apple Developer Program enrollment is deferred, not a prerequisite we
will silently reintroduce. No self-update appcast is enabled.

Remaining public-stability acceptance gates:

1. Complete the administrator-approval/cancellation and helper teardown lifecycle
   on a disposable macOS installation; verify the original root ownership, old
   ACL conversion, crash/restart and a second app session. Local native tests
   use temporary ordinary files, not a real root hosts target.
2. Exercise reconnect/sleep/wake, login item and uninstall on disposable profiles.
   Universal architecture inspection does not replace execution on physical Intel.
3. Review exact archive/source checksums and the clean data boundary before
   publication. Only bundled defaults may be included, never the owner's lists,
   preferences, backups or local verification receipts.
4. Obtain the owner's separate publication authorization. Preparing and installing
   a local candidate does not authorize pushing changes or uploading releases.

The absence of Developer ID means this is an explicitly unsigned-distribution
candidate, not a notarized download. Do not label it stable until the outstanding
lifecycle checks have evidence. Fresh local verification is in BUILD-STATUS.md;
older observations above remain the previous public baseline, not current totals.

## Distribution and naming

`Gas Mask NG` / `gas-mask-ng` is the working public project name. The installed
bundle remains `Gas Mask.app` for now; changing bundle identity or storage requires
an explicit compatibility migration, not a cosmetic rename.

A graphical `.app` belongs in a Homebrew **cask**, not a CLI formula. Start with
an owner-controlled `homebrew-tap` after a stable immutable GitHub release exists.
The cask needs the real download URL, SHA256, minimum macOS and actual app name.
Initially installation will use a qualified tap token (for example
`brew install --cask ww7/tap/gas-mask-ng`), not a promise that a bare token already
exists in Homebrew's official repository. No tap or cask has been published yet.

The project donation policy in [SUPPORT.md](../SUPPORT.md) designates all
associated donations for Ukraine reconstruction, defense and support for people
affected by the war, while preserving GPL rights.

Use one owner-controlled Support landing URL for future donation routing. The
page can list personal support and independently labelled funds; destination
changes should not require rebuilding the app. Until the owner supplies that URL,
the Donate action points directly to the requested UNITED24 page. No redirect or
personal donation destination has been invented or published.

A future umbrella organization/website can group revived applications while each
app keeps its own repository, issue tracker, changelog, security policy and release
artifacts. AI assistance is a development method, not a substitute for those gates.

The unused Sparkle framework and legacy upstream feed/keys were removed from
ww7.21. Ad-hoc third-party dynamic libraries are incompatible with strict
hardened-runtime library validation without a shared Developer ID Team ID.
The app retains manual GitHub release links instead of disabling library
validation. Remote-list updates use the separate first-party downloader. The
writer rejects callers with entitlements that allow library/DYLD/page-protection
bypasses as well as get-task-allow.
