---
type: changelog
status: current
area: history
aliases:
  - Version History
---

# 🗒️ Version History

## v4.0.5+69 — Live heart rate, single-recorder lockdown & live-watch scaffold (2026-05-30)
App-side session; built `--flavor sideload --split-per-abi` (arm64 43.0 MB, under the 50 MB OTA cap), installed + smoke-verified on the physical S24 (Android 16). Ships the in-app **Delete account** from the earlier same-day web session.

**Live heart rate (BLE)** — new [[HeartRateProvider]] (`flutter_blue_plus`) scans the standard **Heart Rate Profile** (service `0x180D` / char `0x2A37`, 8- & 16-bit decode), reads battery (`0x2A19`) once, persists the chosen device and silently auto-reconnects on adapter-on with a >10 s stale-signal guard. **The BLE link itself is the connected/disconnected indicator.** Runtime perms `BLUETOOTH_SCAN`(neverForLocation)/`BLUETOOTH_CONNECT` added to the manifest. Surfaced as a "Live heart rate" card in [[PairWatchScreen]] (scan sheet → connect → big BPM/battery/disconnect) and a "♥ N bpm · live" line on the [[TTProfileScreen]] watch tile. Works with the Instinct in **Broadcast Heart Rate** mode or any BLE chest strap. HR-only by design. (commit `b0ca413`)

**HR written onto the route** — [[RecordingPoint]] gained an optional `hr`; [[recording_provider.dart]] samples the live BPM into every point while recording and exposes `avgHr`/`maxHr`; a slim live-HR strip shows in the **Map-tab recorder** ([[TTMapScreen]]). Wired via a `ChangeNotifierProxyProvider<HeartRateProvider, RecordingProvider>` in `main.dart` so the recorder reads the live source. Covers both phone- and (future) watch-recorded hikes.

**One recorder, locked down** — there were **two** ways to record: the canonical Map-tab recorder and a duplicate [[LiveTrackingScreen]] reachable from the Teams-tab "trek-watch" map gesture. **Deleted `LiveTrackingScreen`** (1,403 LOC, commit `eb7b7d0`); the Teams gesture now routes to the Map tab (`onNavigate(1)`), not a second recorder. No auto-start — routing only shows the map.

**Team vs individual attribution hardened** — [[FinishHikeSheet]] now passes `teamId` **only when the save context is explicitly `team`** (was leaking the last-selected team onto solo saves); context defaults to *personal*, team dropdown shows only in team context. Team hikes populate the Teams tab; solo hikes the hiker's individual history — no erroneous/mis-attributed records.

**Live-watch link — scaffolded, gated on the Garmin SDK** — the chosen "truly instant/live" path (start on the watch → phone mirrors live, no sensor pairing). Done: watch `HikeRecorder.transmitLive()` streams full live metrics ~1 Hz via `Communications.transmit`; phone-side `WatchLiveService` + `WatchLiveProvider` + `WatchLiveScreen` (reachable from Pair Watch). **Remaining = the Android Kotlin plugin wrapping the Connect IQ *Mobile* SDK** (the `.aar` isn't on Maven — user downloads it → `android/app/libs/connectiq.aar`). Spec in `trailtether_watch/HANDOFF_live_link.md`; see [[Open Follow-Ups]].

**Social planner — foundation only, gated on Meta setup** — applied migration `20260530_social_posts_planner`: `social_posts` table (caption, media_urls[], platforms[], post_type, status, scheduled_at, results jsonb…) with `is_admin()`-gated RLS + a public `social-media` storage bucket. The composer UI + `social-publish` edge fn + scheduler cron come once the user completes Meta setup (FB Page, IG Business/Creator, long-lived token). See [[Open Follow-Ups]].

**Community feed cleaned** — purged **9 test-artifact** entries from [[community_activities]] (watch-ingest tests the user never actually saved); 3 real hikes kept.

**CI** — fixed two red checks (see [[Troubleshooting & Fixes]]): the new PC screens were imported but never committed (`uri_does_not_exist`), and a hardcoded `org.gradle.java.home` broke the runner's APK build. Green after both. Project-wide `flutter analyze`: 0 issues.

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
