---
tags: [type/module, layer/infra, status/stable, domain/tooling]
aliases: [Scripts, Build scripts]
source_paths: [scripts]
---

# Scripts Module

PowerShell + Python tooling in `scripts/`. 6 scripts, two purposes: **release** and **ops**.

## Release scripts (PowerShell)

| Script | Purpose | Required env |
|---|---|---|
| [[publish_release.ps1]] | Build Android APK, sha256, upload to Storage, insert [[app_releases]] row | `SUPABASE_SERVICE_ROLE_KEY`, gh PAT |
| [[publish_windows.ps1]] | Build Windows MSIX, sign with `.pfx`, upload to Storage, insert [[app_releases]] row | `SUPABASE_SERVICE_ROLE_KEY`, signing cert |
| [[publish_site.ps1]] | Push static files to cPanel via UAPI | `CPANEL_HOST`, `CPANEL_USER`, `CPANEL_API_TOKEN`, `HILLTREK_PUBLIC_DIR`, `HILLTREK_ADMIN_DIR` |

> [!note] User runs these personally
> Per project convention, the user runs publish scripts themselves after I bump pubspec + commit. See [[Workflow - Release]] for the flow.

## Smoke / utility scripts

| Script | Purpose |
|---|---|
| `device_smoke.ps1` | Manual smoke test on a wired Android device — installs, launches, captures logs |
| `check_caves.py` | Sanity check on `assets/data/caves.gpx` waypoint data |
| `merge_geojson_routes.py` | One-off route data merger (used during initial trail catalogue import) |

## Conventions

- **PowerShell**: `$ErrorActionPreference = 'Stop'`, `Require-Env` helper for env var validation, throttled batch uploads to avoid LFD autoban on cPanel
- **Python**: stdlib only (no pip requirements file)
- **Long-path safe deletion**: `cmd /c rmdir /s /q` used for deep node_modules trees (Windows MAX_PATH limit)

## Depends on

- `flutter`, `gh`, `curl.exe` (Windows 10+ built-in) for PowerShell scripts
- Python 3 stdlib

## Used by

- The user (manual invocation)
- Conceptually: [[Build & Deploy]], [[Workflow - Release]]

## Output destinations

| Script | Where stuff lands |
|---|---|
| [[publish_release.ps1]] | Supabase Storage `app-releases/<version>.apk` + [[app_releases]] row |
| [[publish_windows.ps1]] | Supabase Storage `app-releases/<version>.msix` + [[app_releases]] row |
| [[publish_site.ps1]] | `/home/hilltro7a4x5/public_html` (public) or `.../admin.hilltrek.co.za` (admin) on cPanel |
