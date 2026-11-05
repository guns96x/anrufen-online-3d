"""Actual two-process ENet smoke, with isolated in-memory test identities."""
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = shutil.which('Godot_v4.7.2-stable_win64_console.exe')
BASE = [GODOT, '--headless', '--path', str(ROOT), '--script', 'res://tests/social_state_test.gd', '--']
host_log = ROOT / 'build/social-transport-host.log'
client_log = ROOT / 'build/social-transport-client.log'
flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
with host_log.open('w', encoding='utf-8') as output:
    host = subprocess.Popen(BASE + ['--transport-host', '--test-mode'], cwd=ROOT,
                            stdout=output, stderr=subprocess.STDOUT, creationflags=flags)
    try:
        deadline = time.monotonic() + 5
        while 'TRANSPORT_HOST_READY' not in host_log.read_text(encoding='utf-8', errors='replace'):
            if host.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Transport host did not become ready')
            time.sleep(.05)
        client = subprocess.run(BASE + ['--transport-client', '--test-mode'], cwd=ROOT,
                                capture_output=True, text=True, encoding='utf-8', errors='replace',
                                timeout=10, creationflags=flags)
        client_text = client.stdout + client.stderr
        client_log.write_text(client_text, encoding='utf-8')
        host.wait(timeout=12)
        host_text = host_log.read_text(encoding='utf-8', errors='replace')
        ok = host.returncode == 0 and client.returncode == 0
        ok &= 'TRANSPORT_HOST: PASS' in host_text and 'TRANSPORT_CLIENT: PASS' in client_text
        ok &= 'SCRIPT ERROR' not in host_text + client_text
        print('ENET_TRANSPORT: ' + ('PASS' if ok else 'FAIL'))
        if not ok:
            print(host_text[-1800:])
            print(client_text[-1800:])
        raise SystemExit(0 if ok else 1)
    finally:
        if host.poll() is None:
            host.terminate()
            host.wait(timeout=5)
