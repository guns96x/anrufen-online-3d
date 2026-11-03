@echo off
title Covenant Chronicles 3D Launcher
cd /d "%~dp0"
set "GODOT_EXE=C:\Users\pavlo\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_EXE%" (
    start "" "%GODOT_EXE%" --path "%~dp0"
) else (
    echo Godot executable not found at %GODOT_EXE%
    pause
)
