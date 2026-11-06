"""Run focused gameplay checks with failure/parse-error/timeout detection."""
import shutil
import subprocess
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = shutil.which('Godot_v4.7.2-stable_win64_console.exe')
SUITES = {
    'equipment_forge_test': 'EQUIPMENT_FORGE_SUITE: PASS',
    'title_rules_test': 'TITLE_RULES_SUITE: PASS',
    'recipes_test': 'RECIPES_SUITE: PASS',
    'location2_data_test': 'LOCATION2_DATA_SUITE: PASS',
    'pet_depth_test': 'PET_DEPTH_SUITE: PASS',
    'combat_flow': 'COMBAT_FLOW: PASS',
    'progression_all_test': 'PROGRESSION_SUITE: PASS',
    'items_test': 'ITEMS_SUITE: PASS',
    'companions_test': 'COMPANIONS_SUITE: PASS',
    'world_entities_test': 'WORLD_ENTITIES_SUITE: PASS',
    'settings_test': 'SETTINGS_SUITE: PASS',
    'world_flow': 'WORLD_FLOW: PASS',
    'functions_ui_test': 'FUNCTIONS_UI_SUITE: PASS',
    'mounts_test': 'MOUNTS_SUITE: PASS',
    'social_state_test': 'SOCIAL_STATE_SUITE: PASS',
    'session_store_test': 'SESSION_STORE_SUITE: PASS',
    'regression_features_test': 'REGRESSION_FEATURES_SUITE: PASS',
    'server_world_test': 'SERVER_WORLD_SUITE: PASS',
    'server_session_test': 'SERVER_SESSION_SUITE: PASS',
    'network_world_test': 'NETWORK_WORLD_SUITE: PASS',
    'menu_commands_test': 'MENU_COMMANDS_SUITE: PASS',
    'pet_runes_test': 'PET_RUNES_SUITE: PASS',
    'bounty_guild_test': 'BOUNTY_GUILD_SUITE: PASS',
    'bounty_integration_test': 'BOUNTY_INTEGRATION_SUITE: PASS',
    'skill_rules_test': 'SKILL_RULES_SUITE: PASS',
    'original_skill_flow_test': 'ORIGINAL_SKILL_FLOW_SUITE: PASS',
    'source_character_test': 'SOURCE_CHARACTER_SUITE: PASS',
    'hotbar_test': 'HOTBAR_SUITE: PASS',
    'quest_rewards_test': 'QUEST_REWARDS_SUITE: PASS',
    'auto_medicine_test': 'AUTO_MEDICINE_SUITE: PASS',
    'forest_navigation_test': 'FOREST_NAVIGATION_SUITE: PASS',
}

failed = []
reports = []
for name, marker in SUITES.items():
    try:
        result = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--script',
                                 f'res://tests/{name}.gd', '--', '--test-mode'],
                                cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90)
        output = result.stdout + result.stderr
        (ROOT / 'build' / f'{name}.log').write_text(output, encoding='utf-8')
        bad = result.returncode or marker not in output or any(x in output for x in ['ERROR:', 'FAIL:', 'Parse Error'])
        count = sum(line.startswith('PASS:') for line in output.splitlines())
        reports.append({'suite':name,'status':'FAIL' if bad else 'PASS','checks':count})
        print(f'{name}: {"FAIL" if bad else "PASS"} ({count} checks)')
        if bad:
            failed.append(name)
            print(output[-3500:])
    except subprocess.TimeoutExpired as exc:
        failed.append(name)
        output = (exc.stdout or b'') + (exc.stderr or b'')
        if isinstance(output, bytes): output = output.decode('utf-8', errors='replace')
        (ROOT / 'build' / f'{name}.log').write_text(output, encoding='utf-8')
        reports.append({'suite':name,'status':'TIMEOUT','checks':0})
        print(f'{name}: TIMEOUT')
        print(output[-1200:])
(ROOT/'build/checks-latest.json').write_text(json.dumps({'status':'FAIL' if failed else 'PASS','checks':sum(row['checks'] for row in reports),'suites':reports},indent=2)+'\n',encoding='utf-8')
raise SystemExit(1 if failed else 0)
