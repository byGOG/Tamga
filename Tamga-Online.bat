@echo off
setlocal
title Tamga Cevrimici Baslatici

echo Tamga'in en guncel surumu indiriliyor...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $installer=Join-Path $env:TEMP ('Tamga-install-' + [Guid]::NewGuid().ToString('N') + '.ps1'); try { Invoke-WebRequest -UseBasicParsing 'https://bygog.github.io/Tamga/install.ps1' -OutFile $installer; & $installer } catch { Write-Host ('Tamga baslatilamadi: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 } finally { Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue }"

if errorlevel 1 (
    echo.
    echo Internet baglantinizi kontrol edip yeniden deneyin.
    pause
    exit /b 1
)

exit /b 0
