---
tags: [type/model, layer/db, status/stable, domain/content, domain/commerce]
aliases: [public.site_products]
source_paths: []
---

# site_products

Hilltrek merch products. Each row is a sellable item.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| slug | text UNIQUE |
| name | text |
| price_cents | int |
| currency | text (ZAR) |
| description | text |
| body_md | text |
| hero_image | text |
| variants | jsonb (size, color, etc.) |
| in_stock | bool |
| published | bool |
| created_at, updated_at | timestamptz |

## CRUD locations

- **Authored** by [[Hilltrek Admin Module]] products editor
- **Read** by `generate_site.py` for `merch/index.html`
- **Read** at checkout time: [[place_order]] RPC pulls current product info to snapshot into [[site_order_items]]

## Used by

- [[Hilltrek Site Module]] merch/ page
- [[cart.js]] (after Add to Cart, prices come from the rendered page; product slug + variant key go into localStorage)
- [[place_order]] (validates product exists + computes total)
