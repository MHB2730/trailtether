---
tags: [type/config, layer/infra, status/stable]
aliases: [Publish Scripts Env]
source_paths: [scripts]
---

# Publish Scripts Config

How to configure the PowerShell publish scripts.

## publish_site.ps1 (cPanel deploy)

Required env (per shell session, NEVER committed):

```powershell
$env:CPANEL_HOST        = "fennec.aserv.co.za"
$env:CPANEL_USER        = "hilltro7a4x5"
$env:CPANEL_API_TOKEN   = "<token from cPanel → Manage API Tokens>"
$env:HILLTREK_PUBLIC_DIR = "/home/hilltro7a4x5/public_html"
$env:HILLTREK_ADMIN_DIR  = "/home/hilltro7a4x5/admin.hilltrek.co.za"
```

All 5 validated by `Require-Env` at the top of the script. Missing any → exit 1 with a helpful message.

## publish_release.ps1 (Android)

Required:
- `flutter` on PATH
- `gh` on PATH (for optional GitHub release)
- `SUPABASE_SERVICE_ROLE_KEY` for direct row insert into [[app_releases]]
- Android keystore configured per `android/key.properties`

## publish_windows.ps1 (Windows MSIX)

Required:
- `flutter` on PATH (pre-flight check)
- `gh` on PATH
- Signing cert at `%USERPROFILE%\.trailtether-signing\trailtether.pfx`
- Cert password passed via `--certificate-password` argument

## Throttling

Site uploads have an 800ms inter-file delay to avoid Aserv's CSF / LFD autoban. If the firewall trips (403/415/429), the script sleeps 90s and retries once before giving up on that file.

## See also

- [[Build & Deploy]]
- [[Scripts Module]]
