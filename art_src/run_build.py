"""Run the owned offline asset build without creating Windows console windows.

Uses the reviewed bounded process runner already installed with blender-setup.
The interactive Blender scene is never loaded or changed by this process.
"""
from pathlib import Path
import argparse
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--blender', required=True)
    parser.add_argument('--model', default='all')
    parser.add_argument('--renders', action='store_true')
    parser.add_argument('--timeout', type=int, default=1800)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(Path.home() / '.codex/skills/blender-setup/scripts'))
    from windowless import run
    command = [args.blender, '--background', '--factory-startup',
               '--python-exit-code', '1', '--python',
               str(root / 'art_src/build_characters.py'), '--',
               '--root', str(root), '--model', args.model]
    if args.renders:
        command.append('--renders')
    result = run(command, cwd=root, timeout=args.timeout)
    logs = root / 'art_src/logs'
    logs.mkdir(parents=True, exist_ok=True)
    log = logs / (args.model + '.log')
    log.write_text(result.stdout + '\n' + result.stderr, encoding='utf-8')
    print('BUILD EXIT', result.returncode, 'LOG', log)
    lines=(result.stdout + '\n' + result.stderr).splitlines()
    selected=[line for line in lines if '[DONE]' in line or 'Error:' in line or 'RuntimeError:' in line]
    print('\n'.join(selected) if result.returncode == 0 else '\n'.join(lines[-24:]))
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
