@echo off
setlocal

echo Trailtether setup now uses Supabase only.
echo.
echo 1. Apply supabase_setup.sql in your Supabase project.
echo 2. Verify lib\core\supabase_options.dart contains the right credentials.
echo 3. Run flutter pub get.
echo 4. Build with _setup\2_build_windows.bat or _setup\2_build_apk.bat.
echo.
pause
