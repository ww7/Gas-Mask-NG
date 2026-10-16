# Gas Mask NG

A modern continuation of [Gas Mask](https://github.com/2ndalpha/gasmask), the macOS
hosts-file manager originally created by Siim Raud / Clockwise.

**Development preview.** The public repository is the new home of this fork.
A stable public binary release and Homebrew cask are not available yet.
Current builds intentionally do not use Developer ID signing or notarization.
See the [release readiness review](docs/PUBLIC-RELEASE.md) and
[verification evidence](docs/BUILD-STATUS.md). The installed application is still
named **Gas Mask**, and retains its original preferences identifier and profile
locations to preserve existing installations.

## Features

- Local, downloaded Remote and ordered Combined lists.
- Compact sidebars, inline renaming, drag-to-reorder Combined sources and domain
  conflict inspection without silently changing source precedence.
- Remote updates on a configurable interval, manual per-file/all-file updates and
  the last successful update time. Failed downloads retain the last good content.
- Native document search, global search across Local and downloaded Remote lists
  without Combined duplicates, optional regular expressions and direct navigation.
- Syntax highlighting, line commenting, font zoom and customizable global shortcuts.
- System, light and dark appearance; a shared Mask or Balloon symbol for the
  menu bar and Dock, with seven approved Dock palettes for either symbol.

## Build and test

Requires macOS 13 or newer to run, and full Xcode 26 or newer to build. Package versions are pinned in
`Gas Mask.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

```sh
scripts/build-release.sh  # Universal arm64 + x86_64 ZIP; local ad-hoc signature
scripts/test.sh           # XCTest suite and temporary storage-migration fixtures
scripts/test-storage.sh   # Standalone migration tests
scripts/test-security.sh  # Sanitized native writer tests on temporary files
```

Build artifacts stay in ignored `dist/` and `build/` directories. Local builds are
not Developer ID signed or notarized. The old upstream Sparkle feed is disabled;
application updates are currently manual. Remote-list auto-update is separate.

## Data and permissions

Lists live in `~/Library/Application Support/Gas Mask`. Legacy data in
`~/Library/Gas Mask` is preserved during migration. Existing preferences use
`ee.clockwise.gmask`; renaming the project must not silently create a new store.
Activating a list changes `/etc/hosts`; selecting a list does not. An administrator-approved, session-scoped helper performs atomic changes to the
fixed system file. It does not grant permanent per-user write access or install a
root service. Background updates keep their validated cache without prompting;
if authorization is needed, Activate applies the pending list for that session.
Remote downloads require HTTPS, stay on the original origin through redirects,
and are limited to 32 MiB of validated UTF-8 hosts text. Existing HTTP sources are
retained but no longer downloaded; replace their URL with a trusted HTTPS source.

## Donations

All donations associated with this project are designated for Ukraine's
reconstruction, defense, and support for people affected by the war. Donations
are voluntary and do not change the GPL license. See [SUPPORT.md](SUPPORT.md).

## Contributing and security

Use [Issues](https://github.com/ww7/gas-mask-ng/issues) for bugs and feature requests.
Do not post real hosts files, private domains, credentials or sensitive logs.
See [SECURITY.md](SECURITY.md) for vulnerability reports.

The fork preserves the ancestry and authorship of seven upstream PRs open on
15 October 2026; see [integration decisions](docs/INTEGRATION.md). GPL-2.0-or-later
applies to the original application code; bundled third-party notices remain in
place. See [LICENSE](LICENSE).
