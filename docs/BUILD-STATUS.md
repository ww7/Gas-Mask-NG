# Build status

15 October 2026. Integration source is prepared; the full application build is
waiting for installation of Xcode on this Mac.

Repository: [ww7-forks/gasmask](https://git.ww7.work/ww7-forks/gasmask), private,
default branch `main`. The organization was created for this fork. Branch `upstream`
preserves the exact upstream base. Forgejo Actions is disabled because the existing
server runner is Linux; builds and tests use the local Mac.

## Fresh evidence

- Upstream base and all seven open PR heads fetched directly from GitHub.
- `scripts/test-storage.sh`: **28 assertions passed**, using temporary fixtures.
- Clang syntax checks passed for FileUtil, Util and NotificationHelper with the
  installed macOS SDK.
- Xcode project and property-list syntax validated with `plutil`.
- Project object references checked: 65 app sources, 19 XCTest sources, no missing
  object references or duplicate source entries. Both the restored popover and
  newer performance tests retain their own Xcode IDs.
- All seven PR heads are ancestors of `main`; the snapshot still matched GitHub
  on a second API check after integration.
- Swift syntax parsing and shell syntax checks passed. The compiled DNS script
  matches its source.
- Initial code commit `f0fbdc4c0f889f534245959f3d851a619be79960` was pushed and
  verified through remote refs. Subsequent commits may update this status file.
- `scripts/build-release.sh` correctly reports the missing full Xcode; no `.app`
  or release archive has been produced yet.
- Full Release build, XCTest suite, archive signature/architecture checks and
  real application UI/privileged-operation acceptance are still pending.

Next commands after Xcode is installed and initialized:

```sh
scripts/test.sh
scripts/build-release.sh
```

The installed Gas Mask application, live profiles and `/etc/hosts` have not been
modified by this integration work.
