@echo off
setlocal

set "POWERHUB_SCRIPT=%~dp0PowerHub.ps1"

if not exist "%POWERHUB_SCRIPT%" (
    echo PowerHub.ps1 bulunamadi.
    echo BAT dosyasini PowerHub.ps1 ile ayni klasorde tutun.
    pause
    exit /b 1
)

start "PowerHub" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%POWERHUB_SCRIPT%"
exit /b 0
