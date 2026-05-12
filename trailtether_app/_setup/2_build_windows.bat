@echo off
setlocal enabledelayedexpansion
title Trailtether - Build Windows App

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

echo Building Trailtether Windows release...
call %FLUTTER% config --enable-windows-desktop >nul 2>&1
call %FLUTTER% pub get
if %errorlevel% neq 0 (
    echo ERROR: flutter pub get failed.
    pause
    exit /b 1
)

call %FLUTTER% build windows --release
if %errorlevel% neq 0 (
    echo ERROR: Windows release build failed.
    pause
    exit /b 1
)

echo.
echo Build successful:
echo %APP_DIR%\build\windows\x64\runner\Release\trailtether_app.exe
echo.
echo This app is Supabase-backed. If Supabase initialization fails,
echo the app falls back to local demo mode instead of crashing.
echo.
pause
