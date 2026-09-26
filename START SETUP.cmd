@echo off
cd /d "%~dp0"
if not exist "%~dp0Install-KHUX.ps1" (
  echo Extract the whole ZIP first, then run START SETUP.cmd.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-KHUX.ps1"
pause
