@echo off
REM smoothline installer launcher (Windows cmd.exe)
REM Local mode: calls install.ps1 sibling.
REM Remote mode: downloads install.ps1 from the smoothline repo and runs it.

setlocal
set "REPO_BASE=https://raw.githubusercontent.com/youja2014/smoothline/main"

if exist "%~dp0install.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm '%REPO_BASE%/install.ps1' | iex"
)
endlocal
pause
