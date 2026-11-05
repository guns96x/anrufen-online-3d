# Dedicated server over Tailscale

The game is online by default: the server owns accounts, heroes, movement, monsters,
combat, inventory, quests, pets and the social layer. Clients send intents and draw
what the server sends back. Offline play is kept only as a test switch in the main
menu settings.

## Run the server

On the host PC (Godot 4.7.2 console on PATH, project folder copied there):

```
Run_Server.bat
```

It starts `res://server/dedicated_server.tscn` headless on UDP port 7777, appends to
`server.log` and restarts the server five seconds after any crash. Data lives in
`%APPDATA%\Godot\app_userdata\Covenant Chronicles 3D\lan_server_v1.json` with a
`.bak` copy; back up that folder.

Manual start with another port:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://server/dedicated_server.tscn -- --port 7777
```

Keep it reachable only over Tailscale: allow UDP 7777 in Windows Firewall for the
Tailscale interface, not for public networks.

## Connect

Main menu → Settings → "Адреса сервера (Tailscale)": the host's Tailscale IP or
MagicDNS name (default `100.82.252.86`, the `asus` PC). Main menu → Грати → a slot.

Each of the three slots has its own device token (`user://lan_identity*.token`), so
each slot is a separate server account. Creating a hero sends the chosen name, race
and class; the server applies them only to a brand-new account. Deleting a slot on a
phone forgets its token locally; the account itself stays on the server.

## What the server checks

- Shared world: `GuanlinLayout` bounds and buildings/palisade as the collision map,
  `GuanlinSpawns` monsters with `Balance` numbers, identical on client and server.
- Identity: random 256-bit device token, stored hashed; payloads cannot pick another
  account or upload stats, items or currency (see `docs/lan-social.md`).
- Requests are rate-limited (20/s per peer) and size-capped (8 KB).

## Checks

```
python tools/check_dedicated.py        # headless server + separate client process
python tools/check_world_transport.py  # two clients, movement, duel
python tools/run_checks.py
```

## Not yet

- Public internet accounts (passwords, recovery) — the token model is for trusted
  Tailscale peers.
- Running as a Windows service or scheduled task (start `Run_Server.bat` manually or
  from the Startup folder for now).
- Moving an offline save onto the server.
