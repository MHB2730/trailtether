# =============================================================================
# publish_site.ps1 -- Hilltrek static file deploy
# -----------------------------------------------------------------------------
# Pushes static files to cPanel using the same UAPI the publish-site Edge
# Function uses, so the static deploys and the admin "Publish to live site"
# button speak the same protocol.
#
# Setup (one-off, per PowerShell session -- credentials are NEVER stored in
# this repo):
#
#   $env:CPANEL_HOST        = "fennec.aserv.co.za"
#   $env:CPANEL_USER        = "hilltro7a4x5"
#   $env:CPANEL_API_TOKEN   = "<token from cPanel -> Manage API Tokens -- NOT your password>"
#   $env:HILLTREK_PUBLIC_DIR = "/home/hilltro7a4x5/public_html"
#   $env:HILLTREK_ADMIN_DIR  = "/home/hilltro7a4x5/admin.hilltrek.co.za"
#
# (The first three already exist as Supabase Edge Function Secrets -- copy them
# from Dashboard -> Edge Functions -> Secrets. The two *_DIR vars tell this
# script where each subdomain's docroot lives on the cPanel filesystem.)
#
# Usage:
#   .\scripts\publish_site.ps1 -Target public                   # push this session's static edits to hilltrek.co.za
#   .\scripts\publish_site.ps1 -Target admin                    # push admin SPA edits to admin.hilltrek.co.za
#   .\scripts\publish_site.ps1 -Target public -DryRun           # show what would be uploaded without actually pushing
#   .\scripts\publish_site.ps1 -Target public -Files 'index.html','assets/js/weather.js'   # one-off push
# =============================================================================

[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('public','admin')]
  [string]$Target,

  # Optional explicit file list (relative to the source dir). If absent, the
  # script uses the default list baked in below -- this session's deliverables.
  [string[]]$Files,

  [switch]$DryRun
)

# Stop on any uncaught error so a bad credential doesn't silently push half the
# files and then fail mid-way.
$ErrorActionPreference = 'Stop'

function Require-Env([string]$name) {
  $v = [Environment]::GetEnvironmentVariable($name)
  if ([string]::IsNullOrWhiteSpace($v)) {
    Write-Host ""
    Write-Host "ERROR: required env var '$name' is not set." -ForegroundColor Red
    Write-Host ""
    Write-Host "Copy these from Supabase Dashboard -> Edge Functions -> Secrets, then run:" -ForegroundColor Yellow
    Write-Host '  $env:CPANEL_HOST        = "fennec.aserv.co.za"'
    Write-Host '  $env:CPANEL_USER        = "hilltro7a4x5"'
    Write-Host '  $env:CPANEL_API_TOKEN   = "<token>"'
    Write-Host '  $env:HILLTREK_PUBLIC_DIR = "/home/hilltro7a4x5/public_html"'
    Write-Host '  $env:HILLTREK_ADMIN_DIR  = "/home/hilltro7a4x5/admin.hilltrek.co.za"'
    Write-Host ""
    exit 1
  }
  return $v
}

$CPANEL_HOST  = Require-Env 'CPANEL_HOST'
$CPANEL_USER  = Require-Env 'CPANEL_USER'
$CPANEL_TOKEN = Require-Env 'CPANEL_API_TOKEN'

# Pick source dir + cPanel home per target. Defaults to this session's edits.
$RepoRoot = Split-Path -Parent $PSScriptRoot
switch ($Target) {
  'public' {
    $SourceDir   = Join-Path $RepoRoot 'hilltrek-site'
    $RemoteHome  = Require-Env 'HILLTREK_PUBLIC_DIR'
    $DefaultList = @(
      # Brand-new files -- these MUST go first because the patched HTML pages reference them
      'assets/js/maintenance-gate.js',
      'assets/js/weather.js',
      # Top-level modified pages
      'index.html',
      'trailtether/index.html',
      'trailtether/terms/index.html',
      '404.html',
      # Modified static pages (maintenance-gate script tag injected)
      'cart/index.html',
      'checkout/index.html',
      'hikes/index.html',
      'hikes/mj-cave/index.html',
      'hikes/bushmans-cave-to-thamathu-cave/index.html',
      'hikes/hike-to-tugela-falls/index.html',
      'legal-notice/index.html',
      'merch/index.html',
      'order-confirmation/index.html',
      'payment-cancelled/index.html',
      'privacy/index.html',
      'reach-out/index.html',
      'reviews/index.html',
      'reviews/fire-maple-fire-force-stove/index.html',
      'reviews/firemaple-hiking-kettle/index.html',
      'reviews/merrell-speed-strike-2-mid-ltr-wp/index.html',
      'reviews/self-reliance-outfitters-canteen-cooking-set/index.html',
      'subscribe/confirm/index.html',
      'subscribe/unsubscribe/index.html'
    )
  }
  'admin' {
    $SourceDir   = Join-Path $RepoRoot 'hilltrek-admin'
    $RemoteHome  = Require-Env 'HILLTREK_ADMIN_DIR'
    $DefaultList = @(
      'app.js',
      'index.html',
      'styles.css'
    )
  }
}

if (-not (Test-Path $SourceDir)) {
  Write-Host "ERROR: source directory not found: $SourceDir" -ForegroundColor Red
  exit 1
}

# Check curl.exe (built into Windows 10/11; ships under System32). We use it
# because Invoke-WebRequest in PS 5.1 can't build multipart bodies reliably.
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if (-not $curl) {
  Write-Host "ERROR: curl.exe not found. Install Windows 10 build 1803+ or install curl from https://curl.se" -ForegroundColor Red
  exit 1
}

# Choose file list
if ($Files -and $Files.Count -gt 0) {
  $List = $Files
} else {
  $List = $DefaultList
}
# Normalise + dedupe
$List = $List | ForEach-Object { ($_ -replace '\\', '/').TrimStart('/') } | Select-Object -Unique

# Content-Type by extension -- matters for browsers, not for cPanel, but good hygiene.
function Get-ContentType([string]$path) {
  switch -Regex ($path) {
    '\.html?$'  { return 'text/html; charset=utf-8' }
    '\.css$'    { return 'text/css; charset=utf-8' }
    '\.m?js$'   { return 'application/javascript; charset=utf-8' }
    '\.json$'   { return 'application/json; charset=utf-8' }
    '\.svg$'    { return 'image/svg+xml' }
    '\.png$'    { return 'image/png' }
    '\.jpe?g$'  { return 'image/jpeg' }
    '\.webp$'   { return 'image/webp' }
    '\.ico$'    { return 'image/x-icon' }
    '\.txt$'    { return 'text/plain; charset=utf-8' }
    '\.xml$'    { return 'application/xml; charset=utf-8' }
    default     { return 'application/octet-stream' }
  }
}

Write-Host ""
Write-Host "publish_site.ps1 -> $Target" -ForegroundColor Cyan
Write-Host "  source:   $SourceDir"
Write-Host "  remote:   ${CPANEL_USER}@${CPANEL_HOST}:${RemoteHome}"
Write-Host "  files:    $($List.Count)"
if ($DryRun) { Write-Host "  mode:     DRY RUN (no uploads)" -ForegroundColor Yellow }
Write-Host ""

# Upload one file via curl.exe. Returns $true on HTTP 2xx, $false otherwise.
function Send-OneFile([string]$localPath, [string]$remoteSitePath) {
  $remoteDir = $RemoteHome + ('/' + ($remoteSitePath -replace '/[^/]+$', '')).Replace('//','/').TrimEnd('/')
  if ($remoteDir -eq $RemoteHome.TrimEnd('/')) { $remoteDir = $RemoteHome }
  $filename    = Split-Path -Leaf $remoteSitePath
  $contentType = Get-ContentType $localPath
  $url         = "https://${CPANEL_HOST}:2083/execute/Fileman/upload_files"

  if ($DryRun) {
    Write-Host ("[DRY] {0,-58} -> {1}" -f $remoteSitePath, "$remoteDir/$filename") -ForegroundColor DarkGray
    return $true
  }

  # curl.exe args -- passed as an array so PowerShell doesn't re-tokenise.
  # The -F file-1=@<path>;filename=<n>;type=<ct> form is curl-native syntax.
  $formFile = "file-1=@$localPath;filename=$filename;type=$contentType"
  $args = @(
    '--silent', '--show-error',
    '--output', 'NUL',
    '--write-out', '%{http_code}',
    '--header', "Authorization: cpanel ${CPANEL_USER}:${CPANEL_TOKEN}",
    '--form',   "dir=$remoteDir",
    '--form',   'overwrite=1',
    '--form',   $formFile,
    $url
  )

  $httpCode = & curl.exe @args
  $codeInt  = 0
  [int]::TryParse(($httpCode -as [string]).Trim(), [ref]$codeInt) | Out-Null
  $ok = ($codeInt -ge 200 -and $codeInt -lt 300)

  $marker = if ($ok) { 'OK ' } else { 'ERR' }
  $colour = if ($ok) { 'Green' } else { 'Red' }
  Write-Host ("[{0}] {1,-58} HTTP {2}" -f $marker, $remoteSitePath, $httpCode) -ForegroundColor $colour
  return $ok
}

# Run uploads
$succeeded = 0
$failed    = 0
$skipped   = 0

foreach ($rel in $List) {
  $localPath = Join-Path $SourceDir ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path $localPath)) {
    Write-Host ("[--] {0,-58} (missing locally -- skipped)" -f $rel) -ForegroundColor Yellow
    $skipped++
    continue
  }
  $remoteSitePath = '/' + $rel
  $ok = Send-OneFile -localPath $localPath -remoteSitePath $remoteSitePath
  if ($ok) { $succeeded++ } else { $failed++ }
}

Write-Host ""
Write-Host "Summary: $succeeded ok, $failed failed, $skipped skipped" -ForegroundColor ($(if ($failed -eq 0) { 'Green' } else { 'Red' }))

if ($failed -gt 0) { exit 1 }
