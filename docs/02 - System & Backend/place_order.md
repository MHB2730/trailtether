---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/commerce]
aliases: [public.place_order]
source_paths: [supabase/migrations/20260524_phase_b_orders.sql]
---

# place_order

**RPC** `public.place_order(p_items jsonb, p_customer jsonb) returns uuid` (SECURITY DEFINER)

Creates a [[site_orders]] row + [[site_order_items]] rows from a cart payload. Anon-callable.

## Input

```json
p_items: [
  { "product_slug": "tt-buff", "variant": {"color":"black"}, "quantity": 2 },
  { "product_slug": "trail-map", "variant": null, "quantity": 1 }
]
p_customer: {
  "name": "Alice",
  "email": "alice@example.com",
  "phone": "+27...",
  "shipping_address": {"street":"...","city":"...","zip":"..."}
}
```

## Output

```sql
returns uuid  -- order.id
```

## Validation (server-side)

- Non-empty name + email
- Product slug exists in [[site_products]] + is published
- Quantity > 0
- Computes total from current `price_cents` (not client-supplied)

> [!warning] Verify
> [[Audit Findings]] flagged missing length caps + email format validation. Worth tightening if abuse becomes an issue.

## Callers

- [[Hilltrek Site Module]] `checkout/` form
- Then the caller invokes one of [[payfast-checkout]] / [[yoco-checkout]] / [[zapper-checkout]] with the returned order id

## See also

- [[site_orders]], [[site_order_items]]
- [[Workflow - Checkout]]
