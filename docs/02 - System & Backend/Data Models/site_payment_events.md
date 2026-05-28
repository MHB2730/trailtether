---
tags: [type/model, layer/db, status/stable, domain/commerce, domain/audit]
aliases: [public.site_payment_events]
source_paths: [supabase/migrations/20260524_phase_c_payment_events.sql]
---

# site_payment_events

Authoritative audit log for every PayFast / Yoco / Zapper callback. Every webhook lands here BEFORE any order state change, valid signature or not.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| order_id | text (nullable — may not match a real order) |
| provider | text (payfast / yoco / zapper) |
| payload | jsonb (raw webhook body) |
| signature_valid | bool |
| validate_ok | bool |
| ip_address | text |
| created_at | timestamptz |

## CRUD locations

- **Inserted** by [[payfast-itn]], [[yoco-webhook]], [[zapper-webhook]] on EVERY callback (including rejected ones)
- **Read** by [[Hilltrek Admin Module]] for forensic / dispute investigation

## Why log invalid webhooks too?

If an attacker tries to spoof a payment notification, this row tells the admin exactly what they sent + why we rejected it. Useful for:
- Forensics (was an attack attempted?)
- Debugging (did the provider change their signature scheme?)
- Compliance (proof of authoritative rejection)

## See also

- [[site_orders]] — what gets updated on valid webhook
- [[Workflow - Checkout]]
