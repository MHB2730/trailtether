---
tags: [type/model, layer/db, status/stable, domain/ops]
aliases: [public.site_settings]
source_paths: []
---

# site_settings

Key-value (or single-row) configuration for Hilltrek operational toggles.

## Schema

| Column | Type |
|---|---|
| key | text PK (or just one row with named columns) |
| value | text/jsonb |
| updated_at | timestamptz |

> [!warning] Verify
> Schema not in the inspected migrations. Likely a key-value table or a singleton row with multiple columns. Confirm shape if making changes.

## Known keys / fields

- `maintenance_mode` — bool, read by [[maintenance-gate.js]] on every public page load
- `cron_secret` — **was** stored here in plain text; moved to `vault.secrets` in `20260526_cron_secret_to_vault.sql`. Now only legacy / fallback.
- `faq` / `testimonials` / etc. — content payloads for [[publish-site]] renderer

## RLS

- Public read on safe keys (maintenance_mode)
- Admin-only write (gated by [[is_admin]])

## CRUD locations

- **Read** by [[maintenance-gate.js]] for site downtime gating
- **Read** by [[publish-site]] for content payload
- **Updated** by [[AdminSettingsTab]] + [[Hilltrek Admin Module]]
