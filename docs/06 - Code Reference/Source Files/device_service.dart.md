---
tags: [type/source, layer/frontend, domain/platform]
aliases: [device_service]
source_paths: [trailtether_app/lib/services/device_service.dart]
---

# device_service.dart

`DeviceService` — stable anonymous device ID across platforms.

## Key members

| Member | Role |
|---|---|
| `getDeviceId()` | `Future<String>` — calls `TrailUtils.getDeviceId()` (from [[utils.dart]]). Falls back to a persisted UUID in SharedPreferences if the platform doesn't expose a stable hardware ID. Cached in `_cachedId` after first call. |

## Used by

- [[profile_provider.dart]] (to associate analytics/session with device)
- [[analytics-ingest]] edge function receives the device ID as part of the beacon payload
