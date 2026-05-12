# Trailtether Release Notes

This project now ships as a Supabase-only Flutter app.

## Release Artifacts

- Android APK: `build\app\outputs\flutter-apk\app-release.apk`
- Windows EXE: `build\windows\x64\runner\Release\trailtether_app.exe`

## Release Checklist

1. Confirm [`supabase_setup.sql`](C:\Users\bremn\Documents\Trailtether\trailtether_app\supabase_setup.sql) has been applied to the target Supabase project.
2. Confirm [`lib/core/supabase_options.dart`](C:\Users\bremn\Documents\Trailtether\trailtether_app\lib\core\supabase_options.dart) points at the correct Supabase project.
3. Build Android:

```powershell
flutter build apk --release
```

4. Build Windows:

```powershell
flutter build windows --release
```

## Android Signing

The Android project signs release builds from `android/key.properties` when present. Without that file, Flutter falls back to the debug signing key.

## Firebase Removal

- No Firebase SDK/plugin is configured in Gradle.
- No `google-services` plugin is applied.
- No Firestore or Firebase rules deployment is part of release setup.
