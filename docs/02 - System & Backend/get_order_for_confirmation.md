---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/commerce]
aliases: [public.get_order_for_confirmation]
source_paths: [supabase/migrations/20260524_phase_b_orders.sql]
---

# get_order_for_confirmation

**RPC** `public.get_order_for_confirmation(p_order_id uuid, p_token text default null) returns jsonb` (SECURITY DEFINER)

Returns an order + items by (id, confirmation_token). Used by `order-confirmation/` page to show the shopper their receipt without requiring auth.

## Input

| Param | Note |
|---|---|
| `p_order_id` | uuid from URL `?id=...` |
| `p_token` | uuid from URL `?token=...` |

## Output

JSONB with order + items combined. Returns `null` if token doesn't match.

## Why token-gated?

The order page is anon-accessible (guest checkout supported). The token in the URL acts as a capability — only someone with the link sees the PII. Without `?token=`, the function returns a stripped "order received" view.

## Callers

- `hilltrek-site/order-confirmation/index.html`
- Confirmation URLs are baked into [[payfast-checkout]] return_url + [[yoco-checkout]] successUrl

## See also

- [[site_orders]], [[site_order_items]]
- [[Workflow - Checkout]]
