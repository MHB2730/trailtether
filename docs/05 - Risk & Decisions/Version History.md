---
type: changelog
status: current
area: history
aliases:
  - Version History
---

# 🗒️ Version History

## v4.0.0+62 — Cleanup, Hardening & On-Device Verification
Pre-release pass; app built + launched + smoke-verified on a physical Samsung S24 (Android 16) via `flutter run --flavor sideload`.

**Bug fixes**
- Live "you" map marker now advances while recording — [[recording_provider.dart]] never updated `_currentPosition` after the start fix, so the marker froze at the start while the route grew. Start point is now a directional dot, not a square.
- Hike/walk save no longer fails — `community_activities.team_id`/`team_name` made nullable so the `on_hike_saved` trigger succeeds for solo activities; removed the duplicate client-side feed insert (DB trigger is the single source of truth).
- [[TTWelcomeScreen]] `RenderFlex` overflow fixed (responsive hero height) and the deleted `feature_graphic.png` reference removed (was throwing "Unable to load asset" on every launch).

**UX copy** — fixed stale/misleading strings app-wide: "Tap PLAY"→"Ready to record"; "Start Hike on the Map"→"START RECORDING"; safety-centre PC-pairing text (pointed at a non-existent mobile "Tools tab"); "Hilltrek" brand leak in sync toasts; achievement label mismatches (4K→3K, X12→X10); removed "FREE / NO ADS".

**Security**
- Stopped persisting PII to [[app_logs]]: dropped email from the auth log line and gated remote log sync to debug builds (was hardcoded on, streaming GPS every line — battery + POPIA fix). Enable in release with `--dart-define=TRAILTETHER_REMOTE_LOGS=true`.
- Pinned `search_path` on [[increment_recorded_trail_downloads]] (advisor 0011 fix, applied to prod).
- Verified: all 44 tables RLS-enabled with policies; `admin_*` SECURITY DEFINER functions are `is_admin()`-gated; all 15 edge functions deployed ACTIVE.

**Codebase** — removed 9 dead Dart files (emptied `lib/tools/`); relocated 4 `*_detail_sheet` widgets `screens/`→`widgets/`; removed 22 committed debug screenshots; added `.gitattributes` (LF). `dart format` clean · `flutter analyze` 0 issues · 23 tests pass.

**Release builds verified** — `flutter build apk --release --flavor sideload --split-per-abi` (3 signed APKs: arm64-v8a / armeabi-v7a / x86_64) and `flutter build windows --release` (`trailtether_app.exe`) both compile clean.

**Shipped 2026-05-29** ✅ — Android OTA live ([[app_releases]] 4.0.0 / versionCode **2062**, supersedes 3.7.6/2061 so existing phones get the update prompt); Windows live (GitHub release `v4.0.0-62`, signed `.msix` + `.cer`); website current (`analytics.js`/`subscribe.js` verified HTTP 200 + byte-identical to repo). Git `origin/main` @ `3143a27`. Advisor `function_search_path_mutable` cleared.

**Still to verify post-ship** (see [[Known Issues]]): a real payment finalizes (`verify_jwt` is `true` on webhooks); Google sign-in on the published APK; **enable Auth leaked-password protection** (still disabled per advisor); on-device QA of the core flows.

## v3.7.6+61 — Production Hardening
- **Telemetry**: Integrated `sentry_flutter` with GDPR/POPIA-compliant PII scrubbing via [[telemetry_service.dart]].
- **CI/CD**: Added GitHub Actions pipeline (analyze, test, format, dry-run APK build).
- **Safety**: Built [[offline_incident_queue.dart]] persistent retry queue for off-trail alerts.
- **Tests**: 23 automated tests covering offline queue, model parsing, and widget rendering.
- **Storage RLS**: Documented all 31 production storage policies in migration file.
- **Edge Functions**: Standardised all imports to `jsr:` specifiers.
- **Audit**: Resolved all P1 findings — CORS hardening, Turnstile timeout, off-trail resilience.

## v2.0.0 — Production Scaling Patch
- **Unification**: Merged detail-sheet logic for both 2D and 3D map views.
- **Maps**: Integrated Satellite hybrid styles as the primary tactical view.
- **UI**: Implemented high-performance sidebar search using MapLibre filters.
- **Terrain**: Added 3D DEM support with 1.5x exaggeration.

## v1.5.0 — Intelligence Update
- **Weather**: Added 3D Storm Mode with animated precipitation radar.
- **Telemetry**: Integrated Open-Meteo for live center-point weather reporting.
- **GPX**: Added client-side GPX import and elevation gain calculator.

## v1.0.0 — Initial Release
- Core GPS tracking and Leaflet map integration.
- Basic route list and distance calculations.
