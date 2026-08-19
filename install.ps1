# Tamga bootstrapper
# Usage: irm https://bygog.github.io/Tamga/install.ps1 | iex

param(
    [string]$BaseUrl = 'https://bygog.github.io/Tamga',
    [string]$InstallDirectory,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'

$baseUrl = $BaseUrl.TrimEnd('/')
$customInstallDirectory = -not [string]::IsNullOrWhiteSpace($InstallDirectory)
$installDirectory = if ($customInstallDirectory) { [IO.Path]::GetFullPath($InstallDirectory) } else { Join-Path $env:LOCALAPPDATA 'Tamga' }
$legacyInstallDirectory = Join-Path $env:LOCALAPPDATA 'PowerHub'
$applicationScript = Join-Path $installDirectory 'Tamga.ps1'
$applicationLauncher = Join-Path $installDirectory 'Tamga.bat'
$applicationCatalog = Join-Path $installDirectory 'catalog.json'
$applicationVersion = Join-Path $installDirectory 'version.json'
$applicationAssets = Join-Path $installDirectory 'assets'
$applicationLogo = Join-Path $applicationAssets 'tamga-logo.png'
$applicationIcon = Join-Path $applicationAssets 'tamga-logo.ico'
$applicationPowerShellLogo = Join-Path $applicationAssets 'powershell-logo.png'
$applicationHwinfoLogo = Join-Path $applicationAssets 'hwinfo-logo.png'
$applicationCpuZLogo = Join-Path $applicationAssets 'cpuz-logo.png'
$applicationGpuZLogo = Join-Path $applicationAssets 'gpuz-logo.png'
$applicationOcctLogo = Join-Path $applicationAssets 'occt-logo.png'
$applicationPerformanceTestLogo = Join-Path $applicationAssets 'performancetest-logo.png'
$applicationBurnInTestLogo = Join-Path $applicationAssets 'burnintest-logo.png'
$applicationFurMarkLogo = Join-Path $applicationAssets 'furmark-logo.png'
$applicationPicViewLogo = Join-Path $applicationAssets 'picview-logo.png'
$applicationNeoFreeBirdLogo = Join-Path $applicationAssets 'neofreebird-logo.png'
$applicationBibataModernIceLogo = Join-Path $applicationAssets 'bibata-modern-ice-logo.png'
$applicationWin11DebloatLogo = Join-Path $applicationAssets 'win11debloat-logo.png'
$applicationBusterLogo = Join-Path $applicationAssets 'buster-logo.png'
$applicationCrystalDiskInfoLogo = Join-Path $applicationAssets 'crystaldiskinfo-logo.png'
$applicationDesktopIconsInstallerLogo = Join-Path $applicationAssets 'windows-desktop-icons-installer-logo.png'
$applicationICloudLogo = Join-Path $applicationAssets 'icloud-logo.png'
$applicationAppleMusicLogo = Join-Path $applicationAssets 'apple-music-logo.png'
$applicationAppleDevicesLogo = Join-Path $applicationAssets 'apple-devices-logo.png'
$applicationITunesLogo = Join-Path $applicationAssets 'itunes-logo.png'
$applicationWingetReadyIcon = Join-Path $applicationAssets 'winget-ready.png'
$applicationAboutIcon = Join-Path $applicationAssets 'about-icon.png'
$applicationLinkIcon = Join-Path $applicationAssets 'link-icon.png'
$applicationUninstallIcon = Join-Path $applicationAssets 'uninstall-icon.png'
$applicationSecurityCenterIcon = Join-Path $applicationAssets 'security-center-icon.png'
$applicationUpdateCenterIcon = Join-Path $applicationAssets 'update-center-icon.png'

if (-not $customInstallDirectory -and (Test-Path -LiteralPath $legacyInstallDirectory) -and -not (Test-Path -LiteralPath $installDirectory)) {
    try {
        Move-Item -LiteralPath $legacyInstallDirectory -Destination $installDirectory -Force
        Write-Host 'Eski PowerHub kurulumu Tamga dizinine tasindi.' -ForegroundColor DarkCyan
    } catch {
        Write-Host ('Eski PowerHub kurulumu tasinamadi; Tamga temiz kurulacak: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

if (-not (Test-Path -LiteralPath $installDirectory)) {
    New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $applicationAssets)) {
    New-Item -ItemType Directory -Path $applicationAssets -Force | Out-Null
}

$cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$scriptDownloadUrl = '{0}/Tamga.ps1?v={1}' -f $baseUrl, $cacheBuster
$launcherDownloadUrl = '{0}/Tamga.bat?v={1}' -f $baseUrl, $cacheBuster
$catalogDownloadUrl = '{0}/catalog.json?v={1}' -f $baseUrl, $cacheBuster
$versionDownloadUrl = '{0}/version.json?v={1}' -f $baseUrl, $cacheBuster
$logoDownloadUrl = '{0}/assets/tamga-logo.png?v={1}' -f $baseUrl, $cacheBuster
$iconDownloadUrl = '{0}/assets/tamga-logo.ico?v={1}' -f $baseUrl, $cacheBuster
$powerShellLogoDownloadUrl = '{0}/assets/powershell-logo.png?v={1}' -f $baseUrl, $cacheBuster
$hwinfoLogoDownloadUrl = '{0}/assets/hwinfo-logo.png?v={1}' -f $baseUrl, $cacheBuster
$cpuZLogoDownloadUrl = '{0}/assets/cpuz-logo.png?v={1}' -f $baseUrl, $cacheBuster
$gpuZLogoDownloadUrl = '{0}/assets/gpuz-logo.png?v={1}' -f $baseUrl, $cacheBuster
$occtLogoDownloadUrl = '{0}/assets/occt-logo.png?v={1}' -f $baseUrl, $cacheBuster
$performanceTestLogoDownloadUrl = '{0}/assets/performancetest-logo.png?v={1}' -f $baseUrl, $cacheBuster
$burnInTestLogoDownloadUrl = '{0}/assets/burnintest-logo.png?v={1}' -f $baseUrl, $cacheBuster
$furMarkLogoDownloadUrl = '{0}/assets/furmark-logo.png?v={1}' -f $baseUrl, $cacheBuster
$picViewLogoDownloadUrl = '{0}/assets/picview-logo.png?v={1}' -f $baseUrl, $cacheBuster
$neoFreeBirdLogoDownloadUrl = '{0}/assets/neofreebird-logo.png?v={1}' -f $baseUrl, $cacheBuster
$bibataModernIceLogoDownloadUrl = '{0}/assets/bibata-modern-ice-logo.png?v={1}' -f $baseUrl, $cacheBuster
$win11DebloatLogoDownloadUrl = '{0}/assets/win11debloat-logo.png?v={1}' -f $baseUrl, $cacheBuster
$busterLogoDownloadUrl = '{0}/assets/buster-logo.png?v={1}' -f $baseUrl, $cacheBuster
$crystalDiskInfoLogoDownloadUrl = '{0}/assets/crystaldiskinfo-logo.png?v={1}' -f $baseUrl, $cacheBuster
$desktopIconsInstallerLogoDownloadUrl = '{0}/assets/windows-desktop-icons-installer-logo.png?v={1}' -f $baseUrl, $cacheBuster
$iCloudLogoDownloadUrl = '{0}/assets/icloud-logo.png?v={1}' -f $baseUrl, $cacheBuster
$appleMusicLogoDownloadUrl = '{0}/assets/apple-music-logo.png?v={1}' -f $baseUrl, $cacheBuster
$appleDevicesLogoDownloadUrl = '{0}/assets/apple-devices-logo.png?v={1}' -f $baseUrl, $cacheBuster
$iTunesLogoDownloadUrl = '{0}/assets/itunes-logo.png?v={1}' -f $baseUrl, $cacheBuster
$wingetReadyIconDownloadUrl = '{0}/assets/winget-ready.png?v={1}' -f $baseUrl, $cacheBuster
$aboutIconDownloadUrl = '{0}/assets/about-icon.png?v={1}' -f $baseUrl, $cacheBuster
$linkIconDownloadUrl = '{0}/assets/link-icon.png?v={1}' -f $baseUrl, $cacheBuster
$uninstallIconDownloadUrl = '{0}/assets/uninstall-icon.png?v={1}' -f $baseUrl, $cacheBuster
$securityCenterIconDownloadUrl = '{0}/assets/security-center-icon.png?v={1}' -f $baseUrl, $cacheBuster
$updateCenterIconDownloadUrl = '{0}/assets/update-center-icon.png?v={1}' -f $baseUrl, $cacheBuster
$temporaryScript = Join-Path $installDirectory 'Tamga.ps1.download'
$temporaryLauncher = Join-Path $installDirectory 'Tamga.bat.download'
$temporaryCatalog = Join-Path $installDirectory 'catalog.json.download'
$temporaryVersion = Join-Path $installDirectory 'version.json.download'
$temporaryLogo = Join-Path $installDirectory 'tamga-logo.png.download'
$temporaryIcon = Join-Path $installDirectory 'tamga-logo.ico.download'
$temporaryPowerShellLogo = Join-Path $installDirectory 'powershell-logo.png.download'
$temporaryHwinfoLogo = Join-Path $installDirectory 'hwinfo-logo.png.download'
$temporaryCpuZLogo = Join-Path $installDirectory 'cpuz-logo.png.download'
$temporaryGpuZLogo = Join-Path $installDirectory 'gpuz-logo.png.download'
$temporaryOcctLogo = Join-Path $installDirectory 'occt-logo.png.download'
$temporaryPerformanceTestLogo = Join-Path $installDirectory 'performancetest-logo.png.download'
$temporaryBurnInTestLogo = Join-Path $installDirectory 'burnintest-logo.png.download'
$temporaryFurMarkLogo = Join-Path $installDirectory 'furmark-logo.png.download'
$temporaryPicViewLogo = Join-Path $installDirectory 'picview-logo.png.download'
$temporaryNeoFreeBirdLogo = Join-Path $installDirectory 'neofreebird-logo.png.download'
$temporaryBibataModernIceLogo = Join-Path $installDirectory 'bibata-modern-ice-logo.png.download'
$temporaryWin11DebloatLogo = Join-Path $installDirectory 'win11debloat-logo.png.download'
$temporaryBusterLogo = Join-Path $installDirectory 'buster-logo.png.download'
$temporaryCrystalDiskInfoLogo = Join-Path $installDirectory 'crystaldiskinfo-logo.png.download'
$temporaryDesktopIconsInstallerLogo = Join-Path $installDirectory 'windows-desktop-icons-installer-logo.png.download'
$temporaryICloudLogo = Join-Path $installDirectory 'icloud-logo.png.download'
$temporaryAppleMusicLogo = Join-Path $installDirectory 'apple-music-logo.png.download'
$temporaryAppleDevicesLogo = Join-Path $installDirectory 'apple-devices-logo.png.download'
$temporaryITunesLogo = Join-Path $installDirectory 'itunes-logo.png.download'
$temporaryWingetReadyIcon = Join-Path $installDirectory 'winget-ready.png.download'
$temporaryAboutIcon = Join-Path $installDirectory 'about-icon.png.download'
$temporaryLinkIcon = Join-Path $installDirectory 'link-icon.png.download'
$temporaryUninstallIcon = Join-Path $installDirectory 'uninstall-icon.png.download'
$temporarySecurityCenterIcon = Join-Path $installDirectory 'security-center-icon.png.download'
$temporaryUpdateCenterIcon = Join-Path $installDirectory 'update-center-icon.png.download'

try {
    Invoke-WebRequest -UseBasicParsing -Uri $scriptDownloadUrl -OutFile $temporaryScript
    Invoke-WebRequest -UseBasicParsing -Uri $launcherDownloadUrl -OutFile $temporaryLauncher
    Invoke-WebRequest -UseBasicParsing -Uri $catalogDownloadUrl -OutFile $temporaryCatalog
    Invoke-WebRequest -UseBasicParsing -Uri $versionDownloadUrl -OutFile $temporaryVersion
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
    Invoke-WebRequest -UseBasicParsing -Uri $picViewLogoDownloadUrl -OutFile $temporaryPicViewLogo
    Invoke-WebRequest -UseBasicParsing -Uri $neoFreeBirdLogoDownloadUrl -OutFile $temporaryNeoFreeBirdLogo
    Invoke-WebRequest -UseBasicParsing -Uri $bibataModernIceLogoDownloadUrl -OutFile $temporaryBibataModernIceLogo
    Invoke-WebRequest -UseBasicParsing -Uri $win11DebloatLogoDownloadUrl -OutFile $temporaryWin11DebloatLogo
    Invoke-WebRequest -UseBasicParsing -Uri $busterLogoDownloadUrl -OutFile $temporaryBusterLogo
    Invoke-WebRequest -UseBasicParsing -Uri $crystalDiskInfoLogoDownloadUrl -OutFile $temporaryCrystalDiskInfoLogo
    Invoke-WebRequest -UseBasicParsing -Uri $desktopIconsInstallerLogoDownloadUrl -OutFile $temporaryDesktopIconsInstallerLogo
    Invoke-WebRequest -UseBasicParsing -Uri $iCloudLogoDownloadUrl -OutFile $temporaryICloudLogo
    Invoke-WebRequest -UseBasicParsing -Uri $appleMusicLogoDownloadUrl -OutFile $temporaryAppleMusicLogo
    Invoke-WebRequest -UseBasicParsing -Uri $appleDevicesLogoDownloadUrl -OutFile $temporaryAppleDevicesLogo
    Invoke-WebRequest -UseBasicParsing -Uri $iTunesLogoDownloadUrl -OutFile $temporaryITunesLogo
    Invoke-WebRequest -UseBasicParsing -Uri $wingetReadyIconDownloadUrl -OutFile $temporaryWingetReadyIcon
    Invoke-WebRequest -UseBasicParsing -Uri $aboutIconDownloadUrl -OutFile $temporaryAboutIcon
    Invoke-WebRequest -UseBasicParsing -Uri $linkIconDownloadUrl -OutFile $temporaryLinkIcon
    Invoke-WebRequest -UseBasicParsing -Uri $uninstallIconDownloadUrl -OutFile $temporaryUninstallIcon
    Invoke-WebRequest -UseBasicParsing -Uri $securityCenterIconDownloadUrl -OutFile $temporarySecurityCenterIcon
    Invoke-WebRequest -UseBasicParsing -Uri $updateCenterIconDownloadUrl -OutFile $temporaryUpdateCenterIcon

    $catalog = Get-Content -LiteralPath $temporaryCatalog -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($catalog.SchemaVersion -ne 1 -or @($catalog.Applications).Count -eq 0) {
        throw 'Indirilen Tamga katalogu gecerli degil.'
    }
    $versionManifest = Get-Content -LiteralPath $temporaryVersion -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$versionManifest.Version)) {
        throw 'Indirilen Tamga surum bilgisi gecerli degil.'
    }

    $tokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($temporaryScript, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw ('Indirilen Tamga betigi gecersiz: {0}' -f ($parseErrors.Message -join '; '))
    }
    $launcherText = [IO.File]::ReadAllText($temporaryLauncher, [Text.Encoding]::UTF8).TrimStart()
    if (-not $launcherText.StartsWith('@echo off', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Indirilen Tamga baslaticisi gecerli degil.'
    }
    $pngBytes = [IO.File]::ReadAllBytes($temporaryLogo)
    if ($pngBytes.Length -lt 8 -or $pngBytes[0] -ne 0x89 -or $pngBytes[1] -ne 0x50 -or $pngBytes[2] -ne 0x4E -or $pngBytes[3] -ne 0x47) {
        throw 'Indirilen Tamga logosu gecerli bir PNG degil.'
    }
    $icoBytes = [IO.File]::ReadAllBytes($temporaryIcon)
    if ($icoBytes.Length -lt 6 -or $icoBytes[0] -ne 0 -or $icoBytes[1] -ne 0 -or $icoBytes[2] -ne 1 -or $icoBytes[3] -ne 0) {
        throw 'Indirilen Tamga simgesi gecerli bir ICO degil.'
    }

    Move-Item -LiteralPath $temporaryScript -Destination $applicationScript -Force
    Move-Item -LiteralPath $temporaryLauncher -Destination $applicationLauncher -Force
    Move-Item -LiteralPath $temporaryCatalog -Destination $applicationCatalog -Force
    Move-Item -LiteralPath $temporaryVersion -Destination $applicationVersion -Force
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
    Move-Item -LiteralPath $temporaryPicViewLogo -Destination $applicationPicViewLogo -Force
    Move-Item -LiteralPath $temporaryNeoFreeBirdLogo -Destination $applicationNeoFreeBirdLogo -Force
    Move-Item -LiteralPath $temporaryBibataModernIceLogo -Destination $applicationBibataModernIceLogo -Force
    Move-Item -LiteralPath $temporaryWin11DebloatLogo -Destination $applicationWin11DebloatLogo -Force
    Move-Item -LiteralPath $temporaryBusterLogo -Destination $applicationBusterLogo -Force
    Move-Item -LiteralPath $temporaryCrystalDiskInfoLogo -Destination $applicationCrystalDiskInfoLogo -Force
    Move-Item -LiteralPath $temporaryDesktopIconsInstallerLogo -Destination $applicationDesktopIconsInstallerLogo -Force
    Move-Item -LiteralPath $temporaryICloudLogo -Destination $applicationICloudLogo -Force
    Move-Item -LiteralPath $temporaryAppleMusicLogo -Destination $applicationAppleMusicLogo -Force
    Move-Item -LiteralPath $temporaryAppleDevicesLogo -Destination $applicationAppleDevicesLogo -Force
    Move-Item -LiteralPath $temporaryITunesLogo -Destination $applicationITunesLogo -Force
    Move-Item -LiteralPath $temporaryWingetReadyIcon -Destination $applicationWingetReadyIcon -Force
    Move-Item -LiteralPath $temporaryAboutIcon -Destination $applicationAboutIcon -Force
    Move-Item -LiteralPath $temporaryLinkIcon -Destination $applicationLinkIcon -Force
    Move-Item -LiteralPath $temporaryUninstallIcon -Destination $applicationUninstallIcon -Force
    Move-Item -LiteralPath $temporarySecurityCenterIcon -Destination $applicationSecurityCenterIcon -Force
    Move-Item -LiteralPath $temporaryUpdateCenterIcon -Destination $applicationUpdateCenterIcon -Force
} finally {
    Remove-Item -LiteralPath $temporaryScript, $temporaryLauncher, $temporaryCatalog, $temporaryVersion, $temporaryLogo, $temporaryIcon, $temporaryPowerShellLogo, $temporaryHwinfoLogo, $temporaryCpuZLogo, $temporaryGpuZLogo, $temporaryOcctLogo, $temporaryPerformanceTestLogo, $temporaryBurnInTestLogo, $temporaryFurMarkLogo, $temporaryPicViewLogo, $temporaryNeoFreeBirdLogo, $temporaryBibataModernIceLogo, $temporaryWin11DebloatLogo, $temporaryBusterLogo, $temporaryCrystalDiskInfoLogo, $temporaryDesktopIconsInstallerLogo, $temporaryICloudLogo, $temporaryAppleMusicLogo, $temporaryAppleDevicesLogo, $temporaryITunesLogo, $temporaryWingetReadyIcon, $temporaryAboutIcon, $temporaryLinkIcon, $temporaryUninstallIcon, $temporarySecurityCenterIcon, $temporaryUpdateCenterIcon -Force -ErrorAction SilentlyContinue
}

$windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $windowsPowerShell)) {
    $windowsPowerShell = 'powershell.exe'
}

if ($NoLaunch) {
    Write-Host ('Tamga dosyalari hazirlandi: {0}' -f $installDirectory) -ForegroundColor Cyan
} else {
    Start-Process -FilePath $windowsPowerShell -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-STA',
        '-File', ('"{0}"' -f $applicationScript)
    )
    Write-Host 'Tamga baslatildi.' -ForegroundColor Cyan
}
