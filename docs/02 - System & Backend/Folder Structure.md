---
tags: [type/architecture, layer/infra, status/stable]
aliases: [Repo Tree, Structure]
source_paths: []
---

# Folder Structure

```
Trailtetherv2.0/
├── trailtether_app/             → Flutter mobile + Windows app
│   ├── lib/
│   │   ├── main.dart            → app entry, MultiProvider (16 providers + 2 proxy), UpdateGate → AuthGate
│   │   ├── core/                → 9 files: constants, design_tokens, kalman_filter, theme, utils,
│   │   │                          runtime_config, supabase_options, sun_utils, app_messenger
│   │   ├── models/              → 16 domain types
│   │   │                          Trail, RecordingPoint, SavedHike, Incident, CaveWaypoint,
│   │   │                          RecordedTrail, GpxTrack, HikerProfile, Team, ChatMessage,
│   │   │                          CommunityActivity, Review, Accommodation, Achievement,
│   │   │                          WeatherData, WeatherWarning
│   │   ├── providers/           → 17 ChangeNotifier state holders
│   │   ├── screens/             → 32 screen files
│   │   │   ├── pc/              → MainPcShell + PcTrailsScreen
│   │   │   └── admin/           → MissionControlTab + AdminSettingsTab
│   │   ├── services/            → 29 service classes (Supabase wrappers + platform utils)
│   │   └── widgets/             → 38 reusable widgets
│   │       ├── common/          → clear_chat_bar, user_avatar
│   │       ├── design/          → TT* design primitives (10 files)
│   │       ├── map/             → trail/incident/cave/accommodation map layers (12 files)
│   │       ├── review/          → review_card, review_summary_bar, star_rating_input
│   │       └── trail/           → elevation_chart
│   ├── assets/
│   │   ├── data/
│   │   │   ├── routes_cleaned.json    → bundled 239-trail fallback for [[trail_service.dart]]
│   │   │   └── caves.gpx              → cave waypoint data
│   │   ├── icon/                       → launcher icons
│   │   └── map/
│   │       ├── map3d.html              → 3D viewer (MapLibre GL)
│   │       └── maplibre-gl.{js,css}    → bundled MapLibre
│   ├── android/, windows/, ios/, web/ → platform projects
│   ├── pubspec.yaml             → see [[Pubspec Configuration]]
│   └── marketing/               → store listing assets
│
├── hilltrek-site/               → public marketing/commerce site
│   ├── index.html               → homepage
│   ├── assets/
│   │   ├── css/site.css
│   │   ├── js/                  → site.js, cart.js, subscribe.js, analytics.js, weather.js, maintenance-gate.js
│   │   └── img/
│   ├── cart/, checkout/         → multi-step cart UX
│   ├── hikes/                   → hike content pages (mj-cave, tugela-falls, etc.)
│   ├── merch/                   → product listing
│   ├── reviews/                 → product review pages
│   ├── trailtether/             → APK download landing + /terms
│   ├── subscribe/               → /confirm and /unsubscribe forms
│   ├── order-confirmation/      → post-payment receipt
│   ├── payment-cancelled/       → bailout landing
│   ├── pulse/                   → /pulse (Berg Live community leaderboard)
│   ├── reach-out/, privacy/, legal-notice/  → static pages
│   ├── 404.html, sitemap.xml, robots.txt
│
├── hilltrek-admin/              → admin SPA (login + CMS for the site)
│   ├── index.html               → SPA shell
│   ├── app.js                   → ~4500 LOC vanilla SPA (hash routing)
│   ├── config.js                → Supabase URL + anon key only (admin auth required for writes)
│   ├── styles.css
│   ├── scripts/
│   │   └── generate_site.py     → server-side renderer for [[publish-site]]
│   └── templates/               → Jinja2-ish HTML templates
│       ├── _hike-card.html
│       ├── _product-card.html
│       ├── hike-detail.html
│       ├── hikes-index.html
│       └── merch-index.html
│
├── supabase/
│   ├── migrations/              → 17 SQL migrations (chronological)
│   │   ├── 20260524_phase_b_orders.sql           → merch checkout schema
│   │   ├── 20260524_phase_c_payment_events.sql   → payment audit log
│   │   ├── 20260526_admin_trailtether_rpcs.sql   → admin Trailtether tab RPCs
│   │   ├── 20260526_advisor_cleanup.sql          → security advisor cleanup
│   │   ├── 20260526_apk_download_gate.sql        → APK gate schema
│   │   ├── 20260526_cron_secret_to_vault.sql     → secrets to vault
│   │   ├── 20260526_finalize_orphan_hikes_cron.sql
│   │   ├── 20260526_profiles_pii_lockdown.sql    → profiles RLS
│   │   ├── 20260527_berg_live_admin_kill_switch.sql
│   │   ├── 20260527_berg_live_lockdown_materialized_views.sql
│   │   ├── 20260527_berg_live_teams_consent.sql
│   │   ├── 20260527_berg_live_views_rpcs.sql     → Berg Live RPCs (berg_pulse_stats, leaderboard)
│   │   ├── 20260527_curated_trails_table.sql     → trails CRUD
│   │   ├── 20260528_recorded_trail_downloads_rpc.sql → increment_recorded_trail_downloads RPC
│   │   ├── 20260528_storage_rls_policies.sql     → storage bucket RLS documentation
│   │   ├── 20260529_community_activities_team_nullable.sql → team_id/team_name nullable (solo-activity fix)
│   │   └── 20260529_fix_download_rpc_search_path.sql    → search_path fix for increment_recorded_trail_downloads RPC
│   └── functions/               → 15 edge functions (one dir each, single index.ts)
│       ├── analytics-ingest/
│       ├── apk-download-gate/
│       ├── finalize-orphan-hikes/
│       ├── health-pinger/
│       ├── newsletter-send/
│       ├── newsletter-track-click/
│       ├── newsletter-track-open/
│       ├── payfast-checkout/
│       ├── payfast-itn/
│       ├── publish-site/
│       ├── subscriber-send-confirmation/
│       ├── yoco-checkout/
│       ├── yoco-webhook/
│       ├── zapper-checkout/
│       └── zapper-webhook/
│
├── scripts/                     → publish / build / utility scripts
│   ├── publish_release.ps1      → bump version → build APK → upload to Supabase → row in app_releases
│   ├── publish_windows.ps1      → flutter build windows → MSIX → sign → upload
│   ├── publish_site.ps1         → push static files to cPanel via UAPI
│   ├── device_smoke.ps1         → manual smoke test on a wired Android
│   ├── check_caves.py           → cave waypoint data sanity
│   └── merge_geojson_routes.py  → one-off route data merger
│
├── docs/                        → Obsidian vault (THIS vault), organised into numbered sections
│   ├── 01 - Strategy & Product/
│   ├── 02 - System & Backend/   → Folder Structure, Tech Stack, Build & Deploy, Data Models/
│   ├── 03 - App & UI Design/
│   ├── 04 - Workflows & Releases/
│   ├── 05 - Risk & Decisions/   → Known Issues, Open Follow-Ups, Version History
│   ├── 06 - Code Reference/     → Components/, Dependencies/, Source Files/
│   ├── 99 - Archive/            → legacy top-level docs (Architecture/, Bugs/, Build/, …)
│   └── Home.md
│
├── .codex/, .claude/, .vscode/, .idea/  → editor config
├── .gitignore, .mcp.json
└── README.md                    → top-level orientation
```

## Conventions in `lib/`

- `tt_*.dart` files are the **live** Trailtether 2.0 design-system screens (mobile primary nav).
- `pc/pc_*.dart` files are **desktop-only** (Windows / macOS / Linux).
- `admin/` holds shared admin tabs reachable from MainPcShell (gated by [[is_admin]]).
- `*_sheet.dart` (modal bottom sheets like `cave_detail_sheet`, `finish_hike_sheet`) live in `widgets/`, not `screens/`.
- `_attachments/` is the vault's own; don't confuse with `assets/`.

## What was deleted in cleanup

Deleted (commits `791c0d4` and earlier in `988bb2e`):
- `trailtether_rn/` — Expo/React Native predecessor, frozen at v3.2.2
- `src/`, `public/data/`, `dist/`, `backup/` — pre-Flutter Vite site remnants
- `trailtether_app/master_supabase_setup.sql` — frozen schema dump from initial commit

Deleted/moved in the v3.7.6+61 pre-release cleanup:
- 9 orphaned Dart files: `screens/{trails_tab,offline_download_screen,gpx_upload_screen}.dart`, `tools/{locations_tool,useful_info_tool}.dart`, `widgets/common/{glass_panel,blueprint_background}.dart`, `widgets/trail/difficulty_badge.dart`, `widgets/map/trail_map_3d_windows_export.dart`.
- Moved the 4 bottom-sheet widgets from `screens/` → `widgets/`.
- Removed 22 committed debug screenshots + `ui_dump.xml` + `trail_names.txt` (now gitignored).
- `screens/admin/admin_shell.dart` + 9 old tab files — replaced by [[MainPcShell]].
- `screens/{home_tab,map_screen,chat_tab,teams_tab,tools_tab,desktop_shell}.dart` — replaced by `tt_*.dart` equivalents.
- `welcome_screen.dart`, `welcome_features_screen.dart` — replaced by `tt_welcome_screen.dart` + `onboarding_screen.dart`.
- `chat_screen.dart` — renamed to `team_chat_screen.dart`.
