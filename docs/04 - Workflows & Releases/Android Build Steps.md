---
type: build-guide
status: current
area: build
aliases:
  - Android Build Steps
---

# Android Build Steps

## Prerequisites
- Android Studio
- Capacitor CLI
- Java JDK

## Build Process
1. Sync Capacitor:
   ```bash
   npx cap sync android
   ```
2. Open in Android Studio:
   ```bash
   npx cap open android
   ```
3. Build Signed APK via Build -> Generate Signed Bundle / APK.

## Notes
- Background GPS permissions must be strictly handled in `AndroidManifest.xml`.
