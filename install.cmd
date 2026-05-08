@echo off
REM Double-click runner for install.ps1 (skips ExecutionPolicy hassle).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
