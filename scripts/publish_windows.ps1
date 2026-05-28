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

# Resolve the signing cert. Defaults to ~/.trailtether-signing/trailtether.pfx;
# override either by setting $env:MSIX_CERTIFICATE_PATH. The password is read
# from $env:MSIX_CERTIFICATE_PASSWORD if set, otherwise prompted interactively
# (never logged, never committed). Same cert must be used across releases or
# Windows refuses to apply auto-updates -- the publisher identity has to match.
$certPath = if ($env:MSIX_CERTIFICATE_PATH) {
    $env:MSIX_CERTIFICATE_PATH
} else {
    Join-Path $env:USERPROFILE ".trailtether-signing\trailtether.pfx"
}

# Check if the certificate is already installed in the personal store to sign via thumbprint without a password
$useThumbprint = $false
$thumbprint = "DCEF755D97F906249E897EF8CA5CAB75BF71B300"
if (Get-ChildItem Cert:\CurrentUser\My\$thumbprint -ErrorAction SilentlyContinue) {
    $useThumbprint = $true
}

$certPasswordPlain = $null
if (-not $useThumbprint) {
    if (-not (Test-Path $certPath)) {
        Write-Error "Signing cert not found at $certPath. Set MSIX_CERTIFICATE_PATH or regenerate via the stable-cert setup instructions."
    }

    $certPasswordPlain = if ($env:MSIX_CERTIFICATE_PASSWORD) {
        $env:MSIX_CERTIFICATE_PASSWORD
    } else {
        $secure = Read-Host -AsSecureString "Enter the .pfx password"
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        } finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

Push-Location $appDir
try {
    # --version overrides pubspec's msix_config.msix_version so the AppxManifest
    # Identity Version matches the pubspec version (otherwise PackageInfo on
    # installed clients reads the stale 1.0.0.0 default and the updater never
    # detects a new release).
    if ($useThumbprint) {
        Write-Host "Using installed signing certificate (Thumbprint: $thumbprint) from local store" -ForegroundColor Green
        dart run msix:create `
            --version $msixVersion `
            --signtool-options "/fd sha256 /sha1 $thumbprint" `
            --install-certificate false
    } else {
        dart run msix:create `
            --version $msixVersion `
            --certificate-path $certPath `
            --certificate-password $certPasswordPlain `
            --install-certificate false
    }
    if ($LASTEXITCODE -ne 0) { Write-Error "msix:create failed" }
} finally {
    # Best-effort wipe of the plaintext password from this process's memory.
    $certPasswordPlain = $null
    [System.GC]::Collect()
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

# Publish the public .cer alongside the .msix so new users have a single
# place to download both. The .cer is safe to share -- it's the public half
# of the signing cert, used only to mark the publisher as trusted.
$certPublicPath = [System.IO.Path]::ChangeExtension($certPath, ".cer")
$certPublicAsset = $null
if (Test-Path $certPublicPath) {
    $certPublicAsset = Join-Path $msixDir "trailtether-publisher.cer"
    if (Test-Path $certPublicAsset) { Remove-Item -Force $certPublicAsset }
    Copy-Item -Path $certPublicPath -Destination $certPublicAsset
} else {
    Write-Host "  [WARN] Public .cer not found at $certPublicPath -- skipping cert asset upload" -ForegroundColor Yellow
}

# -- 3. Create GitHub release ----------------------------------------------
Write-Host "[3/4] Creating GitHub release $tagName..." -ForegroundColor Cyan

# Assemble the asset list (always includes the MSIX; includes the .cer if found).
$assets = @($assetPath)
if ($certPublicAsset) { $assets += $certPublicAsset }

# Check whether the release already exists; if so, upload the asset to it
# rather than failing. This makes the script idempotent for re-runs.
#
# Note: gh exits 1 when the release doesn't exist (the expected probe case),
# and under WinPS 5.1 with $ErrorActionPreference=Stop, redirected stderr is
# promoted to a script-terminating NativeCommandError. Temporarily relax the
# preference for the probe so the script can interpret the exit code itself.
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$existing = & gh release view $tagName --json tagName 2>$null
$probeExit = $LASTEXITCODE
$ErrorActionPreference = $prevEAP
if ($probeExit -eq 0 -and $existing) {
    Write-Host "  Release $tagName already exists -- uploading assets with --clobber" -ForegroundColor Yellow
    & gh release upload $tagName @assets --clobber
    if ($LASTEXITCODE -ne 0) { Write-Error "gh release upload failed" }
} else {
    $ghArgs = @(
        "release", "create", $tagName
    ) + $assets + @(
        "--title", "Trailtether v$versionName build $versionCode"
    )
    # WinPS 5.1 drops empty-string arguments during array splatting, so
    # `--notes ""` reaches gh as a bare `--notes` with no value, failing
    # with "flag needs an argument: --notes". Fall through to
    # --generate-notes when no notes were supplied so gh pulls them from
    # the commit log instead.
    if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) {
        $ghArgs += "--generate-notes"
    } else {
        $ghArgs += "--notes"
        $ghArgs += $ReleaseNotes
    }
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
