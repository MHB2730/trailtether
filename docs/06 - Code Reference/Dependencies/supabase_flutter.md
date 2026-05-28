---
tags: [type/dep, layer/infra, status/stable, domain/backend]
aliases: [supabase_flutter]
source_paths: [trailtether_app/pubspec.yaml]
---

# supabase_flutter

`supabase_flutter: ^2.5.0`

The Flutter client SDK for Supabase. Provides:
- `Supabase.instance.client` — global client
- `.auth` — sign-in / sign-out / session
- `.from('table').select/insert/update/delete` — Postgrest builder
- `.rpc('name', params)` — call RPC
- `.storage.from('bucket').uploadBinary/download` — Storage
- Realtime channels (`channel('...').on(...).subscribe()`)

## Init

In [[main.dart]]:

```dart
await Supabase.initialize(
  url: kSupabaseUrl,
  anonKey: kSupabaseAnonKey,
  debug: false,
);
```

From [[supabase_options.dart]] (compiled into binary — anon key is public by design).

## Used by

- Every service in [[Flutter Services Module]]
- Every provider in [[Flutter Providers Module]]
- Most components directly (e.g. [[MainPcShell]] for `auth.currentUser`)

## Critical to verify

- `kSupabaseAvailable` flag in [[runtime_config.dart]] — set true after `Supabase.initialize` succeeds. Code paths that might run without Supabase check this first.
