# Build status

16 October 2026. Local candidate `0.8.7-ww7.17`, internal build `20261016.17`.

Active sidebar names now use regular weight and retain the leading checkmark.
Native toolbar spaces receive the navigation role to keep Create, Remove and
Remote Update in separate blocks in icon-only mode, with Save/Activate paired.
Two focused tests passed (layout and toolbar display-mode persistence). Inspected
rendered icon-only and icon-and-label snapshots, plus light/dark/compact geometry.
Tests used synthetic profiles; full suites were not repeated.
See [verification](verification/2026-10-16-toolbar-groups.json) and
[UI-REFINEMENTS.md](UI-REFINEMENTS.md).

Universal release build and installation are pending. The current installed build
is ww7.16. The last published release remains
[ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13).
The owner authorizes installing each verified new build with profiles/settings
preserved; publication is separate. Archives are locally ad-hoc signed, without
Developer ID signing or notarization.
