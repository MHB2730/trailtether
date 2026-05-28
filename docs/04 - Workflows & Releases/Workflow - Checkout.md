---
tags: [type/workflow, layer/frontend, status/stable, domain/commerce]
aliases: [Checkout flow, Payment flow]
source_paths: [hilltrek-site/checkout, supabase/functions/payfast-checkout, supabase/functions/yoco-checkout, supabase/functions/zapper-checkout]
---

# Workflow - Checkout

Cart → place order → payment provider → webhook → confirmed receipt.

```mermaid
sequenceDiagram
  actor U as Shopper
  participant Site as hilltrek.co.za
  participant RPC as place_order
  participant DB as site_orders / items
  participant Edge as <provider>-checkout
  participant Pay as PayFast / Yoco / Zapper
  participant Hook as <provider>-webhook
  participant Conf as /order-confirmation/

  U->>Site: build cart (cart.js localStorage)
  U->>Site: go to /checkout/
  Site->>RPC: rpc('place_order', {p_items, p_customer})
  RPC->>DB: INSERT site_orders + site_order_items + line_variants
  DB-->>RPC: order id
  RPC-->>Site: { order_id, confirmation_token }
  U->>Site: pick payment method
  Site->>Edge: invoke('<provider>-checkout', {order_id})
  alt PayFast
    Edge->>Edge: build md5-signed query string (php urlencode)
    Edge-->>Site: { redirect_url: 'https://...payfast.co.za/eng/process?...' }
  else Yoco
    Edge->>Pay: POST /api/checkouts with Idempotency-Key=order.id
    Pay-->>Edge: { redirectUrl, id }
    Edge->>DB: stamp payment_provider + payment_provider_ref
    Edge-->>Site: { redirect_url }
  else Zapper
    Edge->>Pay: POST /invoices
    Pay-->>Edge: { reference }
    Edge->>DB: stamp payment_provider + payment_provider_ref
    Edge-->>Site: { deeplink: 'https://zapper.com/payWithZapper?invoice=...' }
  end
  Site->>U: window.location = redirect_url
  U->>Pay: complete payment
  Pay-->>Hook: webhook (POST signed body)
  Hook->>DB: INSERT site_payment_events (signature_valid + raw payload)
  alt signature valid + amount match
    Hook->>DB: UPDATE site_orders SET status='paid', payment_completed_at
  else
    Hook-->>Hook: log + reject (no DB update)
  end
  Pay->>U: redirect to <success_url> = /order-confirmation/?id=...&token=...
  U->>Conf: visits with id + token
  Conf->>RPC: rpc('get_order_for_confirmation', {p_order_id, p_token})
  RPC-->>Conf: order JSON
  Conf-->>U: receipt page
```

## Components

- [[Hilltrek Site Module]] — cart, checkout, order-confirmation pages
- [[cart.js]] — localStorage cart
- [[place_order]] RPC
- [[get_order_for_confirmation]] RPC
- One of [[payfast-checkout]] / [[yoco-checkout]] / [[zapper-checkout]] (per chosen method)
- Matching webhook: [[payfast-itn]] / [[yoco-webhook]] / [[zapper-webhook]]

## Tables

- [[site_orders]] — the order row
- [[site_order_items]] — line items snapshot
- [[site_payment_events]] — every webhook (valid or invalid)
- [[site_products]] — what the order references

## Authoritative source of order status

The webhook handlers are the **only** authoritative writer of `status` and `payment_completed_at`. The shopper's redirect to `/order-confirmation/` is a UI display, not a source of truth. If the shopper closes the browser before the redirect, the webhook still fires and the order updates.

## Triple verification on webhooks

Every webhook handler does:
1. Signature verify (md5 for PayFast, HMAC-SHA256 for Yoco/Zapper)
2. Amount match against `site_orders.total_cents`
3. (PayFast only) POST to `/eng/query/validate` for double-check
4. Idempotent skip if order already `paid` for same provider_ref

## See also

- [[Audit Findings]] for the CORS hardening that just landed on payfast/yoco
- [[Known Issues]] for the same issue still open on zapper-checkout
