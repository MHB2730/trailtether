---
tags: [type/module, layer/frontend, status/stable, domain/web, domain/admin]
aliases: [hilltrek-admin, admin SPA]
source_paths: [hilltrek-admin/app.js, hilltrek-admin/index.html, hilltrek-admin/scripts/generate_site.py, hilltrek-admin/templates]
---

# Hilltrek Admin Module

Hash-routed vanilla-JS SPA at **admin.hilltrek.co.za**. One `app.js` (~4,500 LOC) orchestrates everything.

## Auth gate

On load, calls [[is_admin]] RPC. If not an admin, shows a "no access" view. The Supabase URL + anon key live in `config.js`; service-role operations are blocked by RLS on the server. Every query is gated server-side, not client-side.

## Routing

Hash-based: `#/dashboard`, `#/newsletters`, `#/newsletters/new`, `#/newsletters/<uuid>/edit`, `#/orders`, `#/hikers`, `#/trailtether`, `#/publish`, etc. Lines 486-515 are the route dispatcher.

## Views (inline sections of `app.js`)

| View | Hash | What it does |
|---|---|---|
| Dashboard | `#/` | Stats summary |
| Newsletters list | `#/newsletters` | List + status + recipient counts (queries [[site_newsletters]]) |
| Newsletter edit | `#/newsletters/new` or `#/newsletters/<id>/edit` | Markdown editor (using `marked` from CDN) + segment filter + Send Test / Send Live (calls [[newsletter-send]]) |
| Newsletter detail | `#/newsletters/<id>` | View sent-newsletter stats (counts, errors, send-row list from [[site_newsletter_sends]]) |
| Orders | `#/orders` | List of merch orders (queries [[site_orders]] + [[site_order_items]]) |
| Hikers | `#/hikers` | Trailtether user / team list (calls [[admin_trailtether_top_hikers]], [[admin_trailtether_teams]]) |
| Trailtether tab | `#/trailtether` | Stats strip ([[admin_trailtether_stats]]), active users map ([[admin_trailtether_active_users]]), recent hikes ([[admin_trailtether_recent_hikes]]) |
| Subscribers | (route) | Browse [[site_subscribers]] |
| APK Downloads | (route) | Browse [[apk_downloads]] (gated downloads, segments by newsletter opt-in) |
| Publish | `#/publish` | One-click "publish site" button → invokes [[publish-site]] |

## Static templates

`hilltrek-admin/templates/` holds Jinja2-style HTML templates rendered by `scripts/generate_site.py`:

- `_hike-card.html`, `_product-card.html` — list cards
- `hike-detail.html` — single-hike landing
- `hikes-index.html` — hikes overview
- `merch-index.html` — product index

These are used by [[publish-site]] edge function when publishing changes from the admin SPA to the static site.

## Site renderer

`hilltrek-admin/scripts/generate_site.py` is the Python script that reads from Supabase (hikes, products, FAQ, testimonials from [[site_settings]]) and writes the static HTML files into the public site directory. Invoked server-side by [[publish-site]].

## Files

| File | Role |
|---|---|
| `index.html` | SPA shell (single root + script tag) |
| `app.js` | ~4,500 LOC vanilla SPA |
| `config.js` | Supabase URL + anon key |
| `styles.css` | Site CSS |
| `scripts/generate_site.py` | Site renderer |
| `templates/*.html` | Page templates |
| `README.md` | Setup notes |

## Depends on

- [[Supabase Migrations Module]] (the schema it queries)
- [[Supabase Functions Module]] (the operations it triggers — [[newsletter-send]], [[publish-site]], etc.)
- [[is_admin]] RPC (auth gate)
- `marked` CDN (markdown render in newsletter editor)

## Used by

- The admin (matt@hilltrek.co.za) for content + ops management

## Deploy

```powershell
.\scripts\publish_site.ps1 -Target admin
```

Pushes `app.js`, `index.html`, `styles.css` to `admin.hilltrek.co.za` docroot. Lighter file list than the public site.

> [!warning] Verify
> `app.js` is monolithic and likely contains hidden technical debt (no module system, no minification, hash-routed only). Refactor candidate but not a current priority.
