---
tags: [type/source, layer/frontend, domain/auth]
aliases: [auth_service]
source_paths: [trailtether_app/lib/services/auth_service.dart]
---

# auth_service.dart

`AuthService` — wraps Google sign-in and Supabase auth.

## Key members

| Member | Type | Role |
|---|---|---|
| `authStateStream` | `Stream<AuthState>` | Re-exports `supabase.auth.onAuthStateChange` |
| `currentUser` | `User?` | Re-exports `supabase.auth.currentUser` |
| `signInWithGoogle()` | `Future<void>` | Platform-aware Google sign-in: native SDK on Android, OAuth flow on desktop |
| `signOut()` | `Future<void>` | Signs out of both Google SDK and Supabase |

## Platform behaviour

- **Android / iOS**: Uses `GoogleSignIn.signIn()` → extracts `idToken` + `accessToken` → `supabase.auth.signInWithIdToken()`
- **Desktop (Windows)**: Uses `supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: 'trailtether://login-callback')` — the callback is handled by [[deep_link_service.dart]]

## Dependencies

- `google_sign_in` package
- `supabase_flutter`
- [[supabase_options.dart]] — `kGoogleWebClientId`

## Used by

- [[auth_provider.dart]]
