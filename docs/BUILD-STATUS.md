# Build status

15 October 2026. Local candidate `0.8.7-ww7.8`, internal build `20261015.8`.

The owner requested a short iteration and will verify behavior manually. Validation
for this candidate is the universal Release build, package architecture and strict
local signature checks. No XCTest or storage test suite was run for ww7.8.
The prior [ww7.4 test evidence](verification/2026-10-15-sidebar.json) remains
historical evidence for that version, rather than a result for this candidate.

Changes: inline profile rename receives keyboard focus on first entry, including
context-menu and newly created profile requests. Double-click a sidebar row or
press Return/Enter with its native list focused to begin renaming; Return commits
and Escape cancels. The Return handler excludes text editing and the Combined
composition table. Selection changes cancel the pending inline edit. Retains all
ww7.7 shortcut, sizing, appearance and active-profile startup changes.

Build with `scripts/build-release.sh`: Xcode 27.0 (27A266a), macOS SDK 27.0,
arm64 + x86_64, minimum macOS 13.0. The packaged app records its exact source
commit. Archives are ad-hoc signed, without Developer ID signing or notarization.

The last published release remains
[ww7.4](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.4).
This local candidate does not change personal profiles, preferences or the
installed application during its build. See [UI-REFINEMENTS.md](UI-REFINEMENTS.md).
