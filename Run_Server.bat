@echo off
rem Covenant Chronicles dedicated server (headless). Players join over Tailscale on port 7777.
cd /d "%~dp0"
where Godot_v4.7.2-stable_win64.exe >nul 2>nul || (echo Godot 4.7.2 is not on PATH & pause & exit /b 1)
:loop
Godot_v4.7.2-stable_win64.exe --headless --path . res://server/dedicated_server.tscn -- --port 7777 >> server.log 2>&1
echo [%date% %time%] server stopped, restarting in 5 s >> server.log
timeout /t 5 /nobreak >nul
goto loop
