# Build status

15 October 2026. Release `0.8.7-ww7.2` builds successfully with Xcode 27.0
(`27A266a`), macOS SDK 27.0, on macOS 27.0.1 Apple Silicon.

Repository: [ww7-forks/gasmask](https://git.ww7.work/ww7-forks/gasmask), private,
default branch `main`. The organization was created for this fork. Branch `upstream`
preserves the exact upstream base. Forgejo Actions is disabled because the existing
server runner is Linux; builds and tests use the local Mac.

Release: [v0.8.7-ww7.2](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.2).
The release tag identifies the source commit; the app's `WW7SourceRevision` and
archive filename record that same commit. ZIP, SHA256SUMS and build metadata
are attached to the release.

## Verification

- `scripts/test.sh`: **142 XCTest tests passed, 0 failed, 0 skipped**. Includes the
  performance tests. Execution used separate build-for-testing/test-without-building
  steps on arm64. Result bundle: `build/TestResults-20261015T170629Z.xcresult`.
- `scripts/test-storage.sh`: **28 assertions passed** using temporary fixtures.
- Release configuration compiled successfully for **arm64 and x86_64**.
- Architecture enumeration and `codesign --verify --deep --strict` passed.
- Packaging explicitly checks both architectures using `lipo -archs`; Xcode 27's
  `-verify_arch` invocation rejected multiple architectures despite the binary
  containing both slices.
- Source and package dependencies retain their pinned revisions. All seven
  upstream PR heads remain in the integrated history.
- Tests left `/etc/hosts` and both live Gas Mask profile directories identical
  to their recorded pre-test content hashes.
- Machine-readable test evidence: [verification/2026-10-15-ui.json](verification/2026-10-15-ui.json).

The compiler still reports inherited deprecation and integer-narrowing warnings.
There were no build errors or XCTest runtime warnings. The app is ad-hoc signed
locally, without Developer ID signing or Apple notarization. The x86_64 slice was
compiled and inspected; XCTest execution was on Apple Silicon.

The editor was checked in light/dark appearance and at compact size with synthetic
profiles. The 25-point footer remains outside the scrolling text view, including
at the end of a long document. Native checkbox interaction changed membership
and the included count. See [UI-REFINEMENTS.md](UI-REFINEMENTS.md).

Real privileged hosts switching, DNS restart and notification delivery remain
separate from the automated build/test evidence.
The installed Gas Mask app was not replaced.
