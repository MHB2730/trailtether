---
tags: [type/workflow, layer/frontend, status/stable, domain/admin, domain/trails]
aliases: [Trails admin]
source_paths: [trailtether_app/lib/screens/pc/pc_trails_screen.dart, trailtether_app/lib/services/trail_repository.dart, supabase/migrations/20260527_curated_trails_table.sql]
---

# Workflow - Trails CRUD

Admin's path to curate the [[trails]] catalogue on PC.

```mermaid
sequenceDiagram
  actor A as Admin
  participant PC as PcTrailsScreen
  participant TR as TrailRepository
  participant DB as Supabase trails
  participant SDP as StaticDataProvider
  participant Apps as Mobile + Map UI

  Note over A,PC: First time:
  A->>PC: tap "Seed from bundle"
  PC->>PC: confirm dialog
  PC->>TR: seedFromBundle(onProgress)
  TR->>TR: load routes_cleaned.json (239 rows)
  loop each trail
    TR->>DB: upsert trails ON CONFLICT(id) DO UPDATE
    TR-->>PC: onProgress(done, total) → progress bar
  end
  TR-->>PC: { inserted, skipped }
  PC->>SDP: refreshTrails()
  SDP->>TR: fetchAll()
  TR->>DB: SELECT
  DB-->>TR: rows
  TR-->>SDP: bundle-shape list
  SDP-->>Apps: notifyListeners

  Note over A,PC: Ongoing edits:
  A->>PC: tap Edit on a row
  PC->>A: show _TrailEditDialog
  A->>PC: save form (name, difficulty, category, published)
  PC->>TR: updateMeta(id, name, ...)
  TR->>DB: UPDATE
  DB-->>TR: ok
  PC->>SDP: refreshTrails()

  Note over A,PC: Delete:
  A->>PC: tap Delete
  PC->>A: confirm dialog (red destructive)
  A->>PC: confirm
  PC->>TR: delete(id)
  TR->>DB: DELETE
  PC->>SDP: refreshTrails()

  Note over A,PC: Add via GPX:
  A->>PC: tap "Add trail"
  PC->>PC: GpxService.pickAndParse() → UserGpxTrack
  PC->>A: _TrailEditDialog (with defaults from GPX)
  A->>PC: form save
  PC->>TR: upsertOne(bundleRow)
  TR->>DB: INSERT
  PC->>SDP: refreshTrails()
```

## Components

- [[PcTrailsScreen]] — UI
- [[trail_repository.dart]] — CRUD wrapper
- [[trail_service.dart]] — Supabase → cache → bundle loader (rebuilds cache on refresh)
- [[static_data_provider.dart]] — broadcasts to UI consumers
- [[gpx_service.dart]] — GPX file pick + parse

## Tables

- [[trails]] — single source of truth (Supabase)
- (legacy: `assets/data/routes_cleaned.json` — bundled fallback for first-launch / offline)

## RLS gating

- Anon / authenticated → SELECT WHERE `published = true`
- `is_admin()` → all rows + INSERT/UPDATE/DELETE

The PC UI is also gated at the **nav** layer: `_NavSpec.adminOnly: true` hides the Trails tab from non-admins (see [[MainPcShell]]). Two layers of defence.

## Performance note

`coords` columns can be large (1600-point trails ≈ 50KB per row). Total `trails` table size = ~700KB-1.2MB for the 239 rows. Reasonable.

## See also

- [[trail_service.dart]] cache → SharedPreferences key `trails_supabase_cache_v1`
- [[Audit Findings]] (Aasvoelkrans cosmetic issue addressed by this admin flow)
