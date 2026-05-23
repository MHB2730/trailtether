# device_smoke.ps1
# ---------------------------------------------------------------------------
# Walk every Trailtether v3.0 TT screen on the connected device, snap a
# screenshot of each, and grep logcat for fatals. Output lands under
# scratch/device-test-<timestamp>/.
# ---------------------------------------------------------------------------

param(
    [string]$Apk = "trailtether_app\build\app\outputs\flutter-apk\app-arm64-v8a-sideload-release.apk",
    [int]$DwellSeconds = 4
)

$ErrorActionPreference = "Stop"
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
$pkg = "com.trailtether.app"

# 1. Verify device
$devices = & $adb devices
if (($devices | Where-Object { $_ -match '\sdevice$' }).Count -eq 0) {
    Write-Error "No device authorized. Plug phone, accept USB debugging prompt."
}

# 2. Output dir
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = "scratch\device-test-$stamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Write-Host "Output: $outDir" -ForegroundColor Cyan

# 3. Install (idempotent — overwrites if same signing cert)
if (Test-Path $Apk) {
    Write-Host "[install] $Apk" -ForegroundColor Cyan
    & $adb install -r $Apk
} else {
    Write-Warning "APK not found at $Apk — skipping install, hoping current install matches."
}

# 4. Clear logcat & start capture
& $adb logcat -c | Out-Null
$logProc = Start-Process -FilePath $adb -ArgumentList "logcat","-v","time" -RedirectStandardOutput "$outDir\logcat.txt" -NoNewWindow -PassThru

# 5. Launch
& $adb shell am force-stop $pkg | Out-Null
Start-Sleep -Seconds 1
& $adb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 6  # splash → home

# 6. Walk every tab — taps the bottom nav at known x-coordinates for a
# 1440x3120 screen (S24 Ultra). 6 tabs split equally → each ~240 wide,
# centers at 120, 360, 600, 840, 1080, 1320. Bottom nav vertical center ~3010.
$tabs = @(
    @{ Name = "01-home";      X = 120;  Y = 3010 },
    @{ Name = "02-map";       X = 360;  Y = 3010 },
    @{ Name = "03-tools";     X = 600;  Y = 3010 },
    @{ Name = "04-community"; X = 840;  Y = 3010 },
    @{ Name = "05-teams";     X = 1080; Y = 3010 },
    @{ Name = "06-profile";   X = 1320; Y = 3010 }
)

# Welcome (initial launch) — snap before tapping any tabs.
Start-Sleep -Seconds 2
Write-Host "[snap] 00-welcome" -ForegroundColor Cyan
& $adb shell screencap -p /sdcard/_tt_snap.png
& $adb pull /sdcard/_tt_snap.png "$outDir\00-welcome.png" 2>&1 | Out-Null

# Tap "GET STARTED" — bottom of screen, center. Coords for S24 Ultra.
Write-Host "[tap] Get Started" -ForegroundColor Cyan
& $adb shell input tap 720 2750
Start-Sleep -Seconds 3

foreach ($t in $tabs) {
    Write-Host ("[tap] tab " + $t.Name) -ForegroundColor Cyan
    & $adb shell input tap $t.X $t.Y
    Start-Sleep -Seconds $DwellSeconds
    Write-Host ("[snap] " + $t.Name) -ForegroundColor Cyan
    & $adb shell screencap -p /sdcard/_tt_snap.png
    & $adb pull /sdcard/_tt_snap.png ("$outDir\" + $t.Name + ".png") 2>&1 | Out-Null
}

# 7. Stop logcat
Stop-Process -Id $logProc.Id -Force -ErrorAction SilentlyContinue

# 8. Quick error scan
$logPath = "$outDir\logcat.txt"
if (Test-Path $logPath) {
    $fatal = Select-String -Path $logPath -Pattern 'FATAL EXCEPTION|AndroidRuntime|StateError|RangeError|RenderFlex|FormatException|^E\/flutter' -CaseSensitive | Select-Object -First 30
    if ($fatal.Count -gt 0) {
        Write-Host ""
        Write-Host "============ ISSUES FOUND ============" -ForegroundColor Red
        $fatal | ForEach-Object { Write-Host $_.Line -ForegroundColor Yellow }
        $fatal.Line | Out-File "$outDir\errors.txt"
    } else {
        Write-Host ""
        Write-Host "[OK] No fatals or red Flutter errors in logcat." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Done. Screenshots + logcat in $outDir" -ForegroundColor Cyan
