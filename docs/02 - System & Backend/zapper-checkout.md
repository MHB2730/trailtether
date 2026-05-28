---
tags: [type/endpoint, layer/backend, status/stable, domain/commerce]
aliases: [zapper-checkout edge function]
source_paths: [supabase/functions/zapper-checkout/index.ts]
---

# zapper-checkout

**POST** `/functions/v1/zapper-checkout`

Creates a Zapper invoice and returns a deeplink the shopper can open in the Zapper mobile app.

## Request

```json
{ "order_id": "<uuid>" }
```

## Response

```json
{
  "provider": "zapper",
  "order_number": "HT-00042",
  "amount": "299.00",
  "pending_url": "https://hilltrek.co.za/payment-pending/?id=...&token=...",
  "deeplink": "https://zapper.com/payWithZapper?invoice=...",
  "invoice_reference": "INV-..."
}
```

## Auth

- `verify_jwt: true`
- CORS: **currently `*`** (regression vs payfast/yoco that were tightened — flagged in [[Audit Findings]])

## Env vars

| Var |
|---|
| `ZAPPER_API_KEY` |
| `ZAPPER_MERCHANT_ID` |
| `ZAPPER_SITE_ID` |
| `ZAPPER_SITE_REFERENCE` |
| `ZAPPER_API_BASE_URL` (default `https://api.zapper.com`) |

## Flow

1. Validate config + order_id
2. Fetch [[site_orders]] (must be `pending`)
3. POST to `<API_BASE>/business/api/v1/merchants/<MID>/sites/<SID>/invoices`
4. Parse Zapper response, extract `reference`
5. Stamp `payment_provider='zapper'` + `payment_provider_ref=<reference>`
6. Return deeplink (`https://zapper.com/payWithZapper?invoice=<ref>`)

## See also

- [[zapper-webhook]]
- [[Workflow - Checkout]]
- [[Audit Findings]] — CORS `*` issue
