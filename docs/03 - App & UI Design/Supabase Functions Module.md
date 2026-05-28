---
tags: [type/module, layer/backend, status/stable, domain/edge]
aliases: [Edge Functions]
source_paths: [supabase/functions]
---

# Supabase Functions Module

15 Deno/TypeScript edge functions in `supabase/functions/`. Each is its own directory with a single `index.ts`. No shared deno.json — each function pins its own deps.

## Deploy

| Path | Tool |
|---|---|
| Per-function | `mcp__supabase__deploy_edge_function` (used this session) or `supabase functions deploy <name>` |

All 15 listed in [[External Dependencies]]. Each function note in `05 - APIs & Interfaces/` documents its contract.

## Functions

### Payments

| Function | Purpose | verify_jwt | Note |
|---|---|---|---|
| [[payfast-checkout]] | Generate PayFast redirect URL | true | md5 signature, PHP urlencode |
| [[payfast-itn]] | PayFast notification handler | **false** | Auth = md5 + /eng/query/validate POST + amount match |
| [[yoco-checkout]] | Create Yoco hosted checkout | true | Idempotency-Key = order.id |
| [[yoco-webhook]] | Yoco notification handler | **false** | Auth = Standard Webhooks HMAC + timestamp tolerance |
| [[zapper-checkout]] | Create Zapper invoice | true | Returns deeplink to Zapper app |
| [[zapper-webhook]] | Zapper notification handler | **false** | Auth = HMAC-SHA256 (signature format unconfirmed) |

### Newsletter / email

| Function | Purpose | verify_jwt |
|---|---|---|
| [[newsletter-send]] | Admin newsletter blaster (test or live) | true (is_admin gate) |
| [[newsletter-track-click]] | 302-redirect with click-record | false (public hit) |
| [[newsletter-track-open]] | Tracking pixel | false (public hit) |
| [[subscriber-send-confirmation]] | Send confirm email | false (anon-callable, validates email+token pair) |

### Site ops + analytics

| Function | Purpose | verify_jwt |
|---|---|---|
| [[analytics-ingest]] | POPIA-safe pageview beacon | false |
| [[health-pinger]] | pg_cron uptime checker | false (cron-secret header) |
| [[publish-site]] | One-click admin publish (cPanel UAPI) | true (is_admin) |

### App distribution

| Function | Purpose | verify_jwt |
|---|---|---|
| [[apk-download-gate]] | Public APK download with Turnstile gate | true (anon-callable via apikey) |

### Background workers

| Function | Purpose | verify_jwt |
|---|---|---|
| [[finalize-orphan-hikes]] | Recover sessions that never called save | **false** (cron-secret header) |

## Common patterns

- **Deno entry**: `Deno.serve(async (req) => { ... })`
- **CORS**: Per-request `corsHeaders(req.headers.get('origin'))` with `ALLOWED_ORIGINS` allowlist
- **Service role**: `createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)` bypasses RLS for reads/writes
- **Rate limiting**: Some functions use a `Map<string, {count, reset}>` per-IP. Persists while isolate stays warm; cold start resets.
- **JSON helpers**: Inline `j()` or `jsonResp()` that mixes CORS headers + content-type + status
- **Error returns**: Structured `{ ok: false, error: '<code>', detail: '...' }` JSON, status 4xx or 5xx

## Webhook auth model

Three webhook handlers (`payfast-itn`, `yoco-webhook`, `zapper-webhook`) all have `verify_jwt: false` and check signatures inline. The signature IS the auth. Every webhook event lands in [[site_payment_events]] audit table (valid or invalid) before any DB update.

## Cron jobs

| Function | Trigger | Auth |
|---|---|---|
| [[health-pinger]] | pg_cron every 1 min | `X-Cron-Secret` header from `vault.decrypted_secrets` |
| [[finalize-orphan-hikes]] | pg_cron hourly (minute 17) | `X-Cron-Secret` header from `vault.decrypted_secrets` |

## Depends on

- [[Supabase Migrations Module]] — every function queries tables
- [[denomailer]] for SMTP send (newsletter-send + subscriber-send-confirmation)
- [[supabase-js]] from JSR or esm.sh

## Used by

- [[Trailtether App Module]] (calls [[apk-download-gate]] indirectly via web download)
- [[Hilltrek Site Module]] (subscribe, analytics, checkout)
- [[Hilltrek Admin Module]] (publish, newsletter-send, admin RPCs)

## Local-vs-prod drift

Pre-session, **5 functions existed in production but not locally** (`analytics-ingest`, `health-pinger`, `newsletter-track-open`, `zapper-checkout`, `zapper-webhook`). Pulled into repo via MCP — see [[Audit Findings]].
