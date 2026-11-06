"""Safely execute the isolated geometry preview."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path.home()/'.codex/skills/blender-setup/scripts'))
from windowless import run
root=Path(__file__).resolve().parents[1]
r=run([r'D:\programs\blender\blender.exe','--background','--factory-startup',
       '--python-exit-code','1','--python',str(root/'art_src/preview_geometry.py')],
      cwd=root,timeout=90)
print('Preview exit',r.returncode)
print((r.stdout+r.stderr)[-1500:])
raise SystemExit(r.returncode)
