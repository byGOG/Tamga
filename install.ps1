# PowerHub bootstrapper
# Usage: irm https://bygog.github.io/PowerHub/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$baseUrl = 'https://bygog.github.io/PowerHub'
$installDirectory = Join-Path $env:LOCALAPPDATA 'PowerHub'
$applicationScript = Join-Path $installDirectory 'PowerHub.ps1'
$applicationCatalog = Join-Path $installDirectory 'catalog.json'

if (-not (Test-Path -LiteralPath $installDirectory)) {
    New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
}

$cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$scriptDownloadUrl = '{0}/PowerHub.ps1?v={1}' -f $baseUrl, $cacheBuster
$catalogDownloadUrl = '{0}/catalog.json?v={1}' -f $baseUrl, $cacheBuster
$temporaryScript = Join-Path $installDirectory 'PowerHub.ps1.download'
$temporaryCatalog = Join-Path $installDirectory 'catalog.json.download'

try {
    Invoke-WebRequest -UseBasicParsing -Uri $scriptDownloadUrl -OutFile $temporaryScript
    Invoke-WebRequest -UseBasicParsing -Uri $catalogDownloadUrl -OutFile $temporaryCatalog

    $catalog = Get-Content -LiteralPath $temporaryCatalog -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($catalog.SchemaVersion -ne 1 -or @($catalog.Applications).Count -eq 0) {
        throw 'İndirilen PowerHub kataloğu geçerli değil.'
    }

    Move-Item -LiteralPath $temporaryScript -Destination $applicationScript -Force
    Move-Item -LiteralPath $temporaryCatalog -Destination $applicationCatalog -Force
} finally {
    Remove-Item -LiteralPath $temporaryScript, $temporaryCatalog -Force -ErrorAction SilentlyContinue
}

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
