---
tags: [type/endpoint, layer/backend, status/stable, domain/commerce, domain/webhook]
aliases: [zapper-webhook edge function]
source_paths: [supabase/functions/zapper-webhook/index.ts]
---

# zapper-webhook

**POST** `/functions/v1/zapper-webhook` (called by Zapper)

Zapper payment notification handler. HMAC-SHA256 signature.

## Auth

`verify_jwt: false` — Zapper signs the body. Defensive signature handling:
- Tries multiple header names: `X-Zapper-Signature`, `Zapper-Signature`, `X-Signature`, `Signature`
- Accepts hex or base64 encoding
- Strips optional `sha256=` prefix

> [!warning] Verify
> The exact signature scheme isn't documented by Zapper publicly. The function does multi-format verification defensively. Once a real production delivery is verified, narrow to the single format Zapper actually sends.

## Env vars

| Var |
|---|
| `ZAPPER_WEBHOOK_SECRET` (from merchant portal) |

## Verification

1. HMAC-SHA256 (`secret`, raw body) → hex + base64
2. Timing-safe compare against provided sig (cleaned of `sha256=` prefix)
3. Amount match against [[site_orders]]
4. Idempotent skip if order already `paid` for same invoice_ref

## Side effects (on valid)

- Updates [[site_orders]] `status` → `paid` (status=1) or `cancelled` (status=2)
- Sets `payment_completed_at` (from Zapper's `paymentUTCDate` or now)
- Updates `payment_provider_ref` to invoice ref
- Audit row in [[site_payment_events]]

## See also

- [[zapper-checkout]]
