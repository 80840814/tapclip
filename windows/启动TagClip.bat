@echo off
rem TagClip launcher: run TagClip.ps1 without a console window
setlocal
cd /d "%~dp0"
if not exist "%~dp0TagClip.ps1" (
    echo Cannot find TagClip.ps1. Make sure it is in the same folder.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0TagClip.ps1"
