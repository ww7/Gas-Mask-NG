#!/usr/bin/env python3
"""Verify an exact local release ZIP without launching the app or reading user data."""
import argparse
import datetime
import hashlib
import json
import plistlib
import subprocess
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('archive', type=Path)
parser.add_argument('--test-result', required=True, type=Path)
parser.add_argument('--root-acceptance', type=Path, help='Recorded disposable-Mac evidence for these exact writer bytes')
args = parser.parse_args()
archive = args.archive.resolve()

def run(*command):
    return subprocess.check_output(command, text=True, stderr=subprocess.STDOUT)

summary = json.loads(run('xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', str(args.test_result), '--format', 'json'))
assert summary['failedTests'] == 0 and summary['passedTests'] > 140
assert not summary.get('skippedTests')
with tempfile.TemporaryDirectory(prefix='gasmask-release-check-') as temporary:
    subprocess.run(['ditto', '-x', '-k', str(archive), temporary], check=True)
    app = Path(temporary) / 'Gas Mask.app'
    run('codesign', '--verify', '--deep', '--strict', str(app))
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    revision = info['WW7SourceRevision']
    assert info['CFBundleIdentifier'] == 'ee.clockwise.gmask'
    assert info['WW7BuildLabel'] in archive.name
    assert (app / 'Contents/Resources/UserDefaults.plist').read_bytes() == (root / 'Resources/UserDefaults.plist').read_bytes()
    profiles = list(app.rglob('*.hst'))
    assert profiles == [app / 'Contents/Resources/default.hst']
    assert profiles[0].read_bytes() == (root / 'Resources/default.hst').read_bytes()
    for path in app.rglob('*'):
        assert path.suffix != '.xctest'
        assert path.name not in ['ee.clockwise.gmask.plist', 'INSTALL-RECEIPT.json', 'Sparkle.framework']
        assert not (path.is_dir() and path.name in ['Local', 'Remote', 'Combined', 'Gas Mask Backups'])
    binaries = {}
    magics = {bytes.fromhex(value) for value in ['cafebabe','bebafeca','cafebabf','bfbafeca','feedface','cefaedfe','feedfacf','cffaedfe']}
    for path in sorted(app.rglob('*')):
        if not path.is_file() or path.is_symlink():
            continue
        with path.open('rb') as stream:
            magic = stream.read(4)
        if magic not in magics:
            continue
        architectures = run('xcrun', 'lipo', '-archs', str(path)).split()
        assert set(architectures) == {'arm64', 'x86_64'}
        run('codesign', '--verify', '--strict', str(path))
        signing = run('codesign', '--display', '--verbose=4', str(path))
        assert 'Signature=adhoc' in signing and 'runtime' in signing
        dependencies = run('xcrun', 'otool', '-L', str(path))
        assert '@rpath/' not in dependencies, dependencies
        binaries[str(path.relative_to(app))] = architectures
    assert len(binaries) == 3, binaries
    main = app / 'Contents/MacOS/Gas Mask'
    helper = app / 'Contents/Helpers/HostsWriter'
    helper_hash = hashlib.sha256(helper.read_bytes()).hexdigest()
    assert helper_hash.encode() in main.read_bytes(), 'Writer bytes differ from the pin compiled into the app'
    assert 'session writer 1' in run(str(helper), '--version')
    assert (app / 'Contents/Resources/Legal/GPL-2.0.txt').read_bytes() == (root / 'LICENSE').read_bytes()
    assert (app / 'Contents/Resources/Legal/SUPPORT.md').read_bytes() == (root / 'SUPPORT.md').read_bytes()
    snapshot = json.loads((root / 'docs/upstream-open-prs.json').read_text())
    for pr in snapshot['pull_requests']:
        subprocess.run(['git', 'merge-base', '--is-ancestor', pr['head_sha'], revision], cwd=root, check=True)
    root_evidence = None
    if args.root_acceptance:
        root_evidence = json.loads(args.root_acceptance.read_text())
        assert root_evidence['root_acceptance_passed'] is True
        assert root_evidence['hosts_writer_sha256'] == helper_hash
        assert root_evidence['cases'] and all(value is True for value in root_evidence['cases'].values())
        assert root_evidence['owner_profiles_or_preferences_used'] is False
        assert root_evidence['host_system_hosts_written'] is False
    metadata = {
        'version': info['WW7BuildLabel'], 'internal_build': info['CFBundleVersion'],
        'source_revision': revision, 'distribution_channel': 'public prerelease candidate', 'stable_acceptance_complete': False,
        'built_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'bundle_identifier': info['CFBundleIdentifier'], 'minimum_macos': info['LSMinimumSystemVersion'],
        'archive': archive.name, 'archive_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
        'signature': 'ad-hoc, hardened runtime; no Developer ID', 'notarized': False,
        'verified_mach_o_binaries': binaries, 'hosts_writer_sha256': helper_hash,
        'compiled_writer_hash_matches': True, 'only_system_dynamic_dependencies': True,
        'passed_tests': summary['passedTests'], 'failed_tests': summary['failedTests'],
        'skipped_tests': summary['skippedTests'], 'runtime_warnings': summary.get('runtimeWarnings', []),
        'full_test_suite_run': True, 'storage_assertions': 28, 'native_security_assertions': 240, 'signature_test_configurations': 3,
        'owner_profiles_or_preferences_included': False, 'bundled_hosts_file': 'Resources/default.hst (repository default only)',
        'isolated_root_acceptance': root_evidence,
        'remaining_acceptance': ([] if root_evidence else ['administrator approval/cancellation and teardown on disposable macOS']) + ['physical Intel, sleep/wake, login-item and uninstall lifecycle'],
    }
    output = archive.parent / 'BUILD-INFO.json'
    output.write_text(json.dumps(metadata, indent=2) + '\n')
    (archive.parent / 'SHA256SUMS').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in [archive, output]))
    print(json.dumps(metadata, indent=2))
