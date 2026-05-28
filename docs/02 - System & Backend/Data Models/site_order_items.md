---
tags: [type/model, layer/db, status/stable, domain/commerce]
aliases: [public.site_order_items]
source_paths: [supabase/migrations/20260524_phase_b_orders.sql]
---

# site_order_items

Per-order line items. Snapshot of product details at purchase time (so prices/names don't drift if the product is later edited).

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| order_id | uuid → site_orders.id (CASCADE) |
| product_slug | text |
| product_name | text (snapshot) |
| variant_label | text (snapshot, e.g. "Large / Black") |
| variant_json | jsonb |
| unit_price_cents | int |
| quantity | int |
| line_total_cents | int |

## CRUD locations

- **Created** by [[place_order]] RPC alongside the parent [[site_orders]] row
- **Read** by [[get_order_for_confirmation]] RPC, [[Hilltrek Admin Module]] order detail

## Why snapshot?

If a product is renamed, deleted, or its price changes after the order, the order still shows what the customer actually bought. This is the standard ledger pattern.

## See also

- `site_order_line_variants` — created in the same migration; may be related table for variant snapshots (verify if needed)
