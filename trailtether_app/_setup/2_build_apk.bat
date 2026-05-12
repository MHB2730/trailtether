@echo off
setlocal enabledelayedexpansion
title Trailtether - Build Android APK

set FLUTTER=flutter
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    if exist "C:\flutter\bin\flutter.bat" (
        set FLUTTER=C:\flutter\bin\flutter.bat
    ) else (
        echo ERROR: Flutter not found. Run 1_install_flutter.bat first.
        pause
        exit /b 1
    )
)

set SCRIPT_DIR=%~dp0
set APP_DIR=%SCRIPT_DIR%..
cd /d "%APP_DIR%"

echo Building Trailtether Android APK...
call %FLUTTER% pub get
if %errorlevel% neq 0 (
    echo ERROR: flutter pub get failed.
    pause
    exit /b 1
)

call %FLUTTER% build apk --release
if %errorlevel% neq 0 (
    echo ERROR: Android release build failed.
    pause
    exit /b 1
)

echo.
echo Build successful:
echo %APP_DIR%\build\app\outputs\flutter-apk\app-release.apk
echo.
echo This app is Supabase-backed. If Supabase initialization fails,
echo the app falls back to local demo mode instead of crashing.
echo.
pause
