@echo off
setlocal enabledelayedexpansion
title Trailtether — Step 1: Install Flutter

echo.
echo ============================================================
echo   STEP 1 of 3 — Install Flutter SDK + Android tools
echo ============================================================
echo.

REM ── Where to install ──────────────────────────────────────────
set FLUTTER_DIR=C:\flutter
set ANDROID_SDK_DIR=C:\Android\Sdk

REM ── Check if Flutter is already installed ──────────────────────
if exist "%FLUTTER_DIR%\bin\flutter.bat" (
    echo [✓] Flutter already at %FLUTTER_DIR%
    goto :check_android
)

echo [1] Downloading Flutter SDK...
echo     This is ~700 MB — please wait.
echo.

REM Try winget first (Windows 11 / modern Windows 10)
where winget >nul 2>&1
if %errorlevel%==0 (
    winget install --id Google.Flutter --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel%==0 (
        echo [✓] Flutter installed via winget.
        goto :check_android
    )
)

REM Fallback: download ZIP directly
set FLUTTER_ZIP=%TEMP%\flutter_sdk.zip
set FLUTTER_URL=https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip

echo     Downloading from: %FLUTTER_URL%
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%FLUTTER_URL%' -OutFile '%FLUTTER_ZIP%' -UseBasicParsing"
if %errorlevel% neq 0 (
    echo ERROR: Download failed. Check internet connection.
    pause & exit /b 1
)

echo [2] Extracting Flutter...
powershell -NoProfile -Command "Expand-Archive -Path '%FLUTTER_ZIP%' -DestinationPath 'C:\' -Force"
del "%FLUTTER_ZIP%"

if not exist "%FLUTTER_DIR%\bin\flutter.bat" (
    echo ERROR: Flutter extraction failed.
    pause & exit /b 1
)
echo [✓] Flutter extracted to %FLUTTER_DIR%

:check_android
echo.
echo [3] Adding Flutter to PATH for this session...
set PATH=%FLUTTER_DIR%\bin;%PATH%

REM Persist Flutter on PATH permanently (current user)
powershell -NoProfile -Command ^
  "$cur = [Environment]::GetEnvironmentVariable('PATH','User'); if ($cur -notlike '*%FLUTTER_DIR%*') { [Environment]::SetEnvironmentVariable('PATH', '%FLUTTER_DIR%\bin;' + $cur, 'User'); Write-Host 'PATH updated.' } else { Write-Host 'PATH already has Flutter.' }"

echo.
echo [4] Accepting Android SDK licences (requires Android Studio or SDK)...
REM Check for Android SDK
if not exist "%ANDROID_SDK_DIR%" (
    echo.
    echo  Android SDK not found at %ANDROID_SDK_DIR%.
    echo  Please install Android Studio from:
    echo    https://developer.android.com/studio
    echo  Then re-run this script.
    echo.
    echo  [For Windows-only testing you can skip Android Studio and
    echo   just run 2_build_windows.bat after this step completes.]
    echo.
    pause
    goto :flutter_doctor
)

call "%ANDROID_SDK_DIR%\cmdline-tools\latest\bin\sdkmanager.bat" --licenses < nul

:flutter_doctor
echo.
echo [5] Running flutter doctor...
call "%FLUTTER_DIR%\bin\flutter.bat" doctor --android-licenses < nul 2>&1
call "%FLUTTER_DIR%\bin\flutter.bat" doctor 2>&1

echo.
echo ============================================================
echo   Flutter installation complete!
echo   Next: run  2_build_windows.bat  or  2_build_apk.bat
echo ============================================================
echo.
pause
