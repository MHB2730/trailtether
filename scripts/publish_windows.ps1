# publish_windows.ps1
# ---------------------------------------------------------------------------
# Publishes a new Trailtether Windows release through GitHub Releases.
#
# What this does:
#   1. Reads the current version from pubspec.yaml (must already be bumped).
#   2. Builds a release Windows app via Flutter.
#   3. Packages it as MSIX via the msix Dart package, overriding the bundled
#      version so the AppxManifest matches pubspec.
#   4. Creates a tagged GitHub release and attaches the .msix as an asset.
#
# Required tools:
#   - flutter (in PATH)
#   - dart    (in PATH, comes with flutter)
#   - gh      (GitHub CLI, authenticated via `gh auth login`)
#
# Required env vars: none (gh CLI handles its own auth)
#
# Usage:
#   .\publish_windows.ps1 -ReleaseNotes "..."
#   .\publish_windows.ps1 -ReleaseNotes "..." -Prerelease
# ---------------------------------------------------------------------------

param(
    [string]$ReleaseNotes = "",
    [switch]$Prerelease = $false
)

$ErrorActionPreference = "Stop"

# -- Pre-flight ------------------------------------------------------------

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir   = Join-Path $repoRoot "trailtether_app"
if (-not (Test-Path $appDir)) {
    Write-Error "Cannot find trailtether_app at $appDir"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI 'gh' is not installed or not in PATH. Install from https://cli.github.com and run 'gh auth login'."
}

# Extract version + build number from pubspec.yaml ("version: 1.2.0+8")
$pubspecPath = Join-Path $appDir "pubspec.yaml"
$versionLine = (Select-String -Path $pubspecPath -Pattern "^version:" | Select-Object -First 1).Line
if (-not ($versionLine -match '^version:\s*([\d\.]+)\+(\d+)')) {
    Write-Error "Could not parse 'version:' line in $pubspecPath"
}
$versionName = $Matches[1]
$versionCode = [int]$Matches[2]

# MSIX uses 4-part version: 1.0.6.9 (no `+`). Pad versionName to 3 segments
# in case someone writes "1.0+9" by mistake.
$nameParts = $versionName.Split('.')
while ($nameParts.Length -lt 3) { $nameParts += "0" }
$msixVersion = "$($nameParts[0]).$($nameParts[1]).$($nameParts[2]).$versionCode"

# GitHub release tag -- use `-` instead of `+` to avoid URL-encoding surprises.
$tagName = "v$versionName-$versionCode"

Write-Host ""
Write-Host "Publishing Windows v$versionName (build $versionCode)" -ForegroundColor Cyan
Write-Host "  MSIX manifest version: $msixVersion"
Write-Host "  GitHub release tag:    $tagName"
if ($Prerelease) { Write-Host "  ! Marking as PRERELEASE" -ForegroundColor Yellow }
Write-Host ""

# -- 1. Flutter build ------------------------------------------------------
Write-Host "[1/4] Building Flutter Windows release..." -ForegroundColor Cyan
Push-Location $appDir
try {
    flutter build windows --release --build-name $versionName --build-number $versionCode
    if ($LASTEXITCODE -ne 0) { Write-Error "flutter build windows failed" }
} finally {
    Pop-Location
}

# -- 2. MSIX packaging -----------------------------------------------------
Write-Host "[2/4] Packaging MSIX..." -ForegroundColor Cyan
Push-Location $appDir
try {
    # --version overrides pubspec's msix_config.msix_version so the AppxManifest
    # Identity Version matches the pubspec version (otherwise PackageInfo on
    # installed clients reads the stale 1.0.0.0 default and the updater never
    # detects a new release).
    dart run msix:create --version $msixVersion
    if ($LASTEXITCODE -ne 0) { Write-Error "msix:create failed" }
} finally {
    Pop-Location
}

# The msix package writes to build/windows/x64/runner/Release/<identity>.msix
$msixDir = Join-Path $appDir "build\windows\x64\runner\Release"
$msixCandidates = Get-ChildItem -Path $msixDir -Filter "*.msix" -ErrorAction SilentlyContinue
if (-not $msixCandidates -or $msixCandidates.Length -eq 0) {
    Write-Error "No .msix found in $msixDir"
}
$msixPath = $msixCandidates[0].FullName
$msixSizeMB = [math]::Round((Get-Item $msixPath).Length / 1048576, 1)
Write-Host "  [OK] MSIX ready: $($msixCandidates[0].Name) ($msixSizeMB MB)" -ForegroundColor Green

# Rename to a stable, versioned filename so the GitHub release asset URL is
# predictable and the in-app updater can identify it.
$assetName = "trailtether-$versionName-$versionCode.msix"
$assetPath = Join-Path $msixDir $assetName
if (Test-Path $assetPath) { Remove-Item -Force $assetPath }
Copy-Item -Path $msixPath -Destination $assetPath

# -- 3. Create GitHub release ----------------------------------------------
Write-Host "[3/4] Creating GitHub release $tagName..." -ForegroundColor Cyan

# Check whether the release already exists; if so, upload the asset to it
# rather than failing. This makes the script idempotent for re-runs.
$existing = & gh release view $tagName --json tagName 2>$null
if ($LASTEXITCODE -eq 0 -and $existing) {
    Write-Host "  Release $tagName already exists -- uploading asset with --clobber" -ForegroundColor Yellow
    & gh release upload $tagName $assetPath --clobber
    if ($LASTEXITCODE -ne 0) { Write-Error "gh release upload failed" }
} else {
    $ghArgs = @(
        "release", "create", $tagName,
        $assetPath,
        "--title", "Trailtether v$versionName build $versionCode",
        "--notes", $ReleaseNotes
    )
    if ($Prerelease) { $ghArgs += "--prerelease" }
    & gh @ghArgs
    if ($LASTEXITCODE -ne 0) { Write-Error "gh release create failed" }
}

# -- 4. Verify -------------------------------------------------------------
Write-Host "[4/4] Verifying release is fetchable via API..." -ForegroundColor Cyan
$latest = & gh api repos/MHB2730/trailtether/releases/latest --jq ".tag_name"
if ($latest -eq $tagName) {
    Write-Host "  [OK] /releases/latest reports $latest" -ForegroundColor Green
} else {
    Write-Host "  [WARN] /releases/latest reports '$latest', expected '$tagName'. Newer published release may exist." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Existing Windows installs will see the update on next launch." -ForegroundColor Green
Write-Host "Release page: https://github.com/MHB2730/trailtether/releases/tag/$tagName" -ForegroundColor DarkGray
