# Build status

16 October 2026. Local candidate `0.8.7-ww7.16`, internal build `20261016.16`.

Four focused tests passed: targeted Remote refresh (success, unchanged response,
failure and recovery), rename/sort/focus and text zoom, compact neutral sidebar,
and editor layout in light/dark/compact windows. The Remote test uses URLProtocol
on a reserved `.test` host and temporary files. No live profiles or system hosts
were used. Full suites were not run. One XCTest runtime warning reports a QoS
priority inversion in the native UI test; there were no test failures.

Changes: singular context update with a separator and clicked-file scope; fix
stuck synchronization/error state after download failure; active profile bold with
a fixed leading checkmark instead of a green dot; Save arrow and Activate checkmark;
separate Create/Remove/Remote-refresh toolbar controls; equal 8-point editor margins.
See [verification](verification/2026-10-16-remote-context-toolbar.json) and
[UI-REFINEMENTS.md](UI-REFINEMENTS.md).

The last published release is
[ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13).
The installed version is ww7.15 pending completion of the ww7.16 release build.
The owner authorizes installation after each successfully built and verified new
version, preserving profiles/preferences. Publishing remains separate.
Release archives are locally ad-hoc signed, without Developer ID or notarization.
