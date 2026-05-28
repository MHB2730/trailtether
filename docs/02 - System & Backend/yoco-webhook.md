---
tags: [type/endpoint, layer/backend, status/stable, domain/commerce, domain/webhook]
aliases: [yoco-webhook edge function]
source_paths: [supabase/functions/yoco-webhook/index.ts]
---

# yoco-webhook

**POST** `/functions/v1/yoco-webhook` (called by Yoco)

Standard Webhooks signature scheme. Authoritative source of Yoco payment status.

## Auth

`verify_jwt: false` — Yoco doesn't send a Supabase JWT. HMAC-SHA256 signature IS the auth.

Triple-check:
1. HMAC-SHA256 signature verify (timing-safe)
2. Timestamp window (5min tolerance — anti-replay)
3. Amount match against [[site_orders]].total_cents

## Env vars

| Var | Purpose |
|---|---|
| `YOCO_WEBHOOK_SECRET` | from Yoco merchant portal |

## Audit log

Every webhook (valid or not) → row in [[site_payment_events]].

## Side effects (on valid)

- Updates [[site_orders]] `status` (`succeeded` event → `paid`, `failed` → `cancelled`)
- Sets `payment_completed_at`
- Updates `payment_provider_ref` to final payment id (was just checkout id before)

## See also

- [[yoco-checkout]]
- [[Workflow - Checkout]]
