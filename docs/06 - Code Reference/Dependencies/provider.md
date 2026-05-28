---
tags: [type/dep, layer/frontend, status/stable, domain/state]
aliases: [provider package]
source_paths: [trailtether_app/pubspec.yaml]
---

# provider

`provider: ^6.1.2`

Flutter's de-facto state-management package. The whole [[Flutter Providers Module]] uses it.

## Patterns in use

- `ChangeNotifierProvider(create: (_) => XProvider())` — owns a ChangeNotifier
- `ChangeNotifierProxyProvider<A, B>` / `ChangeNotifierProxyProvider2<A, B, C>` — depends on other providers
- `context.watch<X>()` — rebuilds on notify
- `context.read<X>()` — one-shot read in callbacks
- `context.select<X, T>(selector)` — narrow rebuilds to a derived value

## Examples in this app

- [[main.dart]] `MultiProvider` registers 16 providers + 2 proxies (SafetyProvider, TeamTrackingProvider)
- [[MainPcShell]] uses `context.watch<ap.AuthProvider>()` for the admin gate
- [[TTHomeScreen]] watches several providers for compositions
