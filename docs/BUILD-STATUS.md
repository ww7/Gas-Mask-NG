# Build status

16 October 2026. Local candidate `0.8.7-ww7.19`, internal build `20261016.19`.

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

Universal build and installation pending; installed app is ww7.18.
The last published release remains
[ww7.13](https://git.ww7.work/ww7-forks/gasmask/releases/tag/v0.8.7-ww7.13).
The owner authorizes installation of verified new versions with profiles/settings
preserved. Publication is separate. Archives are locally ad-hoc signed without
Developer ID signing or notarization.
