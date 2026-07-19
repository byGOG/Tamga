@echo off
setlocal

set "TAMGA_SCRIPT=%~dp0Tamga.ps1"

if not exist "%TAMGA_SCRIPT%" (
    echo Tamga.ps1 bulunamadi.
    echo BAT dosyasini Tamga.ps1 ile ayni klasorde tutun.
    pause
    exit /b 1
)

start "Tamga" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%TAMGA_SCRIPT%"
exit /b 0
