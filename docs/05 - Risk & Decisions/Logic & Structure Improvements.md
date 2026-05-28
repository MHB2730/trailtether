---
type: roadmap
status: current
area: issues
aliases:
  - Logic & Structure Improvements
  - Refactoring Roadmap
  - Technical Debt Improvements
---

# 🏗️ Logical & Structural Improvements Roadmap

This document outlines structural refactoring, logical resilience patterns, and architectural alignments necessary to resolve active technical debt in Trailtether v2.0.

---

## 1. Monolithic Admin SPA (`hilltrek-admin/app.js`)
The admin panel is currently governed by a single 4,500 LOC vanilla JavaScript file. This increases reading overhead, leads to name-collision risks, and hinders testing.

### Proposed Improvement
*   **Decouple into ES Modules**: Split the file into separate module concerns:
    *   `js/services/auth.service.js` — Supabase authentication hooks and `is_admin` states.
    *   `js/services/newsletter.service.js` — Newsletter composer and Deno edge hooks.
    *   `js/views/orders.view.js` — Order lists and Yoco/PayFast state updates.
    *   `js/views/hikers.view.js` — Live Mission Control map tracking hooks.
*   **Build System (Optional/Future)**: If dependencies grow, introduce a lightweight build system (e.g., Vite) to bundle and minify `app.js` assets for CPANEL hosting.

---

## 2. Double Recording UIs
Currently, `LiveTrackingScreen` (full-screen map) and `TTMapScreen` (Map tab bottom sheet) both separately consume telemetry state from `RecordingProvider` and build independent HUDs. This creates functional divergence risks.

### Proposed Improvement
*   **Shared Recording HUD Component**: Extract a unified, reusable `TTRecordingHud` widget which maps elevation, distance, and duration states in one canonical widget.
*   **State Alignment**: Ensure both screens render this exact shared layout rather than custom inline layouts, guaranteeing exact parity across mapping surfaces.

---

## 3. Unifying the 3-Layer Trail Storage
Curated trail information drifts across three layers:
1.  On-disk offline JSON (`assets/data/routes_cleaned.json`)
2.  `SharedPreferences` cache (`trails_supabase_cache_v1`)
3.  Live Supabase database table (`trails`)

### Proposed Improvement
*   **Stale-While-Revalidate (SWR) Pattern**: Unify all retrievals inside `TrailRepository.loadTrails()`:
    ```
    InMemory Cache ---> Fallback (SharedPreferences Cache) ---> Fetch (Supabase) ---> Fallback (On-Disk JSON)
    ```
*   **Standardize Invalidation Hooks**: Centralize static cache clears inside `StaticDataProvider.refreshTrails()` to force layer invalidation when administrative edits occur inside `PcTrailsScreen`.

---

## 4. Supabase Schema & Migration Completeness
The `/supabase/migrations` folder only contains late additions from mid-2026. Fundamental core tables (such as `profiles`, `teams`, `hike_history`, `chat_messages`) and standard storage policies live solely in the production dashboard. **A fresh local environment cannot be bootstrapped from migrations alone.**

### Proposed Improvement
*   **Complete Schema Extraction**: Dump the live database structure using `supabase db dump` and consolidate this as `supabase/migrations/20260528000000_base_schema.sql` to represent the base foundation.
*   **Storage Policies Migration**: Script all dashboard RLS storage policies (e.g. for `profile-photos`, `gpx_uploads`) and capture them within a new migration.

---

## 5. Resilient Offline Telemetry Queueing
Active chat messages typed offline are stored in-memory only (unpersisted). Off-trail sentinel incidents are unawaited and dropped upon database inserts if the user undergoes short network drops in deep Drakensberg valleys.

### Proposed Improvement
*   **Chat Queue Persistence**: Port chat message drafts into a local database queue (SQLite/Hive) matching the mechanism used by `offline_track_queue.dart` to prevent data loss.
*   **Reliable Incident Sentinel**: Transition `_maybePublishOffTrailAlert` from an unawaited insert to the offline sync queue so that warnings are stored locally and successfully uploaded the moment signal returns.

---

## 6. Edge Function Security & Import Standardisation
Checkout APIs are currently inconsistent and insecure:
*   `zapper-checkout` allows wildcard (`*`) origins, creating a cross-origin transaction risk.
*   Imports use older `https://esm.sh` references alongside modern `jsr:` imports.

### Proposed Improvement
*   **Tighten CORS on Zapper**: Restrict origins to the `ALLOWED_ORIGINS` list matching PayFast:
    ```typescript
    const ALLOWED_ORIGINS = [
      "https://hilltrek.co.za",
      "https://www.hilltrek.co.za",
      "https://admin.hilltrek.co.za",
    ];
    ```
*   **Pin Deno Imports**: Standardise edge function imports to explicit, version-pinned `jsr:@supabase/supabase-js@2`.

---

## 📈 Improvement & Refactoring Checklist

- [ ] **Phase 1: Edge & Telemetry Security**
    - [ ] Restrict `zapper-checkout` CORS origin wildcards.
    - [ ] Standardise edge function imports to versioned JSR imports.
    - [ ] Add offline queue fallback to off-trail incident alerts (`recording_provider.dart`).
- [ ] **Phase 2: Database Disaster Recovery**
    - [ ] Extract full live schema definition into `supabase/migrations/`.
    - [ ] Export dashboard storage policies as a database SQL migration.
    - [ ] Seed base RPC `increment_recorded_trail_downloads` in schema.
- [ ] **Phase 3: Client Cache & UI Consolidation**
    - [ ] Consolidate caching logic in `TrailRepository` using SWR logic.
    - [ ] Extract unified recording HUD widget across `TTMapScreen` and `LiveTrackingScreen`.
- [ ] **Phase 4: Admin Refactoring**
    - [ ] Modularise monolithic `hilltrek-admin/app.js` into ES Module parts.
