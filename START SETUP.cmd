@echo off
cd /d "%~dp0"
if not exist "%~dp0START SETUP.vbs" (
  echo Extract the entire ZIP first.
  pause
  exit /b 1
)
wscript.exe "%~dp0START SETUP.vbs"
