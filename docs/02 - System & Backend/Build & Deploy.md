---
tags: [type/architecture, layer/infra, status/stable]
aliases: [Deploy, Release]
source_paths: [scripts/publish_release.ps1, scripts/publish_windows.ps1, scripts/publish_site.ps1, trailtether_app/pubspec.yaml]
---

# Build & Deploy

## Local development

| Surface | Run command | Note |
|---|---|---|
| Flutter (Android) | `flutter run` from `trailtether_app/` | Needs Android SDK + signed device |
| Flutter (Windows) | `flutter run -d windows` from `trailtether_app/` | WebView2 + window_manager |
| Hilltrek site | Open `hilltrek-site/index.html` in browser | No build step — static |
| Hilltrek admin | Open `hilltrek-admin/index.html` in browser | Reads Supabase URL/anon key from `config.js` |
| Edge functions | `supabase functions serve <name>` (Supabase CLI) | Or deploy via MCP (`mcp__supabase__deploy_edge_function`) |

## Flutter analyze + tests

```bash
cd trailtether_app && flutter analyze    # 0 issues
cd trailtether_app && flutter test       # 23 tests (offline incident queue, model parsing, widget)
```

## Build outputs

| Output | Tool | Where it goes |
|---|---|---|
| Android APK | `flutter build apk --release` | Self-hosted in Supabase Storage `app-releases` bucket; row in [[app_releases]] |
| Windows MSIX | `flutter pub run msix:create` (via [[publish_windows.ps1]]) | Same storage bucket, separate `platform='windows'` row |
| Hilltrek site | (no build — static) | cPanel docroot at `/home/hilltro7a4x5/public_html` |
| Edge function | Single `.ts` file | Supabase via MCP or `supabase functions deploy` |

## Release flow

```mermaid
sequenceDiagram
    participant U as You
    participant PS as publish_release.ps1
    participant FL as Flutter
    participant SB as Supabase

    U->>U: bump pubspec.yaml version (e.g. 3.7.6+61)
    U->>U: git commit + push
    U->>PS: .\scripts\publish_release.ps1
    PS->>FL: flutter build apk --release
    FL-->>PS: app-release.apk
    PS->>PS: sha256 the APK
    PS->>SB: upload to Storage app-releases bucket
    PS->>SB: insert row into app_releases (version, code, sha256, download_url)
    Note over SB: In-app updater polls app_releases<br/>on next launch; downloads + sha verify
```

The in-app updater (see [[update_service.dart]]) reads from [[app_releases]] on cold start. Users on the previous version get an in-app prompt to update. Web users hitting `/trailtether/` go through [[Workflow - APK Download]].

## Per-script summary

### [[publish_release.ps1]]
- Reads pubspec version
- Runs `flutter build apk --release`
- SHA-256 of resulting APK
- Uploads to Supabase Storage (`app-releases/<version>.apk`)
- Inserts row into [[app_releases]] with `platform='android'`
- Optionally creates a GitHub release for archival
- Required env: `SUPABASE_SERVICE_ROLE_KEY`, GitHub PAT for `gh`

### [[publish_windows.ps1]]
- Runs `flutter build windows --release`
- Calls `msix:create` to package
- Signs with `.pfx` from `%USERPROFILE%\.trailtether-signing\trailtether.pfx`
- Uploads MSIX to Supabase Storage with `platform='windows'` row in [[app_releases]]
- Pre-flight check: `gh` must be on PATH

### [[publish_site.ps1]]
- Pushes `hilltrek-site/` (`-Target public`) or `hilltrek-admin/` (`-Target admin`) files via cPanel UAPI
- Throttled at 800ms between uploads to avoid CSF autoban on Aserv's LFD
- Auto-retries once after a 90s back-off if LFD trips
- Required env: `CPANEL_HOST`, `CPANEL_USER`, `CPANEL_API_TOKEN`, `HILLTREK_PUBLIC_DIR`, `HILLTREK_ADMIN_DIR` (all validated via `Require-Env` at top of script)

## Supabase deploys

| Asset | How |
|---|---|
| Migration SQL | `mcp__supabase__apply_migration` (or `supabase db push` via CLI) |
| Edge function | `mcp__supabase__deploy_edge_function` (or `supabase functions deploy <name>`) |
| Storage policies | Not in migrations — manual via Supabase dashboard |

> [!note]
> Storage bucket RLS policies are documented in `20260528_storage_rls_policies.sql` (migration file kept as reference). All 31 policies are verified active in production.

## GitHub Actions CI

On every push/PR to `main`, `.github/workflows/ci.yml` runs:
1. `flutter pub get`
2. `dart format --set-exit-if-changed lib/ test/`
3. `flutter analyze`
4. `flutter test`
5. `flutter build apk --release --flavor sideload --split-per-abi --no-pub` (dry-run)

Requires Java 17 (Zulu) + Flutter 3.24.5 stable.

## Environments

Currently single-environment (production Supabase project `xuqmdujupbmxahyhkdwl`). No staging tier. Tested edits go straight to prod with MCP-applied migrations. See [[Env Vars Inventory]] for the full secret list.
