---
tags: [type/endpoint, layer/backend, status/stable, domain/commerce, domain/webhook]
aliases: [payfast-itn edge function]
source_paths: [supabase/functions/payfast-itn/index.ts]
---

# payfast-itn

**POST** `/functions/v1/payfast-itn` (called by PayFast servers)

PayFast Instant Transaction Notification handler. Authoritative source of order status.

## Auth

`verify_jwt: false` — PayFast can't send a Supabase JWT. Signature IS the auth.

## Triple verification

Every callback is validated three ways:
1. **md5 signature recompute** from form fields + passphrase
2. **POST to `/eng/query/validate`** at PayFast's host (sandbox or production) — they tell us yes/no
3. **Amount match** — `gross_amount` field equals our stored `total_cents/100`

All three must pass before the order updates.

## Audit log

EVERY callback (valid or not) → row in [[site_payment_events]]. Forensic trail.

## Side effects (on valid)

- Updates [[site_orders]] `status` to `paid` / `failed` / `cancelled`
- Sets `payment_completed_at`
- Sets `payment_provider_ref` to PayFast's `pf_payment_id`

## Consumers

- Called only by PayFast itself (set as `notify_url` in [[payfast-checkout]])

## See also

- [[payfast-checkout]]
- [[Workflow - Checkout]]
