@echo off
rem TagClip launcher generator: recreates the launcher (launch without console)
setlocal
set "SCRIPT=%~dp0TagClip.ps1"
if not exist "%SCRIPT%" (
    echo Error: TagClip.ps1 not found. Make sure it is in the same folder.
    pause
    exit /b 1
)
(
    echo @echo off
    echo rem TagClip launcher: run TagClip.ps1 without a console window
    echo setlocal
    echo cd /d "%%~dp0"
    echo if not exist "%%~dp0TagClip.ps1" ^(
    echo     echo Cannot find TagClip.ps1. Make sure it is in the same folder.
    echo     pause
    echo     exit /b 1
    echo ^)
    echo powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%%~dp0TagClip.ps1"
) > "%~dp0启动TagClip.bat"
echo Created: %~dp0启动TagClip.bat
echo Double-click it to run TagClip (no black window).
pause
