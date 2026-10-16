# Disposable macOS root-writer acceptance

These checks complement the ordinary-user sanitizer and XCTest fixtures. They do
not authorize testing against the owner's `/etc/hosts`. Run only in a disposable
macOS guest, without host directory shares, clipboard sharing or real profiles.

`scripts/build-root-acceptance.sh path/to/Contents/Helpers/HostsWriter` packages
the exact signed production writer and compiles the production PrivilegedActions
implementation into an independent hardened-runtime GUI client. The client is
never included in the product. Its hardware-model and explicit fixture-marker
guards refuse physical Macs; its mode is not a production runtime switch.

## Setup

1. Clone a clean macOS VM; record tool version, image digest, guest version and
   hardware model. Use host-only networking and no host data shares. Transfer only
   the app/harness and synthetic fixtures. Keep VM credentials out of public logs.
2. In the guest, back up its stock `/private/etc/hosts`, including metadata. Verify
   `hw.model` begins with `VirtualMac` and create the explicit marker
   `/private/var/tmp/gasmask-disposable-vm`.
3. Add the guest's ordinary user write ACL to the guest hosts file to reproduce
   older Gas Mask installations. Record root ownership and initial contents.

## Cases

Launch `RootWriterHarness.app` using `open -n ... --args MODE` in the guest GUI:

- `cancel`: cancel the native administrator dialog. Expect no authorized session,
  `NSUserCancelledError`, unchanged target and no surviving stage/helper.
- `approve`: approve the native dialog. Expect the first and second writes to
  succeed, the second with authorization disabled; exact synthetic contents,
  root:wheel 0644 and no ACL; session closed and root stage/helper removed.
- `hold`: approve, verify the root helper exists, then SIGKILL the **guest client**.
  Expect EOF to terminate the writer and remove its root stage. Relaunch and repeat
  to prove a fresh app session works.
- `conflict`: while the native dialog is open, change the guest target as root.
  Approve; expect a CAS conflict and preservation of the intervening contents.

Every mode first attempts a background write with authorization disabled and
expects refusal without a dialog. JSON outcomes are written only in the guest's
`/private/var/tmp/gasmask-acceptance-MODE.json`. Verify the outcome and filesystem
independently, rather than treating a dialog dismissal as success.

Also run the native core/peer regression fixtures in the guest as root and as its
ordinary user. Exercise an incorrect PID/CDHash peer before the expected client,
malformed protocol, disconnected client, unsafe symlink/hard-link targets and the
initial connection timeout. No background service or root-owned persistent app
trust should remain. Restore the guest hosts backup and stop the disposable VM.

Record fresh outcomes in BUILD-STATUS.md. A compiled harness or passing unprivileged
fixtures alone do not satisfy this acceptance gate.
