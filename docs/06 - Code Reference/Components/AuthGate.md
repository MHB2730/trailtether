---
tags: [type/component, layer/frontend, status/stable, domain/auth]
aliases: [auth_gate]
source_paths: [trailtether_app/lib/screens/auth_gate.dart]
---

# AuthGate

The root post-auth router. Decides which shell renders based on auth state + screen size.

## Public surface

- `AuthGate({ super.key })` — used by [[main.dart]] inside `MaterialApp.home`

## Logic flow

```mermaid
flowchart TD
  A[AuthGate.build] --> B{auth.user == null?}
  B -- yes --> C[show TTWelcomeScreen<br/>sign-in surface]
  B -- no --> D{MediaQuery width > 900?}
  D -- yes --> E[MainPcShell]
  D -- no --> F[AppShell]
```

Watches [[auth_provider.dart]] via `context.watch<ap.AuthProvider>()`. On auth state change, rebuilds → either `WelcomeScreen` (or one of the TT welcome variants) or one of the shells.

## Used by

- [[main.dart]] (wraps in `UpdateGate`)

## Depends on

- [[auth_provider.dart]] — for current user
- [[AppShell]] — mobile shell
- [[MainPcShell]] — desktop shell
- [[Workflow - Auth]]

## Side effects

- None directly. Auth state is owned by [[auth_provider.dart]].

## Key file

- `lib/screens/auth_gate.dart` (~80-90 LOC)
