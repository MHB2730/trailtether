---
tags: [type/dep, layer/frontend, status/stable, domain/auth]
aliases: [app_links package]
source_paths: [trailtether_app/pubspec.yaml]
---

# app_links

`app_links: 6.4.1` (pinned, with explicit `dependency_overrides` entry)

Inbound deep-link routing. Required for the desktop OAuth callback flow.

## Why pinned

Per [[Pubspec Configuration]]:
```yaml
app_links: 6.4.1
dependency_overrides:
  app_links: 6.4.1
```

The override pins 6.4.1 specifically. Newer versions had a regression on OAuth callback handling on desktop. The override prevents transitive bumps from breaking sign-in.

> [!warning] Verify
> Confirm whether the override is still needed against current upstream. If 6.5+ has fixed the regression, remove the override to reduce maintenance.

## What it handles

- Custom scheme: `trailtether://login-callback?code=...` (registered via MSIX `protocol_activation: trailtether` on Windows; intent-filter on Android)
- Universal links / app links — not currently used

## Consumer

[[deep_link_service.dart]] (`DeepLinkService.init()`) — one-shot on launch + persistent stream listener. Exchanges the code for a Supabase session via `auth.getSessionFromUrl(uri)`.
