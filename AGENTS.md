# Gas Mask ww7 fork

Project knowledge and PR decisions live in [docs/INTEGRATION.md](docs/INTEGRATION.md).
Current verification evidence is in [docs/BUILD-STATUS.md](docs/BUILD-STATUS.md).

The fork integrates a snapshot of all open upstream PRs while retaining the newer
SwiftUI architecture. `upstream` is read-only GitHub; `origin` is the private
Forgejo repository `ww7-forks/gasmask`. Preserve original authors and merge ancestry.

Build with `scripts/build-release.sh`, test with `scripts/test.sh`. Storage migration
can be tested without full Xcode using `scripts/test-storage.sh`. Tests and smoke
checks must use temporary fixtures, never the owner's live profiles or `/etc/hosts`.
The app is not installed automatically. Release artifacts are locally signed and
are not Developer ID signed or notarized.

The local code graph is `graphify-out/graph.json` (ignored by Git). Refresh it with
`graphify update .` after code changes.
