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

## Stable-release gates

1. **Privileged writes:** replace deprecated `AuthorizationExecuteWithPrivileges`
   and persistent per-user `/etc/hosts` write ACL with a narrowly scoped signed
   helper. Verify caller identity, fixed operation/path boundaries, atomic writes,
   symlink handling, failure rollback and one-time authorization behavior. The
   current legacy design is retained in the development build, not declared safe.
2. **Migration:** exercise the very old `/etc/gasmask` conversion separately. It
   still contains privileged remove/copy operations with weak exit-status handling.
   The modern home-directory migration has fixture coverage; that is not evidence
   for every historical privileged path.
3. **Remote input:** finish HTTPS/redirect policy and bounded-download review.
   HTTP is currently allowed and downloads use a completion-handler data task,
   without a streaming size cap. A selected remote source can supply arbitrary
   hosts mappings; users must trust sources before activation. No silent change
   to existing source URLs is made by this review.
4. **Legacy/vendor review:** inspect RegexKitLite/VDKQueue and verify their notices;
   a clean OSV result for two Swift packages is not a full supply-chain audit.
5. **Distribution:** enroll the owner's Apple Developer account, create Developer
   ID credentials, use hardened runtime and minimal entitlements, notarize/staple
   an exact universal artifact, and verify on a clean Mac. Do not commit credentials.
6. **Acceptance:** run a complete lifecycle on disposable macOS fixtures: first
   launch, authorization/cancellation, save/activate/restore, migration, login item,
   reconnect/sleep/wake, settings persistence and uninstall. Test arm64 and Intel.

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

Use one owner-controlled Support landing URL for future donation routing. The
page can list personal support and independently labelled funds; destination
changes should not require rebuilding the app. Until the owner supplies that URL,
the Donate action points directly to the requested UNITED24 page. No redirect or
personal donation destination has been invented or published.

A future umbrella organization/website can group revived applications while each
app keeps its own repository, issue tracker, changelog, security policy and release
artifacts. AI assistance is a development method, not a substitute for those gates.
