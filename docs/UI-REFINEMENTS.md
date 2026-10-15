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

## ww7.12: separator before Quit

Restore one separator immediately before Quit Gas Mask; keep Update Remote Files
and Settings… adjacent. Retain the ww7.11 sidebar changes. Build/package validation
only for this one-line UI change. The owner authorized installation in Applications
with profiles/settings preserved and the prior app/data backed up.

## ww7.13: standard rename completion and editor focus

- Keep rename entry through double-click, the Rename context-menu action and the
  existing new-file request. Remove Enter-to-start and the local NSEvent monitor.
- Observe the name field's SwiftUI FocusState. Losing focus commits the draft and
  restores its normal row without moving focus away from the clicked target.
- Enter submits and explicitly requests focus in the existing AppKit document
  editor after SwiftUI removes the name field. Escape cancels. Finish the session
  before renaming the model so submit and blur cannot rename it twice.
- Keep the native sidebar appearance bridge limited to appearance; it registers
  no event handlers or keyboard hooks.

Two focused synthetic-profile native tests passed: rename lifecycle/focus and
compact Combined-first neutral sidebar presentation. The lifecycle test checks
actual temporary-file moves, document first responder, Escape cancellation and
Return in the native list. Full test suites were not run. Publication includes
all accumulated changes since ww7.4; the owner authorized push and release upload.

## ww7.14: stable sidebar rows, rename sorting, text size and Remote refresh

- Reuse one file-row layout for the normal label and inline name field. Keep the
  file-type icon and status columns stable; put the active dot after the name
  column. Preserve error/unsaved badges and accessible inline text-field editing.
- Sort each sidebar section by localized natural filename order on refresh and
  after rename. Preserve selected object identity, model next/previous activation
  order, section priority and persisted Combined membership order.
- Add View > Increase Text Size / Decrease Text Size / Actual Text Size with Cmd+,
  Cmd- and Cmd0, also accepting unshifted Cmd=. Native menu commands apply with
  sidebar or document focus. Store 8–40 pt in editorFontSize, default/reset 12 pt.
  Native text views observe the preference; font and typing attributes remain
  monospaced. Font changes do not modify profile contents or mark them unsaved.
- Add the standard icloud.and.arrow.down icon and Update Remote Files action to
  File, the existing status menu item, Remote/Combined profile context menus and
  the leading toolbar. Use the existing global update action rather than a new
  downloader. Disable toolbar/context refresh when no remote profiles are present
  or an update is already busy.

Two focused native tests passed on temporary fixtures. Checks include immediate
rename reordering in both directions, selected-row identity, retained rename focus,
compact neutral rows, native menu key dispatch (including sidebar focus), unchanged
profile bytes/saved state after zoom, typing-font reset and File-menu refresh wiring.
Inspected the native rename snapshot with the retained Combined icon and trailing
active dot. No full test suite or live remote download was run for this iteration.

## ww7.15: screenshot layout follow-up

- Draw a standard vertical Divider along the left sidebar's trailing edge. The
  overlay does not intercept mouse input or disable native split-view resizing.
- Disable floating group rows in the sidebar's native table. This removes the
  horizontal rule/shadow under the first Combined header while retaining section
  labels. Use the semantic secondary label color for readable dark-mode headers.
- Set the editor's vertical text-container inset to 8 points, preserving existing
  horizontal text padding and scrolling/opaque-footer behavior.
- Keep the initial editor font monospaced even when the default NSTextView font
  already has the saved point size; font preference application compares the full
  expected font rather than point size alone.

Two focused native tests passed: compact neutral sidebar presentation and editor
layout/scrolling in light, dark and compact windows. Rendered snapshots were
inspected with synthetic profiles. Eight-point text inset, initial monospace font,
non-floating headers, footer separation and composition geometry are asserted.
All ww7.14 changes remain included. On 16 October 2026 the owner authorized
installing every successfully built and verified new version in Applications,
preserving profiles and settings. This supersedes the earlier per-version
installation requirements above; publication remains separately authorized.
Installed ww7.15 over ww7.13 with a backup of the previous app and data. Verified
the installed bundle, signature, unchanged profiles/settings and system hosts.


## ww7.16: targeted remote refresh and toolbar presentation

Remote profile context menus show a separator and singular **Update Remote File**.
The action passes the clicked object through the main/remote controllers to the
existing download manager, independently of editor selection. Global menu/toolbar
refresh retains its all-files scope. Duplicate in-flight, offline, URL-less and
unmanaged-object updates are rejected. An error now decrements the active download
counter; an unchanged successful response clears previous download errors.

Active sidebar profiles use a regular-weight checkmark in a reserved leading slot
and a bold name. Inactive rows reserve the same space; the file-type icon remains
visible during inline rename. The green active dot is removed. Save uses the
standard SF Symbol `arrow.down`, and Activate uses `checkmark`. On macOS 26+ native
fixed toolbar spacers separate Create, Remove and Update Remote Files, followed by
Save/Activate. Older systems retain their individual native toolbar items.

Editor document margins are 8 points on both axes, with NSTextContainer's extra
horizontal line-fragment padding disabled. Four focused tests passed using
synthetic files and an intercepted reserved test URL; no live profiles, remote
servers or system hosts file were used. Rendered light/dark/compact and rename
snapshots were inspected. Full-suite/manual system-activation acceptance was not
performed. Evidence: `verification/2026-10-16-remote-context-toolbar.json`.


## ww7.17: icon-only toolbar grouping correction

Active sidebar names use regular weight; the leading checkmark remains the active
indicator. In ww7.16 icon-and-label snapshots appeared separated, but icon-only
mode merged Remove, Remote Update and Save/Activate into one glass background.
AppKit positions navigational items ahead of ordinary items. The fixed native
spaces now carry the navigation role too, so they stay between the leading actions.
Apply the role to existing spaces and through the scoped toolbar will-add observer;
no custom backgrounds, dimensions or replacement toolbar are introduced.

Inspected rendered icon-only and icon-and-label snapshots: Create, Remove and
Remote Update have separate native blocks, and Save/Activate stay paired. Two
focused tests passed for layout and display-mode persistence across focus refresh
and window recreation. Full suites were not repeated for this presentation fix.
Evidence: `verification/2026-10-16-toolbar-groups.json`.


## ww7.18: reopen, search, comments and useful footer

- Standard application reopen handling opens/raises the existing editor, including
  restoring a minimized window. It does not toggle the window closed.
- Move to Local sits with Remote Update and Open in Browser in the context menu.
  Toolbar actions have system help tooltips; the toolbar refresh label is Update.
- Replace the read-only lock and file count with the active profile name, unique
  hostname count and a question-mark help button. Count aliases after valid IPv4
  or IPv6 addresses, excluding comments, invalid-address lines and duplicate names
  (case-insensitive, normalized trailing dot). Counting runs on a cancellable worker.
  This is the current active profile content, not an audit of the live system file.
- The help sheet explains activation, read-only sources, update scopes and counts,
  and lists keyboard commands. Long explanations wrap in a scrollable area. It is
  also available from Help > Gas Mask Help.
- Cmd+F routes to the native NSTextView find bar even if the sidebar had focus.
  Existing next/previous/use-selection menu items use the document's native finder.
  Cmd+Shift+F opens global search over local and cached Remote content, excluding
  Combined previews to avoid duplicate results. Matching is case/diacritic
  insensitive, runs off the main thread and returns at most 300 matching lines.
  Click a result or press Return to open the file and select the match. Snapshot
  ranges use UTF-16 offsets and are checked against current text before selection.
- Edit > Toggle Comment (Cmd+/) follows the native responder chain and is disabled
  for read-only editors. It toggles the current or selected nonblank lines,
  preserves indentation/line endings, and uses NSTextView's normal undo/change
  pipeline. No automatic save or activation. Reset undo history on document
  replacement to prevent edits from one profile being undone into another.

Four focused tests passed for reopen, native find/comment/undo and global-result
navigation, search/count semantics, and light/dark/compact layouts. Native help and
search sheets were inspected on synthetic fixtures. The full suite and privileged
system-hosts activation were not repeated. Evidence:
`verification/2026-10-16-search-comment-help.json`.


## ww7.19: Combined conflicts and successful Remote-update time

Combined's right sidebar shows a conflict count (or No domain conflicts). Click
it to review each normalized domain, canonical IP addresses, source file/type and
line number. Analysis uses current source contents, including unsaved edits,
runs on a cancellable worker and never modifies addresses or composition order.
Compare address sets across distinct sources separately for IPv4 and IPv6. Normal
dual-stack pairs, identical sets (including reordered multi-address sets), comments,
invalid-address lines and repeated references to the same file do not produce
false conflicts. Normalize case, trailing hostname dots and IPv6 spellings.

Remote profiles show Last successful update above the editor, with a complete
localized timestamp in the tooltip. Remote icons in Included Files have the same
information. Unknown history says No successful update recorded. Reuse the
existing persisted `updated` metadata key; no profile migration is needed.
Changed content, unchanged content and HTTP 304 with an existing cache all count
as successful checks. Failures retain the previous timestamp. Updating metadata
notifies the views, and Included Files cells refresh their tooltips as it changes.
HTTP error responses and invalid UTF-8 are rejected rather than being mistaken
for successful updates. This timestamp reports a remote download/check, not an
audit of privileged application to the system hosts file.

Three focused tests passed with temporary fixtures: conflict semantics and source
locations, the Remote download/status/persistence lifecycle, and native layout in
light/dark/compact/icon-only windows. Used native UI to open/close the conflict
details and inspect the Remote header and icon tooltip. No live downloads, owner
profiles or system hosts were used by tests; full suites were not repeated.
Evidence: `verification/2026-10-16-conflicts-remote-time.json`.
