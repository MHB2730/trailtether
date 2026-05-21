# publish_release.ps1
# ---------------------------------------------------------------------------
# Publishes a new Trailtether release through the self-hosted update channel.
#
# What this does:
#   1. Reads the current version from pubspec.yaml (must already be bumped).
#   2. Builds a release APK.
#   3. Uploads it to the Supabase `app-releases` storage bucket.
#   4. Inserts a row into `public.app_releases` so clients on launch see the
#      new version and surface the in-app updater.
#
# Required env vars:
#   SUPABASE_URL                 e.g. https://xuqmdujupbmxahyhkdwl.supabase.co
#   SUPABASE_SERVICE_ROLE_KEY    service-role key (from Supabase dashboard
#                                  -> Project Settings -> API). Never check
#                                  this into git -- it bypasses RLS.
#
# Usage:
#   .\publish_release.ps1 -ReleaseNotes "Live tracking fixes; weather alerts."
#   .\publish_release.ps1 -ReleaseNotes "..." -Critical
#   .\publish_release.ps1 -ReleaseNotes "..." -MinSupportedVersionCode 7
# ---------------------------------------------------------------------------

param(
    [string]$ReleaseNotes = "",
    [switch]$Critical = $false,
    [int]$MinSupportedVersionCode = 0
)

$ErrorActionPreference = "Stop"

# -- Pre-flight ------------------------------------------------------------

if (-not $env:SUPABASE_URL) {
    Write-Error "SUPABASE_URL env var is not set."
}
if (-not $env:SUPABASE_SERVICE_ROLE_KEY) {
    Write-Error "SUPABASE_SERVICE_ROLE_KEY env var is not set."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir   = Join-Path $repoRoot "trailtether_app"
if (-not (Test-Path $appDir)) {
    Write-Error "Cannot find trailtether_app at $appDir"
}

# Extract version + build number from pubspec.yaml ("version: 1.2.0+8")
$pubspecPath = Join-Path $appDir "pubspec.yaml"
$versionLine = (Select-String -Path $pubspecPath -Pattern "^version:" | Select-Object -First 1).Line
if (-not ($versionLine -match '^version:\s*([\d\.]+)\+(\d+)')) {
    Write-Error "Could not parse 'version:' line in $pubspecPath"
}
$versionName = $Matches[1]
$versionCode = [int]$Matches[2]

Write-Host ""
Write-Host "Publishing v$versionName (code $versionCode)" -ForegroundColor Cyan
if ($Critical) { Write-Host "  ! CRITICAL: clients will be force-updated" -ForegroundColor Yellow }
if ($MinSupportedVersionCode -gt 0) {
    Write-Host "  ! Pinning min_supported_version_code = $MinSupportedVersionCode" -ForegroundColor Yellow
}
Write-Host ""

# -- 1. Build APK ----------------------------------------------------------
# Split-per-ABI on so each APK stays under the 50 MB Supabase free-plan upload cap.
# Modern Android phones (~2017+) all use arm64-v8a; we publish only that variant.
Write-Host "[1/3] Building release APKs (sideload flavor, split-per-abi)..." -ForegroundColor Cyan
Push-Location $appDir
try {
    flutter build apk --release --flavor sideload --split-per-abi
    if ($LASTEXITCODE -ne 0) { Write-Error "flutter build apk failed" }
} finally {
    Pop-Location
}
$apkPath = Join-Path $appDir "build\app\outputs\flutter-apk\app-arm64-v8a-sideload-release.apk"
if (-not (Test-Path $apkPath)) { Write-Error "arm64-v8a sideload APK not found at $apkPath" }
$apkSizeBytes = (Get-Item $apkPath).Length
$apkSizeMB = [math]::Round(($apkSizeBytes / 1048576), 1)
Write-Host "  [OK] arm64-v8a sideload APK ready ($apkSizeMB MB)" -ForegroundColor Green
if ($apkSizeBytes -gt 50000000) {
    Write-Warning "APK is over 50 MB. Supabase free plan will reject the upload."
}

# Compute SHA-256 for integrity check by clients.
$apkSha256 = (Get-FileHash -Algorithm SHA256 -Path $apkPath).Hash.ToLower()

# -- 2. Upload to Supabase Storage -----------------------------------------
$objectName  = "trailtether-$versionName-$versionCode.apk"
$uploadUrl   = "$env:SUPABASE_URL/storage/v1/object/app-releases/$objectName"
$downloadUrl = "$env:SUPABASE_URL/storage/v1/object/public/app-releases/$objectName"

Write-Host "[2/3] Uploading to Supabase Storage..." -ForegroundColor Cyan
Write-Host "      $objectName"

$uploadHeaders = @{
    "Authorization" = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
    "apikey"        = $env:SUPABASE_SERVICE_ROLE_KEY
    "Content-Type"  = "application/vnd.android.package-archive"
    "x-upsert"      = "true"
}

try {
    Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $uploadHeaders -InFile $apkPath -UserAgent "trailtether-publisher/1.0" | Out-Null
    Write-Host "  [OK] Uploaded" -ForegroundColor Green
} catch {
    Write-Error "Upload failed: $_"
}

# -- 3. Insert release row -------------------------------------------------
Write-Host "[3/3] Registering release in app_releases..." -ForegroundColor Cyan

# Flutter's --split-per-abi mutates versionCode in the APK manifest:
#   arm64-v8a → 2 * 1000 + baseCode
# The client reads this mutated value from the manifest, so the DB must store
# the same number, otherwise the comparison breaks (server=5, phone=2005).
$arm64VersionCode = 2 * 1000 + $versionCode

$row = @{
    platform                   = "android"
    version_name               = $versionName
    version_code               = $arm64VersionCode
    download_url               = $downloadUrl
    sha256                     = $apkSha256
    release_notes              = $ReleaseNotes
    is_critical                = [bool]$Critical
    min_supported_version_code = $MinSupportedVersionCode
}
$body = $row | ConvertTo-Json -Compress

$insertHeaders = @{
    "Authorization" = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
    "apikey"        = $env:SUPABASE_SERVICE_ROLE_KEY
    "Content-Type"  = "application/json"
    "Prefer"        = "return=representation"
}

try {
    # New-style sb_secret_* keys reject browser-like User-Agents on the REST
    # endpoint, and Invoke-RestMethod defaults to a Mozilla/5.0 UA. Override
    # it with a server-side identifier so PostgREST accepts the request.
    $resp = Invoke-RestMethod -Uri "$env:SUPABASE_URL/rest/v1/app_releases" -Method Post -Headers $insertHeaders -Body $body -UserAgent "trailtether-publisher/1.0"
    Write-Host "  [OK] Registered (id=$($resp[0].id))" -ForegroundColor Green
} catch {
    Write-Error "Insert failed: $_"
}

Write-Host ""
Write-Host "Done. Clients will see the update on next launch." -ForegroundColor Green
Write-Host "Download URL: $downloadUrl" -ForegroundColor DarkGray
