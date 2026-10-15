# Build status

15 October 2026. Local candidate `0.8.7-ww7.13`, internal build `20261015.13`.

The owner prefers short iterations. Two focused native UI tests passed using
isolated application defaults and temporary synthetic profile files. They verify
rename completion on focus loss, actual on-disk renaming, Enter submission with
focus returned to the document editor, Escape cancellation, no Enter-to-start
rename in the sidebar, and retained compact/neutral Combined-first navigation.
Full XCTest and storage suites were not run for ww7.13. Historical suite results
remain in the earlier verification documents.

Rename now uses SwiftUI FocusState changes and onSubmit/onExitCommand. Losing
focus commits without redirecting the clicked target; submission returns focus
to the existing native text editor. End the rename session before changing the
model, preventing duplicate submit/focus-loss processing. Removed the local NSEvent
keyboard monitor entirely; double-click, Rename and new-file requests start edits.
The remaining sidebar AppKit bridge only configures presentation. Retains all
ww7.5–ww7.12 changes, including the separator before Quit.

Build with `scripts/build-release.sh`: Xcode 27.0 (27A266a), macOS SDK 27.0,
arm64 + x86_64, minimum macOS 13.0. The packaged app records its exact source
commit. Archives are ad-hoc signed, without Developer ID signing or notarization.

Release target: [ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13),
with the accumulated commits since ww7.4, universal ZIP, BUILD-INFO.json and
SHA256SUMS. The owner explicitly authorized pushing all accumulated source changes
and publishing this release. Build/publication does not replace the installed app
or modify personal profiles/preferences. See [UI-REFINEMENTS.md](UI-REFINEMENTS.md).
