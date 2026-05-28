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
│   │   ├── main.dart            → app entry, MultiProvider, AuthGate
│   │   ├── core/                → constants, design tokens, kalman, theme
│   │   ├── models/              → Trail, RecordingPoint, SavedHike, etc.
│   │   ├── providers/           → 17 ChangeNotifier state holders
│   │   ├── screens/             → 23 top-level screens (post-cleanup)
│   │   │   ├── pc/              → MainPcShell + PcTrailsScreen
│   │   │   └── admin/           → MissionControlTab + AdminSettingsTab
│   │   ├── services/            → 27 service classes (Supabase wrappers + utils)
│   │   ├── tools/               → standalone tools (bubble level, flashlight)
│   │   └── widgets/             → 36 reusable widgets
│   │       ├── common/          → shared utility widgets
│   │       ├── design/          → TT* design primitives
│   │       ├── map/             → trail/incident/cave map layers
│   │       ├── review/          → review card / form widgets
│   │       └── trail/           → trail detail widgets
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
│   ├── migrations/              → 13 SQL migrations (chronological)
│   │   ├── 20260524_phase_b_orders.sql           → merch checkout schema
│   │   ├── 20260524_phase_c_payment_events.sql   → payment audit log
│   │   ├── 20260526_admin_trailtether_rpcs.sql   → admin Trailtether tab RPCs
│   │   ├── 20260526_advisor_cleanup.sql          → security advisor cleanup
│   │   ├── 20260526_apk_download_gate.sql        → APK gate schema
│   │   ├── 20260526_cron_secret_to_vault.sql     → secrets to vault
│   │   ├── 20260526_finalize_orphan_hikes_cron.sql
│   │   ├── 20260526_profiles_pii_lockdown.sql    → profiles RLS
│   │   ├── 20260527_berg_live_*.sql              → 4 migrations for Berg Live pulse
│   │   └── 20260527_curated_trails_table.sql     → trails CRUD
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
├── docs/                        → existing project docs (separate from this vault)
│   ├── Architecture/, Bugs/, Build/, Changelog/, Features/, FieldOps/, Marketing/, design/
│   ├── Home.md
│   └── vault/                   → THIS VAULT
│
├── .codex/, .claude/, .vscode/, .idea/  → editor config
├── .gitignore, .mcp.json
└── README.md                    → top-level orientation
```

## What was deleted in cleanup

Deleted (commits `791c0d4` and earlier in `988bb2e`):
- `trailtether_rn/` — Expo/React Native predecessor, frozen at v3.2.2
- `src/`, `public/data/`, `dist/`, `backup/` — pre-Flutter Vite site remnants
- `trailtether_app/lib/screens/admin/admin_shell.dart` + 9 tab files — replaced by [[MainPcShell]] using just [[MissionControlTab]] + [[AdminSettingsTab]] + [[PcTrailsScreen]]
- `trailtether_app/lib/screens/{home_tab,map_screen,chat_tab,teams_tab,tools_tab,desktop_shell}.dart` — replaced by `tt_*.dart` equivalents
- `trailtether_app/master_supabase_setup.sql` — frozen schema dump from initial commit

## Conventions in `lib/`

- `tt_*.dart` files are the **live** Trailtether 2.0 design-system screens (mobile primary nav).
- `pc/pc_*.dart` files are **desktop-only** (Windows / macOS / Linux).
- `admin/` holds shared admin tabs reachable from MainPcShell (gated by [[is_admin]]).
- `_attachments/` is the vault's own; don't confuse with `assets/`.
