#!/usr/bin/env python3
"""Run ONLY inside the disposable guest; production helper target is unchanged."""
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

assert subprocess.check_output(['sysctl', '-n', 'hw.model'], text=True).strip().startswith('VirtualMac')
assert Path('/private/var/tmp/gasmask-disposable-vm').is_file() and os.getuid() != 0
home = Path.home()
writer = home / 'RootWriterHarness.app/Contents/Helpers/HostsWriter'
client = home / 'protocol-client'
hosts = Path('/private/etc/hosts')
initial = hosts.read_bytes()
results = {}

def sudo(*args):
    return subprocess.check_output(['sudo', '-n', *map(str, args)], text=True).strip()

def run_case(name, mode='status', attacker=False, wrong_hash=False):
    with tempfile.TemporaryDirectory(prefix='gasmask-protocol-') as temp:
        ready, endpoint = Path(temp)/'ready', Path(temp)/'endpoint'
        process = subprocess.Popen([str(client), str(ready), str(endpoint), 'rejected' if wrong_hash else mode], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        stage = None
        try:
            limit = time.monotonic()+5
            while not ready.exists() and time.monotonic()<limit:
                time.sleep(.05)
            pid, uid, codehash = ready.read_text().split()
            if wrong_hash:
                codehash = '00'*20
            stage = Path(sudo('mktemp', '-d', '/private/var/db/gas-mask-ng.XXXXXXXX'))
            sudo('cp', '-X', writer, stage/'writer')
            sudo('chmod', '700', stage/'writer')
            sudo('chmod', '711', stage)
            sudo('env', '-i', 'PATH=/usr/bin:/bin:/usr/sbin:/sbin', 'LC_ALL=C', stage/'writer', '--serve', pid, uid, codehash, stage)
            path = str(stage/'control.sock')
            if attacker:
                connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                connection.settimeout(3)
                connection.connect(path)
                try:
                    refused = connection.recv(1) == b''
                except ConnectionResetError:
                    refused = True
                connection.close()
                assert refused, 'Different PID unexpectedly accepted'
            endpoint.write_text(path+'\n')
            output, _ = process.communicate(timeout=25)
            assert process.returncode == 0, output
            limit = time.monotonic()+(35 if wrong_hash else 5)
            while stage.exists() and time.monotonic()<limit:
                time.sleep(.1)
            assert not stage.exists(), 'Root stage survived disconnect/accept deadline'
            results[name] = {'passed': True, 'client_output': output.strip(), 'root_stage_removed': True}
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()

run_case('wrong_pid_then_valid_peer', attacker=True)
run_case('malformed_protocol', mode='malformed')
run_case('wrong_cdhash_and_initial_deadline', wrong_hash=True)
try:
    sudo('mv', hosts, '/private/var/tmp/gasmask-protocol-hosts')
    sudo('ln', '-s', '/private/var/tmp/gasmask-protocol-hosts', hosts)
    run_case('symlink_target', mode='unsafe')
finally:
    if hosts.is_symlink():
        sudo('rm', hosts)
    sudo('mv', '/private/var/tmp/gasmask-protocol-hosts', hosts)
try:
    sudo('ln', hosts, '/private/var/tmp/gasmask-protocol-hardlink')
    run_case('hardlink_target', mode='unsafe')
finally:
    sudo('rm', '/private/var/tmp/gasmask-protocol-hardlink')
assert hosts.read_bytes() == initial
assert not list(Path('/private/var/db').glob('gas-mask-ng.*'))
results['hosts_content_unchanged'] = hashlib.sha256(initial).hexdigest()
Path('/private/var/tmp/gasmask-protocol-results.json').write_text(json.dumps(results, indent=2)+'\n')
print(json.dumps(results, indent=2))
