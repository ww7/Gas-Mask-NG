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

Verified follow-up: all 145 XCTest tests and all 28 storage assertions passed.
Native fixture interaction moved Development below Production, added Work
(5 to 6 included files), and removed QA (6 to 5). The composition was marked
unsaved and regenerated the preview. The floppy-disk icon rendered in the native
toolbar. Icons-only persistence was checked across focus/refresh and a recreated
window with isolated defaults. Active-save/restore tests intercepted the concrete
NSTask implementation and observed only four noninteractive cache flushes;
inactive saves launched none. Live hosts/profile hashes remained unchanged.

## ww7.4: compact Combined sidebar

| Request | Boundary and verification contract |
| --- | --- |
| Use a standard Save icon | Replace the custom vector with SF Symbols `internaldrive`, matching the other toolbar icons |
| Put composition on the right | Horizontal split between the text editor and a narrow right sidebar; check pane geometry in light/dark and compact windows |
| Compact rows without counts | 22-point native rows, no numbering or selected/total count; grip, removal icon, then filename |
| Drag to reorder | Native local NSTableView insertion, autoscroll and cancellation; only the grip starts dragging. No composition mutation before an accepted drop; reject foreign/cross-profile drags |
| Keep add/remove and persistence | Compact + menu in the sidebar header. Remove only membership. Verify both directions, insertion after the last row, no-op/invalid drops, generated content and save/reload order |

Tests use synthetic profiles and isolated defaults. Installation is a separate
owner-authorized step with a backup of the existing app, both profile stores and
the effective preference domain. Preserve live profile bytes and preferences.

All 146 XCTest tests and all 28 storage assertions passed for ww7.4. The native
table is explicitly subscribed to store updates; the layout test also verifies
row count after removal/addition and visible first-row text after a same-count
reorder. A native drag put Production ahead of Development and the preview
followed that order. The interactive preview runner exited before finishing its
test; the subsequent complete automated suite passed all layout/refresh checks.

## ww7.5: menu order, checkmark and appearance

- Move the existing Show/Close Editor Window action to the top of the status-item
  menu, followed by a separator. Put Combined profiles before the other groups;
  retain the sidebar and next/previous profile order.
- Use SF Symbols `checkmark` for Save.
- Add General > Appearance with System, Light and Dark. Apply the saved choice at
  startup and changes immediately to NSApplication. System clears the application
  override and follows later macOS theme changes. No existing settings are rebased.
- Increase Preferences content height to fit the new dropdown.

The owner requested build-only verification and will perform functional testing.
Do not attribute ww7.4's 146 test results to this version. No test suite was run
for ww7.5. This is a local candidate; publication and installation are separate.

## ww7.6: show the active profile on startup

The initial profile-load notification can precede creation of the SwiftUI store.
The store now reads the active model object during initialization, after registering
observers, and selects it in both the editor and the native controller. The load
notification uses the same path when loading completes later. This is shared by
Local, Combined and Remote profiles and does not reactivate or rewrite any profile.
Build-only verification per the owner's preference; functional acceptance is manual.

## ww7.7: shortcut, compact settings/sidebar and Remote names

- Add Hotkeys > Show Editor Window using a new `showEditorWindowHotkey` key and
  MASShortcutBinder. It raises the editor rather than toggling it; no default
  combination is assigned, and the legacy boolean `showEditWindow` is untouched.
- Use equal 14-point top/bottom content padding and fit Preferences to the selected
  tab's natural height at 500 points wide. Keep its top edge fixed when switching
  tabs. Remove the oversized common content height and vertically centered forms.
- Set the left profile sidebar minimum row height to 24 points with 2-point vertical
  row insets; retain the existing compact Combined list.
- Name newly added Remote profiles from the final URL filename (including its
  extension), with hostname fallback for directory/root URLs and existing duplicate
  name suffixes. Preserve the source URL and all previously saved profile names.

Build-only verification as requested; no automated test suite run.

## ww7.8: immediate inline rename

- Request keyboard focus after inserting the inline name field, including Rename
  from the context menu and the existing new-profile notification path.
- Begin on double-click, Return or keypad Enter. Keep ordinary single-click list
  selection. Scope unmodified Return to the native focused left-sidebar table;
  exclude text fields, the document editor and the Combined composition table.
- Return commits once and Escape cancels. Changing the selected profile cancels
  an in-progress rename. Keep existing name validation and model notifications.

Build-only verification per the owner's preference; behavior acceptance is manual.
This local candidate is not installed or published automatically.

## ww7.9: settings margins and editor-window toggle

- Center the settings content as a 400-point block in the existing 500-point
  window. Apply shared 50-point horizontal and 26-point vertical padding in the
  presenter, preserving leading alignment and each control's label alignment.
  Continue fitting window height to the selected tab.
- Make the existing editor-window hotkey toggle the same open/close actions used
  by the menu. Preserve the shortcut defaults key and assigned combination; label
  it Show / Hide Editor Window. Widen the aligned Hotkeys label column to fit.

Build-only verification per the owner's preference. No automatic publication or
installation; functional acceptance remains manual.

## ww7.10: menu cleanup and Combined type icons

- Keep the profile section separated, but remove separators between the bottom
  actions. Order them Update Remote Files (when available), Settings…, Quit.
  Use Settings… in the application menu too, preserving action selectors.
- Add the same SF Symbols globe/doc distinction used in the main sidebar to
  Combined rows (after grip/remove, before the filename) and the Add File menu.
  Keep row height and drag-handle hit area unchanged.
- Default new Combined names to Combined, retaining duplicate-name suffixes and
  all existing names. Nested Combined composition remains excluded: the current
  concatenation has no cycle detection or deduplication across nested branches.

Build-only verification per owner preference; manual acceptance remains pending.
Publication and installation remain separate owner-authorized steps.

## ww7.11: compact, neutral left sidebar with Combined first

- Move the Combined section to the top for sidebar presentation only; keep model
  order and next/previous activation behavior unchanged, including empty groups.
- Reduce actual profile-row height to 20 points, remove vertical row insets and
  native inter-row spacing. The macOS sidebar list style imposed 32-point rows
  despite the previous requested minimum; use plain-list layout and hide separators.
- Draw the same rounded neutral selection background before and during inline
  rename; suppress the native emphasized row highlight while retaining native
  selection, keyboard navigation and accessibility. Keep text-selection color
  inside the name field controlled by macOS.

One focused synthetic-profile XCTest passed: Combined first, compact actual row
geometry, neutral row highlighting across rename and immediate field-editor focus.
Inspected the captured native rename image. Full test suites were not run. Universal
Release build and extracted-package signature verification are separate checks;
installation and publication remain owner-authorized steps.
