# Build status

15 October 2026. Local candidate `0.8.7-ww7.12`, internal build `20261015.12`.

The owner prefers short iterations and will verify behavior manually. This candidate
adds one menu separator immediately before Quit Gas Mask and retains all ww7.11
sidebar refinements. Update Remote Files and Settings… remain adjacent.

Validation for ww7.12 is the universal Release build and extracted-package signature
and architecture checks. No test suite was run for this one-line menu change.
The [focused ww7.11 sidebar test](verification/2026-10-15-sidebar-compact.json)
and [ww7.4 suite results](verification/2026-10-15-sidebar.json) remain evidence for
those versions. The owner explicitly requested installation of this candidate with
profile/settings preservation and a backup of the previous application.

Build with `scripts/build-release.sh`: Xcode 27.0 (27A266a), macOS SDK 27.0,
arm64 + x86_64, minimum macOS 13.0. The packaged app records its exact source
commit. Archives are ad-hoc signed, without Developer ID signing or notarization.

The last published release remains
[ww7.4](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.4).
This local candidate does not change personal profiles, preferences or the
installed application during its build. See [UI-REFINEMENTS.md](UI-REFINEMENTS.md).
