---
tags: [type/model, layer/db, status/stable, domain/content]
aliases: [public.site_hikes]
source_paths: []
---

# site_hikes

Hilltrek's editorial hike content. Each row is a hike-landing page (e.g. "MJ Cave", "Tugela Falls"). Rendered to static HTML by [[publish-site]].

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| slug | text UNIQUE (URL slug, e.g. `mj-cave`) |
| name | text |
| summary | text |
| body_md | text (markdown content) |
| hero_image | text |
| difficulty | text |
| distance_km, elevation_gain_m | numeric |
| estimated_hours | numeric |
| published | bool |
| created_at, updated_at | timestamptz |

## CRUD locations

- **Authored** by [[Hilltrek Admin Module]] hikes editor
- **Read** by `generate_site.py` to render `hilltrek-site/hikes/<slug>/index.html`
- **Published** via [[publish-site]] edge function

## Difference from [[trails]]

- `site_hikes` = editorial content (long-form descriptions, hero photos, body markdown) for the public website
- [[trails]] = GPS data (coords, distance, elevation profile) used by the Flutter app

A hike landing page might reference a trail by slug, but they're distinct concepts.

## See also

- [[publish-site]] edge function
- [[Hilltrek Site Module]] hikes/ pages
