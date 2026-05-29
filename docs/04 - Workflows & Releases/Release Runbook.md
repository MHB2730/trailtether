---
tags: [type/workflow, layer/infra, status/stable]
aliases: [Release Runbook, How To Ship, Publish Guide, How To Push A Version]
source_paths: [scripts/publish_release.ps1, scripts/publish_windows.ps1, scripts/publish_site.ps1, trailtether_app/pubspec.yaml, trailtether_app/lib/services/update_service.dart, trailtether_app/android/app/build.gradle]
---

# Release Runbook

The single source for **how to build, version, and ship Trailtether** across all three surfaces (Android app, Windows app, Hilltrek website), plus what's verified working and the known gotchas.

> Last verified at **v4.0.0+62 — shipped 2026-05-29**. See [[Version History]] for the changelog and [[Known Issues]] for live open items.

## TL;DR — ship a new version

1. **Bump** `trailtether_app/pubspec.yaml` → `X.Y.Z+N` (N = build number, **must always increase**).
2. **Commit + push** to `origin/main`.
3. **Android OTA:**
   ```powershell
   cd C:\Users\bremn\Documents\Trailtetherv2.0
   $env:SUPABASE_URL = "https://xuqmdujupbmxahyhkdwl.supabase.co"
   $env:SUPABASE_SERVICE_ROLE_KEY = "<service-role key — Supabase → Project Settings → API>"
   .\scripts\publish_release.ps1 -ReleaseNotes "..."     # add -Critical to force-update all clients
   ```
4. **Windows:**
   ```powershell
   gh auth login        # once
   .\scripts\publish_windows.ps1 -ReleaseNotes "..."
   ```
5. **Website — ONLY if `hilltrek-site/` or `hilltrek-admin/` changed:**
   ```powershell
   $env:CPANEL_HOST="fennec.aserv.co.za"; $env:CPANEL_USER="hilltro7a4x5"
   $env:CPANEL_API_TOKEN="<cPanel → Manage API Tokens>"
   $env:HILLTREK_PUBLIC_DIR="/home/hilltro7a4x5/public_html"
   $env:HILLTREK_ADMIN_DIR="/home/hilltro7a4x5/admin.hilltrek.co.za"
   .\scripts\publish_site.ps1 -Target public -DelayMs 3000   # see CSF gotcha below
   .\scripts\publish_site.ps1 -Target admin
   ```

The publish scripts **build for you** — manual builds below are only for verification.

## Build commands (local verification)

| Surface | Command (run from `trailtether_app/`) | Output |
|---|---|---|
| Android | `flutter build apk --release --flavor sideload --split-per-abi` | 3 signed APKs → `build/app/outputs/flutter-apk/` (arm64-v8a is primary) |
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/trailtether_app.exe` |
| Website | (none — static HTML/JS) | — |

> [!warning] `--flavor sideload` is mandatory on Android
> The project has `flavorDimensions "distribution"` (`sideload` / `playStore`). `flutter run`/`build apk` **without** a flavor fails with *"Gradle build failed to produce an .apk file."* Always pass `--flavor sideload`. Release signing uses the keystore from `android/key.properties` when present (else debug); no minification (`minifyEnabled false`).

## VersionCode scheme — don't break OTA

- `pubspec.yaml` `X.Y.Z+N` → `build.gradle` sets `versionCode = N` for a plain build.
- BUT `publish_release.ps1` ships the **arm64 split-per-abi** APK, whose versionCode = **`2000 + N`** (Flutter's per-ABI offset; arm64 = 2xxx).
- So `4.0.0+62` → live arm64 versionCode **2062**; `3.7.6+61` → 2061.
- **N must always increase** so `2000+N` exceeds every installed versionCode. If a new release's versionCode is ≤ the installed one, Android rejects the install as a downgrade and the OTA **silently fails** for existing users. (A dev `flutter run` build is versionCode N, not 2000+N — that's why installing a debug build over a published one throws `INSTALL_FAILED_VERSION_DOWNGRADE`; harmless for OTA.)

## Update channels — two, one per platform

| Platform | Publisher | Lands in | App checks (on cold start) |
|---|---|---|---|
| **Android** | `publish_release.ps1` | Supabase Storage `app-releases` bucket + a row in [[app_releases]] | [[update_service.dart]] → latest `app_releases` row, SHA-256 verified |
| **Windows** | `publish_windows.ps1` | **GitHub Releases** (tag `v<ver>-<code>`), signed `.msix` + public `.cer` | [[update_service.dart]] → GitHub `/releases/latest` |

> [!note] Windows does NOT use Supabase
> A frequent point of confusion. Android = Supabase `app_releases`; Windows = GitHub Releases. The code (`update_service.dart`) reads the correct channel per `Platform.isWindows`.

## Secrets / tooling per script

| Script | Requires |
|---|---|
| `publish_release.ps1` | env `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (bypasses RLS — never commit) |
| `publish_windows.ps1` | `gh auth login`; signing cert — thumbprint `DCEF755D…B300` in the CurrentUser store **or** `.pfx` at `%USERPROFILE%\.trailtether-signing\trailtether.pfx` (`MSIX_CERTIFICATE_PASSWORD` optional) |
| `publish_site.ps1` | env `CPANEL_HOST`, `CPANEL_USER`, `CPANEL_API_TOKEN`, `HILLTREK_PUBLIC_DIR`, `HILLTREK_ADMIN_DIR` |

Supabase migrations/functions deploy via the MCP tools (`apply_migration`, `deploy_edge_function`) or the Supabase CLI. The live DB is **ahead of** the version-controlled `supabase/migrations/` files (only recent migrations are committed as files; full history is applied in the project) — this is expected.

## What works (verified at v4.0)

- **Builds**: Android (3 signed APKs) + Windows (`.exe`) compile clean; `flutter analyze` 0 issues, `dart format` clean, **23 tests pass**.
- **Launch**: boots clean on a physical Samsung S24 / Android 16 — Supabase, deep-link, notifications, 239 trails all init; no overflow / missing-asset errors.
- **Auth**: email sign-in + sign-up, Google (native idToken on mobile, PKCE deep-link `trailtether://login-callback` on desktop), sign-out. The `on_auth_user_created` trigger → `handle_new_user` creates the profile row on signup.
- **Backend security**: all **44** public tables RLS-enabled with policies; `admin_*` SECURITY DEFINER RPCs are `is_admin()`-gated; **15** edge functions deployed ACTIVE; `search_path` pinned on all SECURITY DEFINER functions.
- **OTA**: Android `app_releases` 4.0.0 / code 2062 live (supersedes 2061); Windows GitHub `v4.0.0-62` live; website static assets live + current.
- **Fixed in v4.0**: live map marker now advances (directional dot, not a frozen square); solo hike/walk save (community_activities `team_id`/`team_name` nullable + duplicate client insert removed); welcome-screen overflow + missing `feature_graphic.png` crash; PII (email + GPS) no longer logged to `app_logs` in release; app-wide stale copy.

## What doesn't / gotchas / open risks

- **🔴 `verify_jwt: true` on payment webhooks (UNVERIFIED).** All 15 functions have it, including `payfast-itn` / `yoco-webhook` / `zapper-webhook`. External callers send no Supabase JWT → could 401 → orders may not finalize. **Run one real test payment.** If it doesn't flip to paid, set `verify_jwt = false` on those webhooks (commit a `supabase/config.toml` or set per-function).
- **Auth leaked-password protection disabled** — advisor still flags it. Enable: Supabase → Auth → Password.
- **Google sign-in needs the release keystore's SHA-1 in Google Cloud Console** — otherwise the *signed* build gets a null idToken and sign-in fails (works in debug, fails in release). Test one Google login on the published APK.
- **cPanel CSF/LFD autoban** — `publish_site.ps1` doing rapid UAPI uploads trips Aserv's firewall: a `403 → connection reset → 415` cascade. Mitigate with `-DelayMs 3000`, push only changed files via `-Files '...'`, or wait ~1 h / unblock the IP via Aserv. The script re-pushes its **full** file list every run (it is not diff-based), so most uploads are redundant no-ops.
- **Routing is start/end-node only** (`routing_service.dart`) — trails that cross mid-segment aren't connected; multi-trail routing only works at shared trailheads.
- **Off-trail / incident queue drains on a connectivity *change* only** — launching already-online with a backlog won't drain until connectivity flaps.
- **Low-priority advisors**: `citext` + `pg_net` extensions live in the `public` schema (cosmetic; moving them is disruptive).

## Verify a publish actually landed

```sql
-- Android: newest row should be your new version, code = 2000+build, > the previous
SELECT version_name, version_code, platform, is_critical, released_at
FROM public.app_releases ORDER BY released_at DESC LIMIT 5;
```
```powershell
# Windows: should report your new tag
gh api repos/MHB2730/trailtether/releases/latest --jq .tag_name
```
```bash
# Website: each changed file should be HTTP 200 (not 404)
curl -sL -o /dev/null -w "%{http_code}\n" https://hilltrek.co.za/assets/js/<file>.js
```

## See also
- [[Build & Deploy]] — per-script detail + the release-flow diagram
- [[System Overview]] — the 3-surface architecture
- [[Known Issues]] · [[Open Follow-Ups]] · [[Version History]]
