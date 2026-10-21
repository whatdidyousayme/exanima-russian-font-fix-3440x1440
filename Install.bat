@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-FontFix.ps1"
if errorlevel 1 (
  echo.
  echo Installation stopped. See the message above.
)
echo.
pause

