@echo off
REM Rebuilds js/photos.js from the photos/ folder. Double-click me after
REM adding a game's frames.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build-photos.ps1"
echo.
pause
