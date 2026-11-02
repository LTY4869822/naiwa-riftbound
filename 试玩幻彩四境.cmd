@echo off
chcp 65001 >nul
set "NAIWA_BIOME_ROOT=%~dp0"
start "" "%NAIWA_BIOME_ROOT%tools\Godot_v4.7.2-stable_win64.exe" --path "%NAIWA_BIOME_ROOT%prototype" -- --slice-test --biome-demo
