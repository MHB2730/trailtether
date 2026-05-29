---
tags: [type/service, layer/frontend, status/stable, domain/observability]
aliases: [Sentry, Telemetry, Error reporting]
source_paths: [trailtether_app/lib/services/telemetry_service.dart]
---

# telemetry_service.dart

Centralized error reporting and observability wrapper around [Sentry](https://sentry.io) via `sentry_flutter ^8.8.0`.

## Initialization

Called from [[main.dart]] during app startup:

```dart
const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
await TelemetryService.init(dsn: sentryDsn);
```

If no DSN is compiled in (local dev), telemetry runs in **mock mode** — all calls are no-ops logged to [[logger_service.dart]].

## API

| Method | Purpose |
|---|---|
| `init(dsn, environment)` | Initialize Sentry with 10% trace sampling |
| `setUserContext(anonymousUserId, teamId?)` | Set anonymous user scope — no PII |
| `addBreadcrumb(category, message, data?, level?)` | Structured event breadcrumb |
| `captureException(exception, stackTrace?, hint?)` | Send handled exception to Sentry |

## Privacy (GDPR / POPIA)

The `beforeSend` callback (`_redactPiiBeforeSend`) scrubs every event before it leaves the device:
- **Email regex** — any email-like pattern in message text is replaced with `[REDACTED_EMAIL]`
- **IP address** — forced to `{{private}}` so Sentry never stores real IPs
- **User context** — only an anonymous UUID is sent, never names or phone numbers

## Build Integration

To enable in release builds:

```powershell
flutter build apk --release --dart-define=SENTRY_DSN=https://your-dsn@sentry.io/project
```

The CI pipeline (`.github/workflows/ci.yml`) does NOT inject a DSN — dry-run builds run in mock mode.

## See also

- [[logger_service.dart]] — local logging (always active)
- [[Known Issues]] — resolved telemetry type errors
- [[Tech Stack]] — `sentry_flutter` in dependency table
