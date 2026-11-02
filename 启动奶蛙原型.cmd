@echo off
chcp 65001 >nul
setlocal
set "NAIWA_ROOT=%~dp0"
set "NAIWA_EXE=%NAIWA_ROOT%desktop\lin4run\奶蛙桌宠-联动版.exe"
if not exist "%NAIWA_EXE%" (
  echo 请先运行 desktop\lin4run\build.ps1 构建联动版桌宠。
  pause
  exit /b 1
)
start "" "%NAIWA_EXE%"
