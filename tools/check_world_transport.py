"""Two independent Godot clients: world movement, remote avatar and consented PvP."""
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = shutil.which('Godot_v4.7.2-stable_win64_console.exe')
BASE = [GODOT, '--headless', '--path', str(ROOT), '--script', 'res://tests/world_transport_test.gd', '--', '--test-mode']
host_log = ROOT / 'build/world-transport-host.log'
client_log = ROOT / 'build/world-transport-client.log'
flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
with host_log.open('w', encoding='utf-8') as output:
    host = subprocess.Popen(BASE + ['--world-host'], cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, creationflags=flags)
    try:
        deadline = time.monotonic() + 6
        while 'WORLD_HOST_READY' not in host_log.read_text(encoding='utf-8', errors='replace'):
            if host.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('World host did not become ready')
            time.sleep(.05)
        client = subprocess.run(BASE + ['--world-client'], cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=12, creationflags=flags)
        client_text = client.stdout + client.stderr
        client_log.write_text(client_text, encoding='utf-8')
        host.wait(timeout=12)
        host_text = host_log.read_text(encoding='utf-8', errors='replace')
        ok = host.returncode == 0 and client.returncode == 0
        ok &= 'WORLD_TRANSPORT_HOST: PASS' in host_text and 'WORLD_TRANSPORT_CLIENT: PASS' in client_text
        ok &= not any(bad in host_text + client_text for bad in ['SCRIPT ERROR', 'FAIL:', 'ERROR:'])
        print('ENET_WORLD_TRANSPORT: ' + ('PASS' if ok else 'FAIL'))
        if not ok:
            print(host_text[-2200:])
            print(client_text[-2200:])
        raise SystemExit(0 if ok else 1)
    finally:
        if host.poll() is None:
            host.terminate()
            host.wait(timeout=5)
