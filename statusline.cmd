@echo off
REM Statusline launcher. Uses python from PATH by default.
REM If python isn't on PATH, replace `python` below with full path,
REM e.g. "%USERPROFILE%\AppData\Local\Programs\Python\Python312\python.exe"
python "%USERPROFILE%\.claude\statusline.py"
