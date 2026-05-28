---
type: build-guide
status: current
area: build
aliases:
  - Windows Build Steps
---

# Windows Build Steps

## Prerequisites
- Node.js & NPM
- Electron Forge / Electron Builder

## Build Command
```powershell
# Typical build command
npm run build:windows
```

## Known Issues
- Ensure `WebView2` runtime is installed on the target machine.
- Check certificate signing for production releases.
