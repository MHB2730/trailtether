---
tags: [type/endpoint, layer/backend, status/stable, domain/commerce]
aliases: [payfast-checkout edge function]
source_paths: [supabase/functions/payfast-checkout/index.ts]
---

# payfast-checkout

**POST** `/functions/v1/payfast-checkout`

Generates the PayFast redirect URL for a pending order. md5-signed query string, PHP-urlencoded.

## Request

```json
{ "order_id": "<uuid>" }
```

## Response

```json
{
  "redirect_url": "https://sandbox.payfast.co.za/eng/process?...",
  "order_number": "HT-00042",
  "amount": "299.00",
  "mode": "sandbox"
}
```

## Auth

- `verify_jwt: true` (anon-callable via apikey header)
- CORS: hilltrek.co.za / www. / admin. allowlist
- Reads [[site_orders]] with service role (RLS would block anon)

## Env vars

| Var | Purpose |
|---|---|
| `PAYFAST_MERCHANT_ID` | from PayFast dashboard |
| `PAYFAST_MERCHANT_KEY` | from PayFast dashboard |
| `PAYFAST_PASSPHRASE` | optional signature salt |
| `PAYFAST_MODE` | `sandbox` (default) or `production` |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | injected |

## Flow

1. Validate order_id in body
2. Fetch [[site_orders]] row (must be `status='pending'`)
3. Build field array (`merchant_id`, `merchant_key`, `return_url`, `cancel_url`, `notify_url`, customer info, amount, `m_payment_id`, `custom_str1`)
4. Compute md5 signature using `pfEncode` (PHP urlencode rules)
5. Build GET URL and return

## Consumers

- [[Hilltrek Site Module]] `checkout/` page (when payment method = PayFast)

## See also

- [[payfast-itn]] — notification handler
- [[Workflow - Checkout]]
