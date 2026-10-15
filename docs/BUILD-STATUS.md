# Build status

16 October 2026. Installed local build `0.8.7-ww7.17`, internal build `20261016.17`.

Active sidebar names now use regular weight and retain the leading checkmark.
Native toolbar spaces receive the navigation role to keep Create, Remove and
Remote Update in separate blocks in icon-only mode, with Save/Activate paired.
Two focused tests passed (layout and toolbar display-mode persistence). Inspected
rendered icon-only and icon-and-label snapshots, plus light/dark/compact geometry.
Tests used synthetic profiles; full suites were not repeated.
See [verification](verification/2026-10-16-toolbar-groups.json) and
[UI-REFINEMENTS.md](UI-REFINEMENTS.md).

Universal Release build passed; all seven Mach-O binaries contain arm64 and x86_64.
Verified the extracted archive's strict signature and exact packaged source
`7bc56ff5a0e1c43c22c26ef82cf2979548559cc9`.
Archive SHA256: `3016c2732702547d6826dceefc0ed77d9ef0024ff6781dc05ff1c86f5afdf990`.

Installed ww7.17 over ww7.16 in `/Applications/Gas Mask.app`. The bundle matches
the release archive. Profile/settings file hashes, effective defaults and
`/etc/hosts` remained unchanged. Previous app/data backup:
`~/Library/Application Support/ww7/Gas Mask Backups/2026-10-15T223845Z-ww7.17/`.
Receipt: `build/install-ww7.17-receipt.json`. The app was not launched after install.

The last published release remains
[ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13).
The owner authorizes installing each verified new build with profiles/settings
preserved; publication is separate. Archives are locally ad-hoc signed, without
Developer ID signing or notarization.
