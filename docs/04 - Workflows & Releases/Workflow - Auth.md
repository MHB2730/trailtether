---
tags: [type/workflow, layer/frontend, status/stable, domain/auth]
aliases: [Auth flow, Sign-in]
source_paths: [trailtether_app/lib/main.dart, trailtether_app/lib/screens/auth_gate.dart, trailtether_app/lib/providers/auth_provider.dart, trailtether_app/lib/services/deep_link_service.dart]
---

# Workflow - Auth

User sign-in → JWT → admin role detection → protected routes.

```mermaid
sequenceDiagram
  actor U as User
  participant App as Trailtether app
  participant SB as Supabase Auth
  participant DB as profiles + admin_users
  participant AG as AuthGate

  U->>App: tap "Sign in with Google"
  App->>SB: initiate OAuth (PKCE)
  SB->>U: redirect to Google consent
  U->>SB: approve
  alt Desktop (Windows)
    SB->>App: trailtether://login-callback?code=...
    App->>App: DeepLinkService.handleUri (deep_link_service.dart)
    App->>SB: auth.getSessionFromUrl(uri)
  else Mobile
    SB-->>App: session via redirect (auth listener)
  end
  SB-->>App: session JWT
  App->>App: AuthProvider state change → notifyListeners
  AG->>DB: SELECT is_admin FROM profiles WHERE id = uid
  DB-->>AG: row
  AG->>AG: cache isAdmin
  alt MediaQuery.size > 900
    AG->>U: render MainPcShell
  else
    AG->>U: render AppShell
  end
  alt isAdmin
    Note over AG: PC: Trails + Settings tabs visible
  else
    Note over AG: PC: Trails + Settings hidden via _NavSpec.adminOnly
  end
```

## Components in this flow

- [[main.dart]] — initialises Supabase + DeepLinkService
- [[AuthGate]] — routes based on auth state + screen size
- [[auth_provider.dart]] — owns `isAdmin` flag (refreshed from [[profiles]])
- [[deep_link_service.dart]] — Windows OAuth callback handler
- [[MainPcShell]] / [[AppShell]] — shells dispatched by [[AuthGate]]

## Tables involved

- `auth.users` (Supabase Auth's internal table — triggered by [[handle_new_user]] to populate [[profiles]] on first sign-up)
- [[profiles]] — `is_admin` column drives the flag
- [[admin_users]] — backing allowlist for [[is_admin]] RPC

## Critical pieces

- **`trailtether://` URL scheme** — registered in `pubspec.yaml` msix_config + Android intent-filter
- **`is_admin` is cached locally** in [[auth_provider.dart]] (`_isAdmin` field) and refreshed on every auth state change

## Edge cases

- New user → [[handle_new_user]] trigger creates the matching [[profiles]] row automatically
- Signed-in non-admin sees the same shell, just with admin tabs filtered out — see [[MainPcShell]]
- Sign-out clears local state (achievements, hike history) but Supabase data persists (cloud-first)

## See also

- [[is_admin]] RPC
- [[Workflow - Live Team Tracking]] (depends on signed-in user)
