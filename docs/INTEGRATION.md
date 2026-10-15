# Gas Mask: all-open-PR integration

Snapshot: 15 October 2026. Base: upstream `master` at
`7e0fa133a4584db5d465525e2812bda271e57893`.
The owner requested **all open PRs**, including drafts. Already merged PRs are
included through the upstream base; closed, unmerged PRs are outside this snapshot.
Immutable upstream PR heads are recorded in [upstream-open-prs.json](upstream-open-prs.json).

## PR decisions and verification contracts

| PR | Result | Dependencies and integration decision | Verification |
| --- | --- | --- | --- |
| [#162](https://github.com/2ndalpha/gasmask/pull/162) | Merged, optimized | Sort local profiles once after loading, preserving the PR's ascending name ordering. Shared model order reaches the sidebar, menu and next/previous shortcuts. | Review the sort after enumeration; full app tests and local-profile order smoke check. |
| [#183](https://github.com/2ndalpha/gasmask/pull/183) | Superseded | Its `Editor.xib` and `Cell.m` no longer exist. The current SwiftUI toolbar uses SF Symbols and the editor uses adaptive colors. Preserve those implementations. An `ours` merge records the reviewed PR head without restoring the obsolete UI. | Build and check light/dark UI on the current implementation. |
| [#193](https://github.com/2ndalpha/gasmask/pull/193) | Merged with migration | New profiles live under `~/Library/Application Support/Gas Mask/`. Existing profiles are copied through a staging directory and the saved active-profile path is rebased. Combined profiles reference type/name and remote metadata uses names, so neither needs rewriting. | Standalone migration tests verify copied bytes, retained originals, active selection, repeated launches, conflicting directories and failure fallback. |
| [#217](https://github.com/2ndalpha/gasmask/pull/217) (draft) | Superseded | The draft changes to a new ShortcutRecorder package but comments out two shortcut bindings and persistence. Upstream already replaced the old binary framework with a working MASShortcut package and SwiftUI recorder. Retain MASShortcut; record the draft head with an `ours` merge. Both replacement libraries cannot own the same shortcuts. | Existing `GlobalShortcutsTests` and `ShortcutRecorderViewTests`. |
| [#220](https://github.com/2ndalpha/gasmask/pull/220) | Adapted | Keep upstream's newer Apple Silicon support, icon assets (identical to the PR), macOS 13 minimum, SwiftUI windows, asynchronous text highlighting and network handling. Port the missing native Trash API and UserNotifications delivery. The privileged AppleScript mDNSResponder restart was removed in ww7.3 after it caused an authorization dialog on every save. Sorting and Application Support overlap #162/#193. | Compile changed Objective-C files; full universal build; app tests; manual Trash, notification and DNS checks remain separate. |
| [#239](https://github.com/2ndalpha/gasmask/pull/239) | Merged with project-file repair | Restore SwiftUI error/offline popovers and remove unused MAAttachedWindow. Its Xcode IDs collided with newer performance tests; assign new IDs while keeping both targets' sources. | Validate project object references and source membership; build/tests; click error/offline badges in both appearances. |
| [#243](https://github.com/2ndalpha/gasmask/pull/243) | Merged | Preserve the PR's separate build/test phases, Intel runner pin and performance thresholds. The inherited GitHub workflow is historical upstream configuration; the Forgejo Linux runner cannot build this macOS app. | Local test script uses build-for-testing then test-without-building and includes performance tests. |

All seven PR heads are ancestors of `main`. This records inclusion and resolution;
it does **not** mean that obsolete or mutually exclusive patches were replayed verbatim.
In #220, mechanical numeric/deprecation refactors and changes to deleted UI are
not replayed. In particular, its removal of RegexKitLite/VDKQueue is not appropriate
while current parser/file-watcher code still uses them. The unconditional privileged DNS restart is intentionally not retained: system-file
writes use upstream's noninteractive `dscacheutil -flushcache` behavior.
UserNotifications uses a retained delegate instance with the correct protocol.

## Storage and runtime boundaries

- Migration never deletes the legacy directory or overwrites an existing destination.
- After successful migration, edits go to Application Support; the old directory is
  a retained snapshot, not a synchronized second store.
- If both locations exist before migration and the saved active file still uses
  the legacy directory, keep the legacy store and log the conflict.
- If copying fails, keep the original path and selection. No system hosts change
  is required for migration.
- XCTest startup skips live profile loading/migration, downloads, shortcut
  registration and permission prompts. Standalone tests use temporary paths and
  a dedicated defaults suite.
- Activating/restoring a real profile still changes `/etc/hosts`. Initial write
  access may require authorization; subsequent saves do not run a privileged DNS
  restart. Build/test work uses temporary system-file fixtures.

## Fork build and updates

The first fork label is `0.8.7-ww7.1`, internal build `20261015.1`.
`scripts/build-release.sh` builds Release for both arm64 and x86_64, stamps the
source commit into the packaged app, signs it locally, checks the signature and
architectures, and creates a ZIP plus SHA256SUMS under `dist/`.

Full Xcode is required. Scripts automatically use `/Applications/Xcode.app` when
available, or respect an explicit `DEVELOPER_DIR`; they do not change the global
developer-directory selection. Run `scripts/test.sh` for the XCTest suite and
`scripts/test-storage.sh` for the standalone migration checks.

The fork does not start the upstream Sparkle updater, whose feed points at an old
HTTP endpoint. Settings links to this fork's Forgejo releases instead. The original
app identifier is preserved so profiles and preferences remain compatible. The
owner has authorized installing each successfully built and verified new version
in `/Applications/Gas Mask.app` (16 October 2026). Preserve profiles/preferences,
back up the previous app and data, and verify them after replacement. Installation
does not activate profiles or rewrite the system hosts file. Publishing remains a
separate owner-authorized action.

Release archives are ad-hoc signed locally; they are not Developer ID signed or
Apple notarized. A successful build/test run does not establish real privileged
hosts switching, DNS behavior, notification delivery or UI acceptance.
