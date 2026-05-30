---
type: changelog
status: current
area: history
aliases:
  - Version History
---

# 🗒️ Version History

## 2026-05-30 — Account self-service, shop add-to-cart, Play prep & publish fix
Web + backend session (no app version bump; the in-app delete lands with the next Android publish).

**User account self-service** — new **hilltrek.co.za/account** portal: change password, newsletter/notification prefs, and POPIA account deletion. Backed by 3 new `authenticated`-only SECURITY DEFINER RPCs (`account_prefs` / `account_set_newsletter` / `account_set_notifications`) + the **`account-delete`** edge function (verify_jwt, confirm-own-email → full erasure across every personal-data table + the user's storage; deliberately spares site/CMS content). In-app **Delete account** added to the [[TTProfileScreen]] DANGER ZONE → calls `account-delete`. Satisfies Play's discoverable-delete requirement.

**Shop** — rebuilt `/merch/` as real **add-to-cart** (it had been reverted to mailto when a stale repo copy overwrote the live page — see [[Troubleshooting & Fixes]]). Slugs + prices aligned 1:1 to [[site_products]] so [[place_order]] resolves every item; shipping confirmed **R99** (the live [[site_settings]] value — earlier R150 text was my error, reverted). Added **Returns & Refunds** + **Shipping** policy pages, wired Returns / Shipping / Your-account into the footer site-wide, and added a "Delete your account" clause to the Privacy Policy. Cart + checkout got the footer links + a 5-min shipping-rate cache.

**Security posture confirmed** — RLS on all 44 tables, `is_admin()`-gated definers, and the **payment-webhook `verify_jwt` question is resolved**: webhooks are `verify_jwt=false` + signature-validated, checkout/admin stay `true`. Assessed Supabase-vs-GCP — a migration would not improve security and the cutover is the bigger risk. Still open: enable Auth leaked-password protection; `citext`/`pg_net` in `public` (cosmetic WARN, left as-is — unsafe to move on the live newsletter). See [[Open Follow-Ups]].

**Play Store prep** — no code blockers (build with `--flavor playStore`, NOT `sideload`; the `REQUEST_INSTALL_PACKAGES` "blocker" was a false alarm — present only in the sideload source set). Copy-ready **Data Safety** answer sheet written to `trailtether_app/PLAY_DATA_SAFETY.md`.

**Fixed** — admin **Publish → HTTP 403** on every file (stale cPanel API token; regenerated with no expiry/IP-lock + updated the `CPANEL_API_TOKEN` secret).

**Decision** — Supabase → Google Cloud direction set: **Cloud SQL + Google managed services**, driven by control / avoiding lock-in. Phased plan TBD.

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
