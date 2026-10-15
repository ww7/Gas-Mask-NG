# Build status

15 October 2026. Local candidate `0.8.7-ww7.11`, internal build `20261015.11`.

The owner prefers short iterations and will verify behavior manually. One focused
native sidebar test passed on temporary synthetic profiles, checking Combined-first
ordering, a row height no greater than 22 points, zero inter-row spacing, neutral
row highlighting before/during rename, and immediate name-field keyboard focus.
The complete XCTest and storage suites were not run for ww7.11. The prior
[ww7.4 test evidence](verification/2026-10-15-sidebar.json) remains historical.

Changes: show the Combined section before Local and Remote in the left sidebar
without reordering the model or next/previous activation. Use 20-point rows with
zero vertical insets/spacing. Native sidebar style imposed 32-point rows on the
current macOS; use plain-list layout with hidden separators and a custom rounded
neutral selection background. Disable the native table's emphasized highlight so
row selection stays gray while the name field gains keyboard focus. Text selection
inside the name field keeps standard system behavior. Retains all ww7.10 changes.

Build with `scripts/build-release.sh`: Xcode 27.0 (27A266a), macOS SDK 27.0,
arm64 + x86_64, minimum macOS 13.0. The packaged app records its exact source
commit. Archives are ad-hoc signed, without Developer ID signing or notarization.

The last published release remains
[ww7.4](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.4).
This local candidate does not change personal profiles, preferences or the
installed application during its build. See [UI-REFINEMENTS.md](UI-REFINEMENTS.md).
