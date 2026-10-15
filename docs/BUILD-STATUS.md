# Build status

16 October 2026. Installed local build `0.8.7-ww7.18`, internal build `20261016.18`.

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

Universal Release build passed. The extracted archive's strict signature and all
seven Mach-O binaries were verified (arm64 + x86_64). Packaged source:
`e1a42127809da2f141b20da5c27081a2d71bd107`.
Archive SHA256: `3c7526b60c963e7e375c56d479ab8045e13c0a12e82e0eb26f2333ac10e62ab2`.

Installed ww7.18 over ww7.17 in `/Applications/Gas Mask.app`. The installed bundle
matches the archive. Profiles/settings file hashes, effective preferences and
`/etc/hosts` were unchanged. Previous app and data backup:
`~/Library/Application Support/ww7/Gas Mask Backups/2026-10-15T230233Z-ww7.18/`.
Receipt: `build/install-ww7.18-receipt.json`. The app was not launched after install.

The last published release remains
[ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13).
The owner authorizes installation of verified new versions with profiles/settings
preserved. Publication remains separate. Release archives are locally ad-hoc
signed, without Developer ID signing or notarization.
