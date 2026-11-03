# CLAUDE.md — Covenant Chronicles 3D

## 📌 Project Overview
- **Project Name**: Covenant Chronicles 3D (Repo codename: `anrufen-online-3d`)
- **Developer / Creator**: Pavlo (`guns96x`)
- **Genre**: Mobile 3D Action MMORPG
- **Engine**: **Godot Engine 4.7.2 Stable** (GDScript, ENet Multiplayer, Mobile/Compatibility 3D Renderer)
- **Primary Target**: Android (Touch-first, locked Landscape, optimized for devices like Samsung Galaxy S24 FE)
- **Secondary Target**: Windows 11 (Developer client & headless dedicated server)

---

## 🧭 Project Architecture & Established Game Data
All files in `data/` represent Pavlo's core game design databases and narrative design systems.
**Treat these data structures as authoritative production assets. Do NOT delete, mock, or wipe them.**

- `data/quests.json`: Narrative tree containing 713 designed quests, objectives, NPC dialog branches, and reward tables.
- `data/monsters.json`: Bestiary of 384 unique monster profiles (levels, base HP, stats, drop tables).
- `data/scenes.json`: World geography mapping 227 scene zones, portals, spawn points, and town layouts.
- `data/equipment.json`: Item database (weapons, armor, accessories, stat bonuses, rarity tiers).
- `data/skills.json`: Class abilities and spell definitions.
- `data/classes.json`: Player classes, stat scaling, and level-up progressions.
- `data/balance/`: Mathematical balance sheets and core formula parameters (`script_5005.lua`, etc.).

---

## 🏛 Directory Structure
```
anrufen-online-3d/
├── assets/
│   └── models/               # Stylized low-poly 3D models (GLB format)
├── client/
│   └── scenes/
│       ├── entities/         # 3D game entities (Player, NPC, Monster, TrainingDummy)
│       ├── ui/               # Mobile touch HUD, Floating Dynamic Joystick, Dialogs, Target frames
│       └── world/            # 3D World scenes (e.g. guanlin_town.tscn starting hub)
├── data/                     # Game design datasets (quests, monsters, items, scenes, balance)
├── shared/
│   ├── combat/               # CombatFormulas (PHY, FIRE, WATER, HOLY, DARK damage, crit, evasion)
│   ├── data/                 # DataManager singleton for fast indexed querying
│   └── network/              # NetworkManager (ENet multiplayer RPCs, player state replication)
├── server/                   # Headless server logic, spawner, and authoritative combat validation
├── tools/                    # Asset pipelines (Blender 5.0.1 automation scripts)
├── build/                    # Target Android APK binaries
├── export_presets.cfg        # Godot export preset for Android (arm64-v8a, signed)
├── project.godot             # Godot 4.7.2 project definition
└── Play_Game.bat             # Desktop launcher script
```

---

## 🎮 Mobile Control Standards (Android Touch-First)
- **Screen Orientation**: Strictly locked to **Landscape** (`sensor_landscape`).
- **Left Side Screen**: Dynamic Floating Joystick (`TouchJoystick`). Appears directly wherever the left thumb touches down.
- **Right Side Screen**: 
  - Dragging orbits the third-person spring-arm camera smoothly.
  - Two-finger pinch zooms the camera distance in/out.
  - Single tap rays into the 3D world to select targets (enemies, NPCs, interactables).
- **Action Buttons**: Large, thumb-friendly circular touch buttons for Primary Attack (⚔), Dash (💨), Skill 1 (🔥), and Context Interaction (💬).
- **Movement Direction**: Camera-relative. Joystick up moves character forward into the camera's sightline, down moves toward camera.

---

## ⚙️ Coding Standards & Conventions
- **Language**: GDScript with strict static typing:
  ```gdscript
  var current_hp: int = 100
  func take_damage(amount: int, is_critical: bool) -> void:
  ```
- **Node Paths**: Use `@onready @export` or `@onready var node: Type = $NodePath`.
- **Combat Math**: Always route calculations through `CombatFormulas.calculate_damage()`.
- **Signals**: Use strongly typed custom signals (`signal health_changed(new_hp: int, max_hp: int)`).
- **Performance**: Mobile-first mindset. Avoid per-frame allocations in `_process()`. Cache queries in `DataManager`.

---

## 🚀 Build, Test & Deployment Commands

### 1. Launch Client on PC (for quick testing):
```cmd
"C:\Users\pavlo\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path "C:\Users\pavlo\anrufen-online-3d"
```

### 2. Export Android APK via CLI:
```cmd
"C:\Users\pavlo\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\pavlo\anrufen-online-3d" --export-debug "Android" "C:\Users\pavlo\anrufen-online-3d\build\covenant_chronicles.apk"
```

### 3. Deploy APK to Samsung Galaxy S24 FE via Tailscale:
```cmd
tailscale file cp "C:\Users\pavlo\anrufen-online-3d\build\covenant_chronicles.apk" s24-fe:
```

### 4. Asset Generation (Blender 5.0.1):
```cmd
"D:\programs\blender\blender.exe" --background --python "C:\Users\pavlo\anrufen-online-3d\tools\build_guanlin_assets.py"
```

---

## 🤝 Interaction Principles
- You are working directly with Pavlo as his lead co-developer.
- Focus on practical, high-quality implementations: smooth physics, responsive touch controls, rich 3D environments, animated models, and robust networking.
- Never refactor or question established design datasets unless Pavlo explicitly requests a change.
- Keep commits focused and push changes to GitHub (`guns96x/anrufen-online-3d`).
