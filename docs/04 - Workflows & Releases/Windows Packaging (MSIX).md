---
type: build-guide
status: current
area: build
aliases:
  - Windows Packaging (MSIX)
---

# 📦 Windows Packaging (MSIX)

For Windows distribution, Trailtether uses the **MSIX** packaging format, ensuring clean installs/uninstalls and integration with Windows security.

## 🔧 Configuration (`msix_config`)
- **Display Name**: Trailtether.
- **Publisher**: Hilltrek (Cape Town, South Africa).
- **Publisher ID**: `CN=Hilltrek, O=Hilltrek, L=Cape Town, S=Western Cape, C=ZA`.
- **Identity**: `com.trailtether.app`.

## 🛠️ Build Requirements
- **Certificate**: An install certificate is generated and required for local installation.
- **Capabilities**:
  - `internetClient`: For Supabase and map tile fetching.
  - `location`: Access to Windows location services for GPS tracking.

## 🚀 Execution
The build is typically triggered via:
```powershell
flutter build windows
dart run msix:create
```
