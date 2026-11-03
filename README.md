# Covenant Chronicles 3D (Anrufen Online Reimagined)

> Повноцінна 3D MMORPG під Android на базі **Godot 4.7.2** та реконструйованих ресурсів легендарної мобільної MMORPG **Anrufen Online (契约)** від WiStone.

## 🔗 Репозиторій та ресурси
- **GitHub**: [https://github.com/guns96x/anrufen-online-3d](https://github.com/guns96x/anrufen-online-3d)
- **Локальна директорія**: `C:\Users\pavlo\anrufen-online-3d`
- **Витягнуті оригінальні ресурси SISX**: `C:\Users\pavlo\anrufen_extracted`
- **Зібраний Android APK (28.5 MB)**: `C:\Users\pavlo\anrufen-online-3d\build\covenant_chronicles.apk`

---

## 🏛 Архітектура проєкту

```
anrufen-online-3d/
├── assets/
│   └── models/               # 3D моделі (GLB): Ратуша, фонтан, манекени, будинки, дерева, монстри
├── client/
│   └── scenes/
│       ├── entities/         # Персонаж (Player), NPC (Elder, Militia, Smith), Монстри (Boar, Spider, Jackal)
│       ├── ui/               # Touch HUD, динамічний плаваючий джойстик, квест-трекер, діалоги
│       └── world/            # guanlin_town.tscn — повноцінна стартова 3D-локація
├── data/                     # Декодовані дані з оригінального SISX (713 квестів, 384 монстри, сцени)
│   ├── classes.json
│   ├── equipment.json
│   ├── monsters.json
│   ├── quests.json
│   ├── scenes.json
│   └── scripts_original/     # Оригінальні Lua-скрипти бойових формул (clt_script.godat)
├── shared/
│   ├── combat/               # Розрахунок урону, типи шкоди (PHY, FIRE, WATER, HOLY, DARK), крит, ухилення
│   ├── data/                 # DataManager для швидкого завантаження сутностей
│   └── network/              # NetworkManager (ENet RPC, синхронізація гравців)
├── tools/
│   ├── build_guanlin_assets.py # Генератор 3D-асетів через Blender 5.0.1
│   ├── clean_uids.py           # Утиліта нормалізації Godot UID
│   └── generate_lowpoly_assets.py
├── build/                    # Зібрані інсталяційні APK
├── export_presets.cfg        # Налаштування експорту під Android (arm64-v8a, landscape, signed)
├── project.godot             # Конфігурація Godot 4.7.2
└── Play_Game.bat             # Швидкий запуск клієнта на ПК
```

---

## 🎮 Керування на Android (Touch-First)
- **Орієнтація**: Жорстко закріплений **Landscape** (`sensor_landscape`).
- **Лівий палець**: Динамічний плаваючий джойстик (з'являється під пальцем у будь-якій точці зліва).
- **Правий палець (свайп)**: Плавне 3D-обертання камери навколо героя.
- **Щипок (Pinch-to-Zoom)**: Наближення та віддалення камери.
- **Tap-to-Target**: Прямий дотик по монстру або NPC у 3D світі бере його в таргет.
- **Кнопки дій**: Велика кнопка **⚔ ATK**, скіли **🔥 Fire**, **💨 Dash** та діалог **💬 Talk**.

---

## 🛠 Запуск та збірка

### Запуск на ПК для тестування:
Запустити файл `Play_Game.bat` або через консоль:
```cmd
"C:\Users\pavlo\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path C:\Users\pavlo\anrufen-online-3d
```

### Збірка Android APK через CLI:
```cmd
"C:\Users\pavlo\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\pavlo\anrufen-online-3d" --export-debug "Android" "C:\Users\pavlo\anrufen-online-3d\build\covenant_chronicles.apk"
```

### Відправка на телефон через Tailscale:
```cmd
tailscale file cp "C:\Users\pavlo\anrufen-online-3d\build\covenant_chronicles.apk" s24-fe:
```
