@echo off
setlocal
title PowerHub Cevrimici Baslatici

echo PowerHub'in en guncel surumu indiriliyor...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { Invoke-RestMethod 'https://bygog.github.io/PowerHub/install.ps1' | Invoke-Expression } catch { Write-Host ('PowerHub baslatilamadi: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"

if errorlevel 1 (
    echo.
    echo Internet baglantinizi kontrol edip yeniden deneyin.
    pause
    exit /b 1
)

exit /b 0
