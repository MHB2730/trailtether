---
tags: [type/architecture, layer/infra, status/stable]
aliases: [Stack]
source_paths: [trailtether_app/pubspec.yaml, hilltrek-admin/app.js, supabase/functions]
---

# Tech Stack

## Flutter app

| Package | Version | Role | Note |
|---|---|---|---|
| `flutter` SDK | 3.3.0+ | Framework | [[Pubspec Configuration]] |
| `supabase_flutter` | ^2.5.0 | Auth, Postgres client, Storage, Realtime | [[supabase_flutter]] |
| `provider` | ^6.1.2 | State management — 16 ChangeNotifierProviders in [[main.dart]] | [[provider]] |
| `flutter_map` | ^7.0.1 | 2D map (OpenTopo, Stadia tiles) | [[flutter_map]] |
| `flutter_map_tile_caching` | ^9.1.0 | FMTC offline tile cache, ObjectBox backend | [[offline_map_service.dart]] |
| `geolocator` | ^13.0.1 | GPS + permissions | [[geolocator]], [[location_service.dart]] |
| `latlong2` | ^0.9.0 | LatLng primitives | — |
| `gpx` | ^2.2.0 | Parse + write `.gpx` files | [[gpx]] |
| `webview_flutter` | ^4.10.0 | 3D map (MapLibre GL via WebView) | [[webview_flutter]] |
| `webview_windows` | ^0.4.0 | Windows WebView2 | — |
| `flutter_local_notifications` | ^17.2.2 | Local notifications (Android + iOS) | [[flutter_local_notifications]], [[notification_service.dart]] |
| `flutter_background_service` | ^5.1.0 | Foreground service for background tracking | [[location_service.dart]] |
| `flutter_compass` | ^0.8.0 | Magnetometer heading | [[LiveTrackingScreen]] |
| `sensors_plus` | ^6.1.0 | Bubble level + compass auxiliary | — |
| `battery_plus` | ^7.0.0 | Battery vitals | [[recording_provider.dart]] |
| `connectivity_plus` | ^6.0.3 | Online/offline detection | [[team_tracking_provider.dart]] |
| `device_info_plus` | ^10.1.0 | Device ID per platform | [[utils.dart]] |
| `package_info_plus` | ^8.0.2 | Current app version | [[update_service.dart]] |
| `permission_handler` | ^11.3.0 | Permissions wrapper | — |
| `file_picker` | ^8.1.2 | GPX upload | [[gpx_service.dart]] |
| `image_picker` | ^1.1.2 | Photo capture (profile, incident) | [[profile_provider.dart]] |
| `share_plus` | ^10.0.2 | Share GPX exports | — |
| `path_provider` | ^2.1.4 | Temp + documents directories | — |
| `shared_preferences` | ^2.3.2 | Local cache for drafts + settings | [[app_state_provider.dart]] |
| `app_links` | 6.4.1 (pinned override) | OAuth callback deep links (`trailtether://`) | [[app_links]], [[deep_link_service.dart]] |
| `http` | ^1.2.1 | Plain HTTP (Open-Meteo, BigDataCloud) | [[weather_service.dart]] |
| `google_sign_in` | ^6.2.1 | Google OAuth via SDK | — |
| `qr_flutter` | ^4.1.0 | QR codes for PC↔mobile pairing | [[Workflow - Auth]] |
| `mobile_scanner` | ^6.0.11 | QR scanner on mobile | — |
| `torch_light` | ^1.0.0 | Flashlight tool | [[TTToolsScreen]] |
| `fl_chart` | ^0.69.0 | Elevation profile charts | [[fl_chart]] |
| `crypto` | ^3.0.3 | SHA-256 verify of APK downloads | [[update_service.dart]] |
| `uuid` | ^4.4.0 | Hike IDs, draft tokens | — |
| `intl` | ^0.19.0 | Date/number formatting | — |
| `google_fonts` | ^6.2.1 | Manrope (text) + JetBrains Mono (numerals) | [[TT Design Tokens]] |
| `collection` | ^1.18.0 | UnmodifiableListView + minOrNull etc | — |
| `tray_manager` | ^0.2.1 | System tray icon on Windows | — |
| `window_manager` | ^0.4.3 | Window chrome on desktop | [[MainPcShell]] |
| `open_filex` | ^4.5.0 | Sideload-install downloaded APK | [[update_service.dart]] |
| `health` | 12.2.0 | Health Connect / HealthKit integration | — |

Dev: `flutter_lints ^4.0.0`, `flutter_launcher_icons ^0.14.1`, `flutter_native_splash ^2.4.1`, `msix ^3.16.1`.

## Edge functions (Deno)

| Dep | Used by | Role |
|---|---|---|
| `jsr:@supabase/supabase-js@2` | Most functions | DB client | [[supabase-js]] |
| `https://esm.sh/@supabase/supabase-js@2.45.0` | Payment functions, finalize-orphan-hikes | Older pinned import — non-standard | — |
| `https://deno.land/x/denomailer@1.6.0/mod.ts` | [[subscriber-send-confirmation]], [[newsletter-send]] | SMTP send | [[denomailer]] |
| `https://deno.land/std@0.224.0/crypto/mod.ts` | [[payfast-checkout]] | MD5 (not in WebCrypto) | — |

> [!warning] Verify
> Two different supabase-js imports across functions (jsr vs esm.sh). Should standardise on `jsr:` per Supabase's current recommendation.

## Static sites + admin SPA

No package.json at repo root anymore (legacy Vite remnants purged this session). Both `hilltrek-site/` and `hilltrek-admin/` are vanilla HTML/CSS/JS deployed to cPanel.

| Library | Source | Used in |
|---|---|---|
| `marked` (CDN) | unpkg.com | [[Hilltrek Admin Module]] for newsletter markdown rendering |
| Cloudflare Turnstile | cdn | [[Workflow - APK Download]] |
| MapLibre GL JS | bundled in `trailtether_app/assets/map/maplibre-gl.js` | [[TrailMap3DWidget]] |

## Infrastructure

- **Hosting**: Supabase (DB + auth + storage + edge), cPanel via Aserv (`fennec.aserv.co.za`) for static sites
- **Domains**: `hilltrek.co.za`, `www.hilltrek.co.za`, `admin.hilltrek.co.za`
- **CDN / WAF**: Cloudflare (Turnstile + `cf-ipcountry` + `cf-connecting-ip` headers used throughout)
- **Email**: SMTP (host configured per `SMTP_HOST` secret in edge functions — see [[Edge Function Secrets]])
- **Payments**: PayFast, Yoco, Zapper (ZAR only — [[Workflow - Checkout]])
- **Captcha**: Cloudflare Turnstile (on APK download gate; secret in `TURNSTILE_SECRET`)
- **Signing**: APK signed with stored cert; MSIX signed with `.pfx` outside the repo (`%USERPROFILE%\.trailtether-signing\`)
