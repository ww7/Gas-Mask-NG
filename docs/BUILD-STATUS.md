# Build status

15 October 2026. Local candidate `0.8.7-ww7.9`, internal build `20261015.9`.

The owner requested a short iteration and will verify behavior manually. Validation
for this candidate is the universal Release build, package architecture and strict
local signature checks. No XCTest or storage test suite was run for ww7.9.
The prior [ww7.4 test evidence](verification/2026-10-15-sidebar.json) remains
historical evidence for that version, rather than a result for this candidate.

Changes: center a 400-point preferences content block within the 500-point window,
with 50-point horizontal and 26-point vertical margins. Keep leading alignment
inside each tab and existing label/control alignment in Hotkeys. The editor-window
hotkey now toggles the existing Show/Close actions and is labeled Show / Hide
Editor Window; its stored shortcut is preserved. Retains the ww7.8 rename fixes.

Build with `scripts/build-release.sh`: Xcode 27.0 (27A266a), macOS SDK 27.0,
arm64 + x86_64, minimum macOS 13.0. The packaged app records its exact source
commit. Archives are ad-hoc signed, without Developer ID signing or notarization.

The last published release remains
[ww7.4](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.4).
This local candidate does not change personal profiles, preferences or the
installed application during its build. See [UI-REFINEMENTS.md](UI-REFINEMENTS.md).
