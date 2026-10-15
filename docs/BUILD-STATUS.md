# Build status

16 October 2026. Installed local build `0.8.7-ww7.16`, internal build `20261016.16`.

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
Universal Release build passed (arm64 + x86_64, minimum macOS 13). All seven
Mach-O binaries and the strict signature of the extracted archive were verified.
Packaged source: `ebe697a31107c0a984e68d9900f3867a667dc10b`.
Archive: `dist/0.8.7-ww7.16-ebe697a31107/gas_mask_0.8.7-ww7.16_ebe697a31107_universal.zip`.
SHA256: `e2b9639ebfa66221e9b1e645549f342c82761940ff8fe076d221a9294aad5ff6`.

Installed ww7.16 over ww7.15 in `/Applications/Gas Mask.app`. The installed bundle
matches the verified archive. Profiles/settings file hashes, effective preferences
and `/etc/hosts` were unchanged. Previous app/data backup:
`~/Library/Application Support/ww7/Gas Mask Backups/2026-10-15T223100Z-ww7.16/`.
Local receipt: `build/install-ww7.16-receipt.json`. The app was not launched for
manual acceptance after replacement.

The owner authorizes installation after each successfully built and verified new
version, preserving profiles/preferences. Publishing remains separate.
Release archives are locally ad-hoc signed, without Developer ID or notarization.
