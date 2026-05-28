---
tags: [type/endpoint, layer/backend, status/stable, domain/admin]
aliases: [publish-site edge function]
source_paths: [supabase/functions/publish-site/index.ts]
---

# publish-site

**POST** `/functions/v1/publish-site`

One-click admin publish. Renders static HTML from CMS data + pushes files to cPanel via UAPI.

## Auth

- `verify_jwt: true`
- Internal: calls [[is_admin]] RPC → 403 if not

## Env vars

| Var |
|---|
| `CPANEL_HOST` (e.g. `fennec.aserv.co.za`) |
| `CPANEL_USER` (`hilltro7a4x5`) |
| `CPANEL_API_TOKEN` |
| `CPANEL_HOME` (e.g. `/home/hilltro7a4x5/public_html`) |

## Flow

1. Auth gate
2. Read hikes / products / FAQ / testimonials from [[site_hikes]], [[site_products]], [[site_settings]]
3. Render HTML using templates from `hilltrek-admin/templates/`
4. POST each generated file to cPanel `Fileman/upload_files` UAPI with `Authorization: cpanel <user>:<token>`

## Consumers

- [[Hilltrek Admin Module]] "Publish to live site" button (`#/publish`)

## Note

Mirrors [[publish_site.ps1]] but server-side. The PowerShell script is for manual ops (development); this edge function is for one-click admin publishing.
