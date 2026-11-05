"""Validate the actual deliverable, including ignored export version options."""
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sdk = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk'
analyzer = sdk / 'cmdline-tools/latest/bin/apkanalyzer.bat'
signer = sdk / 'build-tools/36.0.0/apksigner.bat'
# Release key since v0.9.5 (C:/Users/pavlo/.android-keys, outside the repo); earlier builds used the debug key.
expected_certificate = 'b989bbabb927aeb77d3f62b1adb72faae2fdb70da5981ad37164cbf0aaa847a1'


def run(args):
    result = subprocess.run([str(x) for x in args], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout.strip()


config = (ROOT / 'export_presets.cfg').read_text(encoding='utf-8')
version_code = int(re.search(r'^version/code=(\d+)$', config, re.M)[1])
version_name = re.search(r'^version/name="([^"]+)"$', config, re.M)[1]
apk = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / f'build/covenant_chronicles_v{version_name}.apk'
package = re.search(r'^package/unique_name="([^"]+)"$', config, re.M)[1]
actual_code = int(run([analyzer, 'manifest', 'version-code', apk]))
actual_name = run([analyzer, 'manifest', 'version-name', apk])
actual_package = run([analyzer, 'manifest', 'application-id', apk])
assert (actual_code, actual_name, actual_package) == (version_code, version_name, package), 'APK metadata differs from export settings'
certificate = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)', run([signer, 'verify', '--print-certs', apk]))[1]
assert certificate == expected_certificate, 'Signing identity changed'
with zipfile.ZipFile(apk) as archive:
    assert archive.testzip() is None, 'Corrupt APK member'
    names = archive.namelist()
    assert not any(x.startswith(('assets/build/', 'assets/tests/', 'assets/tools/', 'assets/docs/')) for x in names), 'Development artifacts shipped'
    required_files = ['assets/data/original/all_prop.json', 'assets/data/original/all_skill.json', 'assets/data/original/all_title.json', 'assets/server/game_session.gdc', 'assets/shared/network/network_manager.gdc', 'lib/arm64-v8a/libgodot_android.so']
    if version_code >= 5:
        required_files += ['assets/data/original/skill_rules.json', 'assets/shared/combat/skill_action_plan.gdc', 'assets/client/scenes/entities/original_skill_controller.gdc']
    if version_code >= 6:
        required_files += ['assets/data/original/quest_rules.json', 'assets/data/original/quest_graph.json', 'assets/shared/progression/original_quest_catalog.gdc', 'assets/shared/progression/forest_forage.gdc', 'assets/shared/items/auto_medicine.gdc', 'assets/shared/items/medicine_state.gdc']
    for required in required_files:
        assert required in names, f'Missing runtime file: {required}'
report = {'status':'PASS','apk':str(apk.resolve()),'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'package':actual_package,'version_code':actual_code,'version_name':actual_name,'signer_sha256':certificate,'zip_crc':'PASS','development_assets':0,'physical_device_tested':False}
apk.with_suffix('.verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'APK_VERIFICATION: PASS ({actual_name}, code {actual_code}, {apk.stat().st_size} bytes, signing identity preserved)')
