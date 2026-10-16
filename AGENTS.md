# Gas Mask ww7 fork

Project knowledge and PR decisions live in [docs/INTEGRATION.md](docs/INTEGRATION.md).
Current verification evidence is in [docs/BUILD-STATUS.md](docs/BUILD-STATUS.md).

The fork integrates a snapshot of all open upstream PRs while retaining the newer
SwiftUI architecture. `upstream` is read-only GitHub; `origin` is the public GitHub repository
`ww7/gas-mask-ng`; `forgejo` retains the private `ww7-forks/gasmask` mirror. Preserve original authors and merge ancestry.

Build with `scripts/build-release.sh`, test with `scripts/test.sh`. Storage migration
can be tested without full Xcode using `scripts/test-storage.sh`. Tests and smoke
checks must use temporary fixtures, never the owner's live profiles or `/etc/hosts`.
Owner standing authorization (16 October 2026): after each successfully built and
verified new version, install it in `/Applications/Gas Mask.app`. Close the running
app gracefully, preserving pending edits, and back up the previous app, profiles
and preferences before replacement. Verify that profiles and settings are
preserved; installation must not activate profiles or rewrite `/etc/hosts`.
The owner authorized the initial public GitHub migration. Subsequent publishing
and release uploads require separate owner authorization.

Release artifacts are locally signed and are not Developer ID signed or notarized.

The local code graph is `graphify-out/graph.json` (ignored by Git). Refresh it with
`graphify update .` after code changes.
