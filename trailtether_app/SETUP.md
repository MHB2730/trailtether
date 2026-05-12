# Trailtether Setup

Trailtether now uses Supabase only. Firebase is not required for login, reviews, chat, teams, incidents, or GPX uploads.

## Prerequisites

- Flutter SDK
- Visual Studio 2022 with `Desktop development with C++` for Windows builds
- Android Studio / Android SDK for Android builds

## Supabase

The app reads its Supabase project credentials from [`lib/core/supabase_options.dart`](C:\Users\bremn\Documents\Trailtether\trailtether_app\lib\core\supabase_options.dart).

To provision the database schema in a fresh Supabase project:

1. Open your Supabase SQL editor.
2. Run [`supabase_setup.sql`](C:\Users\bremn\Documents\Trailtether\trailtether_app\supabase_setup.sql).
3. Create the storage buckets referenced by the app:
   - `profile-photos`
   - `gpx-files`
4. If you are changing projects, update `kSupabaseUrl` and `kSupabaseAnonKey` in [`lib/core/supabase_options.dart`](C:\Users\bremn\Documents\Trailtether\trailtether_app\lib\core\supabase_options.dart).

## Install Dependencies

```powershell
flutter pub get
```

## Build Windows

```powershell
flutter build windows --release
```

Output:

```text
build\windows\x64\runner\Release\trailtether_app.exe
```

## Build Android

```powershell
flutter build apk --release
```

Output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

## Notes

- If Supabase initialization fails, the app falls back to local demo mode instead of crashing.
- Android no longer requires `google-services.json` or any Firebase plugin setup.
