#requires -Version 5.1

[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://bygog.github.io/Tamga'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $env:TEMP ("Tamga-bootstrap-test-{0}" -f [Guid]::NewGuid().ToString('N'))

try {
    & (Join-Path $root 'install.ps1') -BaseUrl $BaseUrl -InstallDirectory $target -NoLaunch
    $required = @(
        'Tamga.ps1','Tamga.bat','catalog.json',
        'assets\tamga-logo.png','assets\tamga-logo.ico','assets\winget-ready.png',
        'assets\about-icon.png','assets\link-icon.png','assets\uninstall-icon.png',
        'assets\security-center-icon.png','assets\update-center-icon.png'
    )
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $target $_)) })
    if ($missing.Count -gt 0) { throw "Kurucu eksik dosya bıraktı: $($missing -join ', ')" }

    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $target 'Tamga.ps1'), [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { throw "İndirilen Tamga.ps1 ayrıştırılamadı: $($errors.Message -join '; ')" }
    $downloadedScript = [IO.File]::ReadAllText((Join-Path $target 'Tamga.ps1'), [Text.Encoding]::UTF8)
    if (-not $downloadedScript.Contains('function Export-TamgaRecipe')) { throw 'İndirilen Tamga sürümünde Reçete özelliği bulunamadı.' }
    if ($downloadedScript.Contains('AddFontResourceEx') -or $downloadedScript.Contains('RemoveFontResourceEx')) { throw 'İndirilen Tamga sürümü kullanıcı yazı tiplerine müdahale edebilir.' }

    $catalog = Get-Content -LiteralPath (Join-Path $target 'catalog.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$catalog.SchemaVersion -ne 1 -or @($catalog.Applications).Count -eq 0) { throw 'İndirilen katalog geçersiz.' }
    Write-Host "Tamga kurucu duman testi başarılı: $(@($catalog.Applications).Count) katalog kaydı." -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
}
