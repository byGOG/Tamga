param([switch]$CheckNetwork)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $root 'catalog.json'
$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
$errors = [Collections.Generic.List[string]]::new()
$warnings = [Collections.Generic.List[string]]::new()

$apps = @($catalog.Applications)
$categoryNames = @($catalog.Categories | ForEach-Object { [string]$_.Name })
$networkTargets = [ordered]@{}
$duplicateNames = $apps | Group-Object Name | Where-Object Count -gt 1
$duplicateIds = $apps | Where-Object { $_.Id } | Group-Object Id | Where-Object Count -gt 1
foreach ($item in $duplicateNames) { $errors.Add("Yinelenen ad: $($item.Name)") }
foreach ($item in $duplicateIds) { $errors.Add("Yinelenen paket kimliği: $($item.Name)") }

foreach ($app in $apps) {
    if ([string]::IsNullOrWhiteSpace([string]$app.Name)) { $errors.Add('Adsız katalog kaydı bulundu.'); continue }
    if ([string]::IsNullOrWhiteSpace([string]$app.Category)) {
        $errors.Add("Kategori eksik: $($app.Name)")
    } elseif ([string]$app.Category -notin $categoryNames) {
        $errors.Add("Tanımsız kategori: $($app.Name) -> $($app.Category)")
    }
    $officialUrl = if ($catalog.OfficialWebsites.PSObject.Properties.Name -contains [string]$app.Name) {
        [string]$catalog.OfficialWebsites.([string]$app.Name)
    } elseif ($app.Url) { [string]$app.Url } elseif ($app.Website) { [string]$app.Website } else { '' }
    if ($officialUrl -and -not ([Uri]::IsWellFormedUriString($officialUrl, [UriKind]::Absolute))) {
        $errors.Add("Geçersiz resmî site: $($app.Name) -> $officialUrl")
    } elseif ($officialUrl) {
        $networkTargets[$officialUrl] = [string]$app.Name
    }
    if ($app.Logo -and [string]$app.Logo -match '^https://' -and -not ([Uri]::IsWellFormedUriString([string]$app.Logo, [UriKind]::Absolute))) {
        $errors.Add("Geçersiz logo adresi: $($app.Name)")
    }
}

foreach ($entry in @($catalog.OfficialWebsites.PSObject.Properties)) {
    $url = [string]$entry.Value
    if (-not [Uri]::IsWellFormedUriString($url, [UriKind]::Absolute)) {
        $errors.Add("Geçersiz resmî site eşlemesi: $($entry.Name) -> $url")
    } else { $networkTargets[$url] = [string]$entry.Name }
}

if ($CheckNetwork) {
    foreach ($url in @($networkTargets.Keys)) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Method Head -Uri $url -TimeoutSec 15 -MaximumRedirection 5
            if ([int]$response.StatusCode -ge 400) { $warnings.Add("Site yanıtı $($response.StatusCode): $($networkTargets[$url])") }
        } catch { $warnings.Add("Siteye erişilemedi: $($networkTargets[$url]) -> $url") }
    }
}

Write-Host "Katalog sağlığı: $($apps.Count) kayıt, $($errors.Count) hata, $($warnings.Count) uyarı."
$warnings | ForEach-Object { Write-Warning $_ }
if ($errors.Count) { throw ($errors -join [Environment]::NewLine) }
