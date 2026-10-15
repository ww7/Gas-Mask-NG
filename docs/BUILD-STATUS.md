# Build status

16 October 2026. Local candidate `0.8.7-ww7.14`, internal build `20261016.14`.

The owner prefers short iterations. Two focused native UI tests passed with
isolated preferences and temporary synthetic files. They cover rename completion,
immediate alphabetical sidebar reordering with selection retained, compact/neutral
rows, and native View-menu Cmd+, Cmd-, Cmd0 plus Cmd= alias. Zoom works with document
or sidebar focus; it preserves the profile's saved state, text and on-disk bytes.
The File-menu refresh action and its image were checked. Full XCTest and storage
suites were not run for ww7.14.

The activity dot now follows the name column. A shared file-row layout retains the
file-type icon and column geometry during inline rename. Sort sidebar children by
localized natural name order without changing model activation order or Combined
composition. View-menu text-size commands persist 8–40 pt, with 12 pt reset; native
text views observe the preference and retain monospaced font/typing attributes.
Add Update Remote Files with icloud.and.arrow.down in File, the status-item menu,
Remote/Combined profile context menus, and the toolbar. All entry points use the
existing update-and-synchronize action for all remote profiles.

Build with `scripts/build-release.sh`: Xcode 27.0 (27A266a), macOS SDK 27.0,
arm64 + x86_64, minimum macOS 13.0. The packaged app records its exact source
commit. Archives are ad-hoc signed, without Developer ID signing or notarization.

The last published release is
[ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13).
This build does not automatically replace the installed app or modify personal
profiles/preferences. See [UI-REFINEMENTS.md](UI-REFINEMENTS.md).
