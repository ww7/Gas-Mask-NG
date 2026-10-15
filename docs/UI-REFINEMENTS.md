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

Verified in light/dark appearance and a compact editor window. All 142 XCTest
tests, including performance and scrolling/layout regression checks, and all 28
storage assertions passed. The editor reserves 25 points for the opaque footer.
A live native checkbox click changed the included count from 5 of 6 to 6 of 6
and marked the Combined profile as unsaved. The existing release remains available.

The test runner uses a dedicated bundle identifier so the test application's
preferences are separate from the installed app. Native interactive checks use
the `build/native-qa` app with a distinct identifier and temporary synthetic files.

## Save, toolbar mode and Combined editing follow-up

| Request | Implementation boundary | Verification contract |
| --- | --- | --- |
| Recognizable Save icon | Template vector floppy-disk icon; retain Save action and Command-S | Inspect native toolbar at normal size, including icons-only mode |
| Stop repeated system-modification prompts | Remove the unconditional privileged AppleScript DNS restart from save/restore. Keep the existing noninteractive `dscacheutil -flushcache` and initial write-permission authorization | Repeated active-profile saves and restore against a temporary system-file fixture; intercept process launches; verify live hosts/profile hashes remain unchanged |
| Remember icons / labels choice | Observe and persist the native toolbar display mode; restore when the toolbar attaches, never reset on focus | Change to icons only, simulate focus/refresh, recreate the window with the same isolated defaults; switch back to icons and labels too |
| Edit Combined membership and order | Display the persisted ordered composition, Add File menu, remove and move-up/down buttons; generated text remains read-only | Add/remove/reorder, verify dirty state and generated content, save/reload including an empty list; native interaction against synthetic profiles |

The repeated prompt came from the PR #220 AppleScript port, which requested
administrator privileges after each successful system-file write. The owner's
existing hosts ACL already allowed writes. Removing that unconditional restart
restores the upstream noninteractive cache-flush behavior without changing file
permissions or weakening authorization when initial write access is needed.
Combined profile storage remains the same ordered `type/name` format.
