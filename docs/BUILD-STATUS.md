# Build status

15 October 2026. Local candidate `0.8.7-ww7.10`, internal build `20261015.10`.

The owner requested a short iteration and will verify behavior manually. Validation
for this candidate is the universal Release build, package architecture and strict
local signature checks. No XCTest or storage test suite was run for ww7.10.
The prior [ww7.4 test evidence](verification/2026-10-15-sidebar.json) remains
historical evidence for that version, rather than a result for this candidate.

Changes: the bottom menu actions are Update Remote Files, Settings… and Quit,
without separators between those actions. Preserve the separators around the
profile section. Rename the app-menu Preferences item to Settings as well.
Show standard globe/doc type icons in the Combined sidebar and Add File menu.
New Combined profiles start with the shorter name Combined (existing names stay
unchanged). Nested Combined profiles remain excluded from composition. Retains
the ww7.8 rename and ww7.9 settings-spacing/hotkey-toggle changes.

Build with `scripts/build-release.sh`: Xcode 27.0 (27A266a), macOS SDK 27.0,
arm64 + x86_64, minimum macOS 13.0. The packaged app records its exact source
commit. Archives are ad-hoc signed, without Developer ID signing or notarization.

The last published release remains
[ww7.4](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.4).
This local candidate does not change personal profiles, preferences or the
installed application during its build. See [UI-REFINEMENTS.md](UI-REFINEMENTS.md).
