"""Ask the existing Godot editor to import assets, without editing game scripts."""
from pathlib import Path
import argparse
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path.home() / '.codex/skills/blender-setup/scripts'))
from windowless import run

result = run([args.godot, '--headless', '--editor', '--path', str(root), '--import'],
             cwd=root, timeout=240)
log = root / 'art_src/logs/godot_import.log'
log.parent.mkdir(parents=True, exist_ok=True)
log.write_text(result.stdout + '\n' + result.stderr, encoding='utf-8')
lines = (result.stdout + '\n' + result.stderr).splitlines()
errors = [line for line in lines if 'ERROR:' in line or 'SCRIPT ERROR:' in line]
print('GODOT IMPORT EXIT', result.returncode, 'ERROR LINES', len(errors), 'LOG', log)
print('\n'.join(errors[:12]))
raise SystemExit(result.returncode or bool(errors))
