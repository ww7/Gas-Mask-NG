# Build status

16 October 2026. Local candidate `0.8.7-ww7.15`, internal build `20261016.15`.

Two focused native UI tests passed on isolated synthetic profiles. Layout was
checked in light, dark and compact windows: the footer stays separate, long text
scrolls, the text container reserves 8 points vertically, and the sidebar uses
non-floating group labels. Inspected rendered images for the vertical sidebar
separator, removal of the header rule and readable dark-mode section labels.
The original monospaced font is also verified at initial display. Full XCTest
and storage suites were not run for ww7.15; prior ww7.14 menu/rename/zoom evidence
is in [sidebar/text-size verification](verification/2026-10-16-sidebar-text-size.json).

Changes: draw an explicit standard vertical divider at the trailing edge of the
navigation sidebar without intercepting resize/mouse input. Disable floating
native table group rows, which produced the stray horizontal rule below Combined.
Add an 8-point vertical text-container inset below the toolbar. Apply semantic
secondary color to sidebar section labels in either appearance. Compare the full
font when applying the text-size preference, retaining monospace on initial load
when the system's initial proportional font happens to share the same point size.
Retains all ww7.14 row, sorting, text-size and Remote-refresh controls.

Build with `scripts/build-release.sh`: Xcode 27.0 (27A266a), macOS SDK 27.0,
arm64 + x86_64, minimum macOS 13.0. The packaged app records its exact source
commit. Archives are ad-hoc signed, without Developer ID signing or notarization.

The last published release is
[ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13).
This build does not automatically replace the installed app or modify personal
profiles/preferences. See [UI-REFINEMENTS.md](UI-REFINEMENTS.md).
