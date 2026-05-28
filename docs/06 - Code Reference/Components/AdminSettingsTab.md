---
tags: [type/component, layer/frontend, status/stable, domain/desktop, domain/admin]
aliases: [admin_settings_tab]
source_paths: [trailtether_app/lib/screens/admin/admin_settings_tab.dart]
---

# AdminSettingsTab

Settings section of [[MainPcShell]]. Admin-only via `_NavSpec.adminOnly: true`. Houses Hilltrek admin operational toggles.

## What it shows

- Maintenance mode toggle (writes [[site_settings]].maintenance_mode)
- Cron secret rotation (writes to vault — see [[Edge Function Secrets]])
- App release management (list of [[app_releases]] rows, mark current, retire old)
- Admin allowlist editor ([[admin_users]] table CRUD)
- Diagnostic console (logs from `app_logs` table)

> [!warning] Verify
> Did not fully read this file in detail. Above is reasoned from the imports + sibling code. Confirm scope by reading `lib/screens/admin/admin_settings_tab.dart` directly if making changes.

## Used by

- [[MainPcShell]] settings section (admin-only)

## Depends on

- [[auth_provider.dart]] (for isAdmin)
- [[Supabase Migrations Module]] (writes to [[site_settings]], [[admin_users]], etc.)
- [[TT Design Tokens]]

## Key file

- `lib/screens/admin/admin_settings_tab.dart`
