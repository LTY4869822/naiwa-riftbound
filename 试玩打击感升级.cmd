@echo off
chcp 65001 >nul
set "NAIWA_PUNCH_ROOT=%~dp0"
start "" "%NAIWA_PUNCH_ROOT%tools\Godot_v4.7.2-stable_win64.exe" --path "%NAIWA_PUNCH_ROOT%prototype" -- --slice-test --punch-demo
