---
tags: [type/model, layer/db, status/stable, domain/release]
aliases: [public.apk_downloads]
source_paths: [supabase/migrations/20260526_apk_download_gate.sql]
---

# apk_downloads

Audit log of gated APK downloads from the public site `/trailtether/` page. Legal evidence of T&Cs acceptance + newsletter opt-in audit.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| email | text |
| terms_accepted_at | timestamptz |
| newsletter_opt_in | bool |
| subscriber_id | uuid → site_subscribers.id (nullable) |
| apk_release_id | uuid → app_releases.id |
| apk_filename | text |
| apk_version_name | text |
| apk_version_code | int |
| ip | text (cf-connecting-ip or x-forwarded-for first IP) |
| ip_country | text (cf-ipcountry) |
| user_agent | text (sliced to 500 chars) |
| created_at | timestamptz |

## CRUD locations

- **Inserted** by [[apk-download-gate]] after Turnstile + email validation
- **Read** by [[Hilltrek Admin Module]] APK Downloads view (segmented by newsletter opt-in)

## Why this exists

POPIA-friendly audit: any user who clicked through the gate has a row proving they saw + agreed to T&Cs. Newsletter opt-in is captured so the admin can segment.

## See also

- [[Workflow - APK Download]]
- [[apk-download-gate]] edge function
