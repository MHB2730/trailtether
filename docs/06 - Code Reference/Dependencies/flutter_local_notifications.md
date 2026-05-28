---
tags: [type/dep, layer/frontend, status/stable, domain/notifications]
aliases: [flutter_local_notifications]
source_paths: [trailtether_app/pubspec.yaml]
---

# flutter_local_notifications

`flutter_local_notifications: ^17.2.2`

Local notifications on Android + iOS. The platform doesn't go through a push-notification provider — these are entirely local triggers.

## Use cases

- Off-trail alerts (from [[recording_provider.dart]] `_maybePublishOffTrailAlert`)
- Proximity hazard alerts ([[safety_provider.dart]])
- Proactive weather alerts ([[weather_alert_service.dart]])
- Realtime team incident broadcasts (via [[notification_service.dart]])

## Wrapper

[[notification_service.dart]] is the singleton wrapper around this plugin. Handles platform init, permissions, channel registration.

## Permissions

- Android 13+: requires runtime notification permission (requested via `permission_handler`)
- iOS: notification permission requested via plugin's `requestPermissions`
