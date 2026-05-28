---
tags: [type/endpoint, layer/backend, status/stable, domain/commerce]
aliases: [yoco-checkout edge function]
source_paths: [supabase/functions/yoco-checkout/index.ts]
---

# yoco-checkout

**POST** `/functions/v1/yoco-checkout`

Creates a Yoco hosted-checkout session and returns the shopper-redirect URL.

## Request

```json
{ "order_id": "<uuid>" }
```

## Response

```json
{
  "redirect_url": "https://payments.yoco.com/...",
  "order_number": "HT-00042",
  "amount": "299.00",
  "provider": "yoco",
  "yoco_checkout_id": "ch_xyz"
}
```

## Auth

- `verify_jwt: true`
- CORS: hilltrek allowlist
- Service role for DB access

## Env vars

| Var | Purpose |
|---|---|
| `YOCO_SECRET_KEY` | `sk_test_xxx` or `sk_live_xxx` |

## Flow

1. Validate order_id, fetch [[site_orders]] (must be `status='pending'`)
2. Build Yoco API payload (amount in cents, ZAR, metadata with order_id + order_number, success/cancel/failure URLs with confirmation_token)
3. POST to `https://payments.yoco.com/api/checkouts` with `Idempotency-Key: <order.id>`
4. Stamp `payment_provider='yoco'` + `payment_provider_ref=<checkout id>` on the order
5. Return redirectUrl from Yoco response

## Idempotency

`Idempotency-Key: order.id` lets Yoco safely dedupe accidental double-clicks server-side. The Flutter `status !== 'pending'` check on our side adds belt+braces.

## Consumers

- [[Hilltrek Site Module]] `checkout/` page (when payment method = Yoco)

## See also

- [[yoco-webhook]]
- [[Workflow - Checkout]]
