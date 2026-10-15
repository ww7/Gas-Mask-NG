# Build status

16 October 2026. Local candidate `0.8.7-ww7.18`, internal build `20261016.18`.

Four focused tests passed without runtime warnings. Checks cover application
reopen, native Find Next, comment/uncomment with undo/redo and read-only protection,
clearing undo between documents, global search navigation and UTF-16 offsets,
Combined exclusion and unique-host counts, plus existing layout modes.
Native help and global-search sheets were inspected with synthetic profiles.
Full suites and real privileged activation were not run.

The footer now shows the active profile, uncommented unique hostname count and
help. Toolbar buttons have help tooltips, refresh is labeled Update, and Move to
Local joins the Remote context actions. Cmd+F searches the displayed document;
Cmd+Shift+F searches local/downloaded Remote files; Cmd+/ toggles line comments.
See [verification](verification/2026-10-16-search-comment-help.json) and
[UI-REFINEMENTS.md](UI-REFINEMENTS.md).

Release build and installation pending; installed app is ww7.17.
The last published release remains
[ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13).
The owner authorizes installation of verified new versions with profiles/settings
preserved. Publication remains separate. Release archives are locally ad-hoc
signed, without Developer ID signing or notarization.
