---
tags: [type/config, layer/frontend, status/stable]
aliases: [Supabase init, runtime_config]
source_paths: [trailtether_app/lib/core/supabase_options.dart, trailtether_app/lib/core/runtime_config.dart, trailtether_app/lib/main.dart]
---

# Supabase Client Config

How the Flutter app connects to Supabase.

## Files

| File | Role |
|---|---|
| [[supabase_options.dart]] (`lib/core/`) | `kSupabaseUrl` + `kSupabaseAnonKey` constants compiled into the binary |
| [[runtime_config.dart]] (`lib/core/`) | `kSupabaseAvailable` mutable flag (set at startup) + `kAllowDemoMode` dart-define |
| [[main.dart]] | Calls `Supabase.initialize()` in startup sequence |

## Init code

```dart
try {
  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
    debug: false,
  );
  kSupabaseAvailable = true;
} catch (e, stack) {
  kSupabaseAvailable = false;
  LoggerService.error('SYSTEM', 'Supabase initialization failed', stack);
}
```

After this, `Supabase.instance.client` is the global client.

## Anon key safety

The anon key is intentionally public — it's compiled into the binary. RLS policies (per-table) enforce real access control. Service-role key is NEVER in the app binary; only in edge functions.

> [!warning] Verify
> Confirm by reading `lib/core/supabase_options.dart` directly that ONLY the anon key + URL are exposed. If a service-role key has ever been added there, it's a P0 leak.

## kAllowDemoMode

Build-time flag for offline demo mode (e.g. App Store screenshots). Compile with `flutter build apk --dart-define=ALLOW_DEMO_MODE=true` to enable. Various providers ([[chat_provider.dart]], etc.) substitute in-memory mocks when Supabase is unavailable AND demo mode is on.

## Service ↔ provider conditional behaviour

Many providers check `kSupabaseAvailable` before making Supabase calls — graceful degradation when offline at launch:

```dart
if (!kSupabaseAvailable) {
  // load from local cache only
  return;
}
```

## Deep links

[[deep_link_service.dart]] uses `app_links` to receive `trailtether://login-callback?code=...` and complete OAuth via `auth.getSessionFromUrl(uri)`. Registered in MSIX `protocol_activation: trailtether` + Android intent-filter.
