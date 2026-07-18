# PowerHub bootstrapper
# Usage: irm https://bygog.github.io/PowerHub/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$baseUrl = 'https://bygog.github.io/PowerHub'
$installDirectory = Join-Path $env:LOCALAPPDATA 'PowerHub'
$applicationScript = Join-Path $installDirectory 'PowerHub.ps1'
$applicationCatalog = Join-Path $installDirectory 'catalog.json'
$applicationAssets = Join-Path $installDirectory 'assets'
$applicationLogo = Join-Path $applicationAssets 'powerhub-logo.png'
$applicationIcon = Join-Path $applicationAssets 'powerhub-logo.ico'
$applicationPowerShellLogo = Join-Path $applicationAssets 'powershell-logo.png'
$applicationHwinfoLogo = Join-Path $applicationAssets 'hwinfo-logo.png'
$applicationCpuZLogo = Join-Path $applicationAssets 'cpuz-logo.png'
$applicationGpuZLogo = Join-Path $applicationAssets 'gpuz-logo.png'
$applicationOcctLogo = Join-Path $applicationAssets 'occt-logo.png'
$applicationPerformanceTestLogo = Join-Path $applicationAssets 'performancetest-logo.png'
$applicationBurnInTestLogo = Join-Path $applicationAssets 'burnintest-logo.png'
$applicationFurMarkLogo = Join-Path $applicationAssets 'furmark-logo.png'
$applicationWingetReadyIcon = Join-Path $applicationAssets 'winget-ready.png'
$applicationAboutIcon = Join-Path $applicationAssets 'about-icon.png'

if (-not (Test-Path -LiteralPath $installDirectory)) {
    New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $applicationAssets)) {
    New-Item -ItemType Directory -Path $applicationAssets -Force | Out-Null
}

$cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$scriptDownloadUrl = '{0}/PowerHub.ps1?v={1}' -f $baseUrl, $cacheBuster
$catalogDownloadUrl = '{0}/catalog.json?v={1}' -f $baseUrl, $cacheBuster
$logoDownloadUrl = '{0}/assets/powerhub-logo.png?v={1}' -f $baseUrl, $cacheBuster
$iconDownloadUrl = '{0}/assets/powerhub-logo.ico?v={1}' -f $baseUrl, $cacheBuster
$powerShellLogoDownloadUrl = '{0}/assets/powershell-logo.png?v={1}' -f $baseUrl, $cacheBuster
$hwinfoLogoDownloadUrl = '{0}/assets/hwinfo-logo.png?v={1}' -f $baseUrl, $cacheBuster
$cpuZLogoDownloadUrl = '{0}/assets/cpuz-logo.png?v={1}' -f $baseUrl, $cacheBuster
$gpuZLogoDownloadUrl = '{0}/assets/gpuz-logo.png?v={1}' -f $baseUrl, $cacheBuster
$occtLogoDownloadUrl = '{0}/assets/occt-logo.png?v={1}' -f $baseUrl, $cacheBuster
$performanceTestLogoDownloadUrl = '{0}/assets/performancetest-logo.png?v={1}' -f $baseUrl, $cacheBuster
$burnInTestLogoDownloadUrl = '{0}/assets/burnintest-logo.png?v={1}' -f $baseUrl, $cacheBuster
$furMarkLogoDownloadUrl = '{0}/assets/furmark-logo.png?v={1}' -f $baseUrl, $cacheBuster
$wingetReadyIconDownloadUrl = '{0}/assets/winget-ready.png?v={1}' -f $baseUrl, $cacheBuster
$aboutIconDownloadUrl = '{0}/assets/about-icon.png?v={1}' -f $baseUrl, $cacheBuster
$temporaryScript = Join-Path $installDirectory 'PowerHub.ps1.download'
$temporaryCatalog = Join-Path $installDirectory 'catalog.json.download'
$temporaryLogo = Join-Path $installDirectory 'powerhub-logo.png.download'
$temporaryIcon = Join-Path $installDirectory 'powerhub-logo.ico.download'
$temporaryPowerShellLogo = Join-Path $installDirectory 'powershell-logo.png.download'
$temporaryHwinfoLogo = Join-Path $installDirectory 'hwinfo-logo.png.download'
$temporaryCpuZLogo = Join-Path $installDirectory 'cpuz-logo.png.download'
$temporaryGpuZLogo = Join-Path $installDirectory 'gpuz-logo.png.download'
$temporaryOcctLogo = Join-Path $installDirectory 'occt-logo.png.download'
$temporaryPerformanceTestLogo = Join-Path $installDirectory 'performancetest-logo.png.download'
$temporaryBurnInTestLogo = Join-Path $installDirectory 'burnintest-logo.png.download'
$temporaryFurMarkLogo = Join-Path $installDirectory 'furmark-logo.png.download'
$temporaryWingetReadyIcon = Join-Path $installDirectory 'winget-ready.png.download'
$temporaryAboutIcon = Join-Path $installDirectory 'about-icon.png.download'

try {
    Invoke-WebRequest -UseBasicParsing -Uri $scriptDownloadUrl -OutFile $temporaryScript
    Invoke-WebRequest -UseBasicParsing -Uri $catalogDownloadUrl -OutFile $temporaryCatalog
    Invoke-WebRequest -UseBasicParsing -Uri $logoDownloadUrl -OutFile $temporaryLogo
    Invoke-WebRequest -UseBasicParsing -Uri $iconDownloadUrl -OutFile $temporaryIcon
    Invoke-WebRequest -UseBasicParsing -Uri $powerShellLogoDownloadUrl -OutFile $temporaryPowerShellLogo
    Invoke-WebRequest -UseBasicParsing -Uri $hwinfoLogoDownloadUrl -OutFile $temporaryHwinfoLogo
    Invoke-WebRequest -UseBasicParsing -Uri $cpuZLogoDownloadUrl -OutFile $temporaryCpuZLogo
    Invoke-WebRequest -UseBasicParsing -Uri $gpuZLogoDownloadUrl -OutFile $temporaryGpuZLogo
    Invoke-WebRequest -UseBasicParsing -Uri $occtLogoDownloadUrl -OutFile $temporaryOcctLogo
    Invoke-WebRequest -UseBasicParsing -Uri $performanceTestLogoDownloadUrl -OutFile $temporaryPerformanceTestLogo
    Invoke-WebRequest -UseBasicParsing -Uri $burnInTestLogoDownloadUrl -OutFile $temporaryBurnInTestLogo
    Invoke-WebRequest -UseBasicParsing -Uri $furMarkLogoDownloadUrl -OutFile $temporaryFurMarkLogo
    Invoke-WebRequest -UseBasicParsing -Uri $wingetReadyIconDownloadUrl -OutFile $temporaryWingetReadyIcon
    Invoke-WebRequest -UseBasicParsing -Uri $aboutIconDownloadUrl -OutFile $temporaryAboutIcon

    $catalog = Get-Content -LiteralPath $temporaryCatalog -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($catalog.SchemaVersion -ne 1 -or @($catalog.Applications).Count -eq 0) {
        throw 'İndirilen PowerHub kataloğu geçerli değil.'
    }

    Move-Item -LiteralPath $temporaryScript -Destination $applicationScript -Force
    Move-Item -LiteralPath $temporaryCatalog -Destination $applicationCatalog -Force
    Move-Item -LiteralPath $temporaryLogo -Destination $applicationLogo -Force
    Move-Item -LiteralPath $temporaryIcon -Destination $applicationIcon -Force
    Move-Item -LiteralPath $temporaryPowerShellLogo -Destination $applicationPowerShellLogo -Force
    Move-Item -LiteralPath $temporaryHwinfoLogo -Destination $applicationHwinfoLogo -Force
    Move-Item -LiteralPath $temporaryCpuZLogo -Destination $applicationCpuZLogo -Force
    Move-Item -LiteralPath $temporaryGpuZLogo -Destination $applicationGpuZLogo -Force
    Move-Item -LiteralPath $temporaryOcctLogo -Destination $applicationOcctLogo -Force
    Move-Item -LiteralPath $temporaryPerformanceTestLogo -Destination $applicationPerformanceTestLogo -Force
    Move-Item -LiteralPath $temporaryBurnInTestLogo -Destination $applicationBurnInTestLogo -Force
    Move-Item -LiteralPath $temporaryFurMarkLogo -Destination $applicationFurMarkLogo -Force
    Move-Item -LiteralPath $temporaryWingetReadyIcon -Destination $applicationWingetReadyIcon -Force
    Move-Item -LiteralPath $temporaryAboutIcon -Destination $applicationAboutIcon -Force
} finally {
    Remove-Item -LiteralPath $temporaryScript, $temporaryCatalog, $temporaryLogo, $temporaryIcon, $temporaryPowerShellLogo, $temporaryHwinfoLogo, $temporaryCpuZLogo, $temporaryGpuZLogo, $temporaryOcctLogo, $temporaryPerformanceTestLogo, $temporaryBurnInTestLogo, $temporaryFurMarkLogo, $temporaryWingetReadyIcon, $temporaryAboutIcon -Force -ErrorAction SilentlyContinue
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
