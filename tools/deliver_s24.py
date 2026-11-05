"""Send an explicitly selected APK once S24 FE is online; bounded wait only."""
import argparse
import hashlib
import json
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('apk',type=Path)
parser.add_argument('--wait-seconds',type=int,default=0)
args = parser.parse_args()
apk = args.apk.resolve(strict=True)
assert apk.suffix == '.apk' and 0 <= args.wait_seconds <= 3600
tailscale = shutil.which('tailscale')
assert tailscale
flags = getattr(subprocess,'CREATE_NO_WINDOW',0)
target = '100.105.189.114'
deadline = time.monotonic()+args.wait_seconds
report_path = apk.with_suffix('.delivery.json')
report = dict(apk=str(apk),sha256=hashlib.sha256(apk.read_bytes()).hexdigest(),target=target,status='WAITING',receiver_playback_verified=False)

def save(status):
    report.update(status=status,checked_at=datetime.now(timezone.utc).isoformat())
    report_path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('S24_DELIVERY: '+status,flush=True)

save('WAITING')
while True:
    status = subprocess.run([tailscale,'status','--json'],capture_output=True,text=True,timeout=15,creationflags=flags)
    if status.returncode == 0:
        peers = json.loads(status.stdout).get('Peer',{}).values()
        if any(target in p.get('TailscaleIPs',[]) and p.get('Online') for p in peers):
            subprocess.run([tailscale,'ping','--c','1','--timeout','4s',target],capture_output=True,timeout=10,creationflags=flags)
            try:
                result = subprocess.run([tailscale,'file','cp','--update-interval=0',str(apk),target+':'],capture_output=True,text=True,timeout=180,creationflags=flags)
                if result.returncode == 0:
                    save('SENT')
                    raise SystemExit(0)
            except subprocess.TimeoutExpired:
                pass
    if time.monotonic() >= deadline:
        save('NOT_SENT_OFFLINE_OR_UNREACHABLE')
        raise SystemExit(1)
    time.sleep(min(30,max(0,deadline-time.monotonic())))
