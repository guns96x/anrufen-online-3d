"""Headless dedicated server plus one independent client process."""
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = shutil.which('Godot_v4.7.2-stable_win64_console.exe')
server_log = ROOT / 'build/dedicated-server.log'
flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
with server_log.open('w', encoding='utf-8') as output:
    server = subprocess.Popen([GODOT, '--headless', '--path', str(ROOT), 'res://server/dedicated_server.tscn', '--', '--port', '17903', '--test-mode'],
                              cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, creationflags=flags)
    try:
        deadline = time.monotonic() + 15
        while 'Сервер Covenant Chronicles працює' not in server_log.read_text(encoding='utf-8', errors='replace'):
            if server.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Dedicated server did not start')
            time.sleep(.1)
        client = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--script', 'res://tests/dedicated_client_test.gd', '--', '--test-mode'],
                                cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=40, creationflags=flags)
        text = client.stdout + client.stderr
        (ROOT / 'build/dedicated-client.log').write_text(text, encoding='utf-8')
        ok = client.returncode == 0 and 'DEDICATED_CLIENT: PASS' in text and 'SCRIPT ERROR' not in text
        print('DEDICATED_SERVER: ' + ('PASS' if ok else 'FAIL'))
        if not ok:
            print(text[-2000:])
        raise SystemExit(0 if ok else 1)
    finally:
        if server.poll() is None:
            server.terminate()
            server.wait(timeout=5)
