---
tags: [type/model, layer/db, status/stable, domain/commerce]
aliases: [public.site_orders]
source_paths: [supabase/migrations/20260524_phase_b_orders.sql]
---

# site_orders

Hilltrek merch orders. Guest-checkout supported (no auth required).

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| order_number | text (sequential, human-readable) |
| customer_name | text |
| customer_email | text |
| customer_phone | text |
| shipping_address | jsonb |
| total_cents | int |
| currency | text (ZAR) |
| status | text (pending / processing / paid / cancelled / failed / refunded) |
| payment_provider | text (payfast / yoco / zapper) |
| payment_provider_ref | text (PayFast m_payment_id / Yoco checkout id / Zapper invoice ref) |
| payment_completed_at | timestamptz |
| confirmation_token | uuid (gates PII on confirmation page) |
| created_at, updated_at | timestamptz |

## RLS

- Public: insert via [[place_order]] RPC only
- Owner: read by `(id, confirmation_token)` via [[get_order_for_confirmation]] RPC
- Admin: full CRUD

## CRUD locations

- **Created** by [[place_order]] RPC from `cart/` → `checkout/` form on [[Hilltrek Site Module]]
- **Read** by `order-confirmation/` page via [[get_order_for_confirmation]]
- **Updated** by [[payfast-itn]] / [[yoco-webhook]] / [[zapper-webhook]] (authoritative status from payment provider)
- **Read** by [[Hilltrek Admin Module]] orders list

## See also

- [[site_order_items]] — line items
- [[site_payment_events]] — audit log of every payment provider callback
- [[Workflow - Checkout]]
