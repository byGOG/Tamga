#requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$StrictWarnings
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = [Collections.Generic.List[string]]::new()
$warnings = [Collections.Generic.List[string]]::new()
$checks = 0

function Assert-Tamga {
    param([bool]$Condition, [string]$Message)
    $script:checks++
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Test-PowerShellFile {
    param([string]$RelativePath)
    $path = Join-Path $root $RelativePath
    $tokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    Assert-Tamga ($parseErrors.Count -eq 0) "$RelativePath PowerShell sözdizimi hatası içeriyor: $($parseErrors.Message -join '; ')"
}

foreach ($file in @('Tamga.ps1','install.ps1','tools\Test-Tamga.ps1','tools\Test-TamgaBootstrap.ps1')) { Test-PowerShellFile $file }

$scriptPath = Join-Path $root 'Tamga.ps1'
$scriptText = [IO.File]::ReadAllText($scriptPath, [Text.Encoding]::UTF8)
$xamlMatch = [regex]::Match($scriptText, "(?s)\[xml\]\`$xaml\s*=\s*@'\r?\n(.*?)\r?\n'@")
Assert-Tamga $xamlMatch.Success 'Tamga.ps1 içindeki ana XAML bloğu bulunamadı.'
if ($xamlMatch.Success) {
    try {
        [xml]$xamlDocument = $xamlMatch.Groups[1].Value
        Assert-Tamga ($null -ne $xamlDocument.DocumentElement) 'Ana XAML belgesi boş.'
        $names = @([regex]::Matches($xamlMatch.Groups[1].Value, 'x:Name="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
        # PART_* adları farklı ControlTemplate kapsamlarında yinelenebilir.
        $duplicateNames = @($names | Where-Object { $_ -notlike 'PART_*' } | Group-Object | Where-Object Count -gt 1)
        Assert-Tamga ($duplicateNames.Count -eq 0) "XAML içinde yinelenen x:Name var: $($duplicateNames.Name -join ', ')"
    } catch {
        $failures.Add("Ana XAML ayrıştırılamadı: $($_.Exception.Message)")
    }

    # XAML yalnızca XML olarak değil, gerçek WPF nesne ağacı olarak da yüklenebilmelidir.
    $temporaryXaml = Join-Path $env:TEMP ("Tamga-xaml-{0}.xaml" -f [Guid]::NewGuid().ToString('N'))
    $temporaryValidator = Join-Path $env:TEMP ("Tamga-xaml-{0}.ps1" -f [Guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText($temporaryXaml, $xamlMatch.Groups[1].Value, [Text.UTF8Encoding]::new($false))
        $validatorSource = @'
param([Parameter(Mandatory)][string]$XamlPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
[xml]$document = Get-Content -LiteralPath $XamlPath -Raw -Encoding UTF8
$reader = [Xml.XmlNodeReader]::new($document)
$window = [Windows.Markup.XamlReader]::Load($reader)
if (-not $window) { throw 'WPF pencere nesnesi oluşturulamadı.' }
$window.Close()
'@
        [IO.File]::WriteAllText($temporaryValidator, $validatorSource, [Text.UTF8Encoding]::new($false))
        $process = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',('"{0}"' -f $temporaryValidator),'-XamlPath',('"{0}"' -f $temporaryXaml)) -WindowStyle Hidden -Wait -PassThru
        Assert-Tamga ($process.ExitCode -eq 0) "Ana XAML, WPF çalışma zamanı tarafından yüklenemedi (kod: $($process.ExitCode))."
    } catch {
        $failures.Add("WPF XAML doğrulaması çalıştırılamadı: $($_.Exception.Message)")
    } finally {
        Remove-Item -LiteralPath $temporaryXaml,$temporaryValidator -Force -ErrorAction SilentlyContinue
    }
}

$catalogPath = Join-Path $root 'catalog.json'
$logosPath = Join-Path $root 'logos.json'
try { $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $failures.Add("catalog.json okunamadı: $($_.Exception.Message)") }
try { $logos = Get-Content -LiteralPath $logosPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $failures.Add("logos.json okunamadı: $($_.Exception.Message)") }

if ($catalog) {
    Assert-Tamga ([int]$catalog.SchemaVersion -eq 1) 'Katalog şema sürümü 1 olmalı.'
    $categories = @($catalog.Categories)
    $applications = @($catalog.Applications)
    Assert-Tamga ($categories.Count -gt 0) 'Katalog kategori içermiyor.'
    Assert-Tamga ($applications.Count -gt 0) 'Katalog uygulama içermiyor.'
    Assert-Tamga (@($categories | Group-Object Name | Where-Object Count -gt 1).Count -eq 0) 'Katalogda yinelenen kategori adı var.'
    Assert-Tamga (@($applications | Group-Object Name | Where-Object Count -gt 1).Count -eq 0) 'Katalogda yinelenen uygulama adı var.'
    Assert-Tamga (@($applications | Where-Object Id | Group-Object Id | Where-Object Count -gt 1).Count -eq 0) 'Katalogda yinelenen paket kimliği var.'
    $categoryNames = @($categories.Name)

    foreach ($app in $applications) {
        Assert-Tamga (-not [string]::IsNullOrWhiteSpace([string]$app.Name)) 'Adsız uygulama kaydı bulundu.'
        Assert-Tamga (-not [string]::IsNullOrWhiteSpace([string]$app.Description)) "$($app.Name): açıklama eksik."
        Assert-Tamga ($categoryNames -contains [string]$app.Category) "$($app.Name): bilinmeyen kategori '$($app.Category)'."
        Assert-Tamga (-not [string]::IsNullOrWhiteSpace([string]$app.Initial)) "$($app.Name): Initial eksik."
        Assert-Tamga ([string]$app.Color -match '^#[0-9A-Fa-f]{6}$') "$($app.Name): Color #RRGGBB biçiminde olmalı."
        $action = [string]$app.Action
        Assert-Tamga (@('','Url','PowerShell') -contains $action) "$($app.Name): bilinmeyen eylem türü '$action'."
        if ($action -eq 'Url') {
            Assert-Tamga ([string]$app.Url -match '^https://') "$($app.Name): internet adresi HTTPS olmalı."
        } elseif ($action -eq 'PowerShell') {
            Assert-Tamga (-not [string]::IsNullOrWhiteSpace([string]$app.Command)) "$($app.Name): PowerShell komutu eksik."
            Assert-Tamga ([string]$app.Url -match '^https://') "$($app.Name): resmî internet adresi HTTPS olmalı."
            Assert-Tamga ([string]$app.Category -eq 'Betikler & Otomasyon') "$($app.Name): PowerShell eylemleri Betikler & Otomasyon kategorisinde olmalı."
        } else {
            Assert-Tamga (-not [string]::IsNullOrWhiteSpace([string]$app.Id)) "$($app.Name): WinGet kimliği eksik."
        }
        foreach ($dependency in @($app.AdditionalPackages | Where-Object { $null -ne $_ })) {
            Assert-Tamga (-not [string]::IsNullOrWhiteSpace([string]$dependency.Id)) "$($app.Name): ek paket kimliği eksik."
            Assert-Tamga (-not [string]::IsNullOrWhiteSpace([string]$dependency.Name)) "$($app.Name): ek paket adı eksik."
        }
    }

    foreach ($website in $catalog.OfficialWebsites.PSObject.Properties) {
        Assert-Tamga ([string]$website.Value -match '^https://') "$($website.Name): resmî site HTTPS olmalı."
    }

    if ($logos) {
        $logoKeys = @($logos.PSObject.Properties.Name)
        $localOverrides = @('PerformanceTest','Buster','YouTube Auto HD + FPS','Win11Debloat','Bibata Modern Ice Cursor')
        foreach ($app in $applications) {
            $key = if ($app.LogoKey) { [string]$app.LogoKey } else { [string]$app.Name }
            if ($logoKeys -notcontains $key -and $localOverrides -notcontains [string]$app.Name) {
                $warnings.Add("$($app.Name): logos.json veya yerel varlık eşlemesi bulunamadı.")
            }
        }
    }
}

foreach ($asset in @('tamga-logo.png','tamga-logo.ico','winget-ready.png','about-icon.png','link-icon.png','uninstall-icon.png','security-center-icon.png','update-center-icon.png')) {
    Assert-Tamga (Test-Path -LiteralPath (Join-Path $root "assets\$asset")) "Eksik arayüz varlığı: assets/$asset"
}

$installBytes = [IO.File]::ReadAllBytes((Join-Path $root 'install.ps1'))
$onlineBytes = [IO.File]::ReadAllBytes((Join-Path $root 'Tamga-Online.bat'))
Assert-Tamga (-not ($installBytes.Length -ge 3 -and $installBytes[0] -eq 0xEF -and $installBytes[1] -eq 0xBB -and $installBytes[2] -eq 0xBF)) 'install.ps1 UTF-8 BOM içermemeli; irm | iex bunu komut olarak okuyabilir.'
Assert-Tamga (-not ($onlineBytes.Length -ge 3 -and $onlineBytes[0] -eq 0xEF -and $onlineBytes[1] -eq 0xBB -and $onlineBytes[2] -eq 0xBF)) 'Tamga-Online.bat UTF-8 BOM içermemeli.'
Assert-Tamga ($scriptText -notmatch 'CurrentVersion\\Fonts|AddFontResourceEx|RemoveFontResourceEx|Tamga-Inter') 'Tamga kullanıcı yazı tiplerini veya font kayıt defterini değiştirmemeli.'
Assert-Tamga ($scriptText -notmatch 'Set-ExecutionPolicy') 'Tamga kalıcı ExecutionPolicy değişikliği yapmamalı.'

if ($warnings.Count -gt 0) {
    Write-Host "`nUyarılar ($($warnings.Count))" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
if ($failures.Count -gt 0 -or ($StrictWarnings -and $warnings.Count -gt 0)) {
    Write-Host "`nBaşarısız denetimler ($($failures.Count))" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "`nTamga kalite kapısı başarılı: $checks denetim, $($warnings.Count) uyarı." -ForegroundColor Green
exit 0
