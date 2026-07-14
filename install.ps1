# PowerHub bootstrapper
# Usage: irm https://bygog.github.io/PowerHub/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$baseUrl = 'https://bygog.github.io/PowerHub'
$installDirectory = Join-Path $env:LOCALAPPDATA 'PowerHub'
$applicationScript = Join-Path $installDirectory 'PowerHub.ps1'

if (-not (Test-Path -LiteralPath $installDirectory)) {
    New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
}

$downloadUrl = '{0}/PowerHub.ps1?v={1}' -f $baseUrl, [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile $applicationScript

$windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $windowsPowerShell)) {
    $windowsPowerShell = 'powershell.exe'
}

Start-Process -FilePath $windowsPowerShell -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-STA',
    '-File', ('"{0}"' -f $applicationScript)
)

Write-Host 'PowerHub started.' -ForegroundColor Cyan
