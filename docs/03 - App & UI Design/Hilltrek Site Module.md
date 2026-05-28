---
tags: [type/module, layer/frontend, status/stable, domain/web]
aliases: [hilltrek-site, public site]
source_paths: [hilltrek-site]
---

# Hilltrek Site Module

Static HTML/CSS/JS marketing + commerce site at **hilltrek.co.za**. No build step — every page is hand-authored HTML deployed to cPanel via [[publish_site.ps1]].

## Page directories

| Path | Purpose | Dynamic? |
|---|---|---|
| `index.html` | Homepage + weather forecast | Hits [[weather.js]] |
| `cart/` | Shopping cart UX | Uses [[cart.js]] (localStorage) |
| `checkout/` | Multi-step checkout | Calls [[place_order]] → [[payfast-checkout]] / [[yoco-checkout]] / [[zapper-checkout]] |
| `order-confirmation/` | Post-payment receipt | Reads order via [[get_order_for_confirmation]] |
| `payment-cancelled/` | Bailout landing | Static |
| `hikes/` | Hike landing pages (mj-cave, tugela-falls, bushmans-cave) | Rendered by [[publish-site]] |
| `merch/` | Product listing | Rendered by [[publish-site]] from [[site_products]] |
| `reviews/` | Product review pages | Static |
| `trailtether/` | APK download landing | Calls [[apk-download-gate]] |
| `trailtether/terms/` | T&Cs for the APK gate | Static |
| `subscribe/` | Footer signup confirmation pages | `/confirm/` calls [[subscriber_confirm]], `/unsubscribe/` calls [[subscriber_unsubscribe]] |
| `pulse/` | Berg Live community leaderboard | Calls [[berg_pulse_stats]], [[berg_pulse_leaderboard]], etc. |
| `reach-out/`, `privacy/`, `legal-notice/` | Static info pages | — |

## JavaScript modules (`assets/js/`)

| File | Role |
|---|---|
| [[site.js]] | Shared site chrome: mobile nav toggle, smooth scroll, IntersectionObserver-driven reveal animations, FAQ accordion. No deps. |
| [[cart.js]] | Vanilla localStorage shopping cart. Public API: `.read()`, `.add()`, `.updateQty()`, `.remove()`, `.clear()`, `.count()`, `.subtotalCents()`, `.priceString()`, `.lineKey()`. Dedupes by slug + variant JSON. Fires `hilltrek:cart-changed` event. |
| [[subscribe.js]] | Footer email signup. Calls [[subscriber_signup]] RPC with `{p_email, p_source: 'site'}`. Then optionally invokes [[subscriber-send-confirmation]] edge function. |
| [[analytics.js]] | POPIA-safe pageview beacon. Per-tab session ID (sessionStorage). Posts `{session_id, path, referrer, ua, event_type}` to [[analytics-ingest]]. Uses `navigator.sendBeacon` on unload, fetch otherwise. |
| [[weather.js]] | Homepage 7-day forecast. Fetches Open-Meteo + BigDataCloud reverse geocode. Default Cathedral Peak. Hike-score formula mirrors `tt_home_screen.dart` (lines 1963-1972). |
| [[maintenance-gate.js]] | Reads [[site_settings]] `maintenance_mode` flag. Blocks page load if true (admin preview bypass via `?preview=1`). Fail-open 1200ms timeout. |

## Templating

`hilltrek-site/` is fully static after [[publish-site]] runs. The renderer lives in [[Hilltrek Admin Module]] (`hilltrek-admin/scripts/generate_site.py`) and uses templates from `hilltrek-admin/templates/`. The admin's "Publish to live site" button calls [[publish-site]] edge function, which executes that script + pushes via cPanel UAPI.

## Auth

The public site is **anonymous**. Users don't sign in. Identity comes from email (newsletter signup, APK gate, checkout). Edge functions consumed are anon-callable via the public anon key (sent as `apikey` header).

## Depends on

- [[Supabase Functions Module]] for dynamic ops (subscribe, checkout, analytics, APK gate)
- [[Hilltrek Admin Module]] for content publishing
- [[publish_site.ps1]] for manual deploys

## Used by

- End users browsing hilltrek.co.za
- Web crawlers (sitemap.xml + robots.txt + structured JSON-LD on pages)

## Deploy

```powershell
.\scripts\publish_site.ps1 -Target public
```

Pushes the curated file list defined inside the script to `/home/hilltro7a4x5/public_html` via cPanel UAPI. Throttled at 800ms/file to avoid LFD autoban. See [[Build & Deploy]].
