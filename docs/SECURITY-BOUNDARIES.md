# Security boundaries for the unsigned release candidate

16 October 2026. Applies to the ww7.21 implementation. This document describes
reviewed boundaries and fixture evidence; it is not an assertion of zero bugs.

## System hosts writer

The application no longer uses AuthorizationExecuteWithPrivileges or adds a
persistent per-user write ACL. It never installs a launchd root service. Explicit
Activate or Save on an active list may request administrator approval to start a
session-scoped native writer. Closing the app closes its private connection and
ends the writer. A new app session can require new approval.

The administrator-authorized shell has fixed source, a sanitized environment,
absolute tool paths and descriptor arguments. Shell path arguments are quoted;
list names, URLs and hosts text are never executable input. It copies the helper
into a random root-owned staging directory and checks its SHA-256 against a
constant embedded in the locally signed main executable. The packaged helper's
signature must not be changed after compiling this pin.

The writer authenticates the connection using the kernel audit token (PID and
real/effective UID), strict running-code validity, the approved app's exact
CDHash, hardened runtime, and the absence of get-task-allow. It then removes the
listening socket; only that stream remains. The client verifies root ownership
of the endpoint and the server's root peer UID. Initial authentication has a
30-second deadline. The descriptor is close-on-exec.

The protocol accepts only status/digest and bounded write operations. It accepts
no arbitrary pathname, executable, command, ownership or permission request.
Production opens the fixed `/private/etc` directory and `hosts` leaf. It refuses
symlinks, hard links, nonregular or non-root-owned targets, unsafe parent
permissions/ACLs, NUL/non-UTF-8 input and payloads above 32 MiB. Both sides bound
reads. Test binaries link the same write core against a temporary directory;
there is no runtime production option to select another target.

Writes use a new root:wheel 0644 inode with an empty ACL, fsync and atomic exchange.
The previous inode remains until the commit is durable. Expected-content hashes,
inode checks, and a second hash of the retained old inode detect concurrent edits,
including in-place edits permitted by an inherited legacy ACL. Precommit failures
leave the original intact; a directory-sync failure attempts rollback. If rollback
itself fails, the old inode is retained under its recovery filename and an error
is returned; the app does not claim that a failed operation certainly changed
nothing.

A preexisting unsafe target or legacy system symlink is refused, not silently
repaired. The old v0.4 migration imports readable ordinary files without privileged
copy/remove commands, deleting `/etc/gasmask`, or rewriting a system symlink.
The modern user-data migration remains non-destructive.

Existing per-user hosts ACLs from older installed versions are removed by the
first successful explicit activation, when the safe inode replaces the old one.
Installation and tests do not modify the owner's live hosts file or its ACL.

## Background behavior

Timers, startup, watchers and download callbacks cannot open an authorization
dialog. A validated download is saved to its normal cache. If applying the active
list requires approval, the app marks it Pending and enables Activate again.
Background updates apply automatically while the authenticated session exists.
The native DispatchSource watcher follows atomic replacement and deletion/
recreation, with descriptor lifetime handled by cancellation handlers. It avoids
restoring its own successful write. Combined restoration expands the saved source
references and saved source content, not the composition's serialized index or
unsaved source buffers.

## Remote downloads

Sources require HTTPS with a nonempty host and no embedded username/password or
fragment. Redirects stay on the same host and effective port, remain HTTPS, strip
Authorization and stop after five hops. The system TLS verifier is used; there
is no certificate-trust bypass, cookie jar, shared credential store or disk URL
cache. Timeouts bound stalled requests. Existing HTTP profiles retain their data
and URL but show an error until the owner supplies a trusted HTTPS source.

A streaming delegate enforces a 32 MiB cap, including unknown-length/decompressed
bodies. Accepted responses are HTTP 200 with text/plain or application/octet-stream,
or a bodyless conditional 304 with an existing cache. New text must be UTF-8,
without NUL, with mappings/comments only, valid numeric IP addresses and bounded
hostname/line lengths. Errors retain the last successful content and timestamp.
Failures do not log token-bearing URLs. A chosen HTTPS source can still supply
unwanted but valid mappings: transport validation does not establish source trust.

## Release and trust limits

The owner chose to defer Apple Developer Program, Developer ID and notarization.
An ad-hoc signature with hardened runtime is retained for executable integrity
and exact-build helper authentication on Apple Silicon. This signature does not
identify a publisher or make Gatekeeper trust the download. Verify the immutable
archive/source and SHA-256 before granting administrator access; do not globally
disable macOS security protections. Updates do not silently reuse a permanent
root-service trust relationship.

Native core sanitizer fixtures cover success, metadata/ACL cleanup, bad targets,
CAS conflicts, write/sync/exchange failures, rollback and peer rejection. Real
administrator approval/cancellation, staging cleanup after app crash/restart,
legacy ACL conversion under root, sleep/wake and physical Intel execution still
need disposable-Mac acceptance. No root acceptance test used the owner's hosts.
Source review and automated scanning cannot establish the absence of all defects
or malicious behavior in every dependency. See BUILD-STATUS.md for exact results.

The unused Sparkle framework and legacy upstream feed/keys were removed from
ww7.21. Ad-hoc third-party dynamic libraries are incompatible with strict
hardened-runtime library validation without a shared Developer ID Team ID.
The app retains manual GitHub release links instead of disabling library
validation. Remote-list updates use the separate first-party downloader. The
writer rejects callers with entitlements that allow library/DYLD/page-protection
bypasses as well as get-task-allow.

The final candidate also covers nested authorization event loops: if a validated
Remote cache changes during administrator approval, a successful write of the
older snapshot does not clear Pending for the newer cache. Cache saved/unsaved
state remains distinct from system-apply state. A source refresh regenerates a
Combined preview without saving or applying an in-progress unsaved composition;
background system restoration expands the last saved source order only.

Darwin ACL enumeration is tested explicitly: acl_get_entry returns zero when
an entry is found. Parent-directory ACLs are refused even when mode bits alone
look safe. Empty replacement-file ACLs and root ownership/mode are verified.

The ephemeral execution stage lives below `/private/var/db`, not `/var/run`:
macOS may make the latter group-writable by daemon. Before authorization the app
checks `/private`, `/private/var` and `/private/var/db` for root ownership, no
symlink, no group/other write mode and no ACL. This prevents a non-root group
from renaming/replacing a stage between the verified copy and root execution.
A separate fixture covers group-writable parents, wrong owner and symlinks.

An already active list is marked Pending when system-file permissions/ACLs are
unsafe, even if its text matches. This enables Activate to repair a legacy write
ACL without switching lists. Attribute-change events are monitored too. Startup
and installation do not repair permissions or request administrator approval;
the first explicit approved activation performs the atomic permission cleanup.
