# UI refinement: 15 October 2026

The owner supplied the new and legacy editor screenshots as visual references.
Verification uses synthetic profiles; personal screenshot data is not copied into
the repository or the release.

| Request | Implementation boundary | Verification contract |
| --- | --- | --- |
| Move Create / Remove / Save / Activate to the left | Leading toolbar placement and expanded native window toolbar; retain actions and enabled states | Render a wide editor and verify the action group remains on the leading side |
| Improve the Combined file checklist | Compact, left-aligned native checkboxes with file icons, section title and included count; retain membership and save behavior | Render selected/unselected rows and verify membership changes update Combined content |
| Stop text appearing through the bottom status bar | Reserve a separate footer row, use an opaque system background and clip the native text editor. Configure vertical resizing so long documents can scroll to their end | Verify the editor scroll view ends above the footer and long text really scrolls, in all three window/appearance states |
| Correct the menu bar preference wording | Show `Show Host File Name in Menu Bar`; preserve the existing preference key | Inspect General settings and confirm no preference migration is introduced |

Visual checks cover light/dark appearance and a compact editor window. Full XCTest,
storage checks and the universal Release build must pass before distributing the
updated build. The existing release remains available.

The test runner uses a dedicated bundle identifier so the test application's
preferences are separate from the installed app. Native interactive checks use
the `build/native-qa` app with a distinct identifier and temporary synthetic files.
