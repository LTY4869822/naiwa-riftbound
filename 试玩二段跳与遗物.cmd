@echo off
chcp 65001 >nul
set "NAIWA_ECHO_ROOT=%~dp0"
start "" "%NAIWA_ECHO_ROOT%tools\Godot_v4.7.2-stable_win64.exe" --path "%NAIWA_ECHO_ROOT%prototype" -- --slice-test --echo-demo
