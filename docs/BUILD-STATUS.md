# Build status

16 October 2026. Installed local build `0.8.7-ww7.19`, internal build `20261016.19`.

Combined now displays conflicting domains, source files/line numbers and addresses
in a review sheet. IPv4 and IPv6 are compared separately, with normalized domain
names and address sets. Source content/order is never changed by analysis.
Remote files show the last successful check time above the editor and in Included
Files icon tooltips. Successful unchanged checks update the timestamp; failures
preserve it. Existing persisted update history remains compatible.

Three focused tests passed without runtime warnings. Checks cover conflict edge
cases and source locations; changed/unchanged/304 Remote success, network/HTTP/text
failures and timestamp persistence; and existing layout modes. Native conflict
review and Remote timestamp UI were inspected on synthetic fixtures. Full suites
and privileged system-hosts activation were not repeated.
See [verification](verification/2026-10-16-conflicts-remote-time.json) and
[UI-REFINEMENTS.md](UI-REFINEMENTS.md).

Universal Release build passed. Verified the extracted archive's strict signature
and arm64 + x86_64 in all seven Mach-O binaries. Packaged source:
`dc66fe9c8de37db52df857f7589adf01c3a99b1f`.
Archive SHA256: `06a3f252c3c6e095e33227ea0dcabb4f6ad66cf18685c6688c002b17f60c67bc`.

Installed ww7.19 over ww7.18 in `/Applications/Gas Mask.app`, matching the archive.
Profile/settings file hashes, effective preferences and `/etc/hosts` were unchanged.
Previous app and data backup:
`~/Library/Application Support/ww7/Gas Mask Backups/2026-10-15T233125Z-ww7.19/`.
Receipt: `build/install-ww7.19-receipt.json`. The app was not launched after install.
A first preparation pass stopped before replacement when macOS flushed preferences;
the subsequent stable backup and installation passed all preservation checks.

The last published release remains
[ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13).
The owner authorizes installation of verified new versions with profiles/settings
preserved. Publication is separate. Archives are locally ad-hoc signed without
Developer ID signing or notarization.
