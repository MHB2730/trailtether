---
tags: [type/model, layer/db, status/stable, domain/safety]
aliases: [public.incidents]
source_paths: []
---

# incidents

Active safety incidents on the map. Hazard reports, SOS triggers, off-trail alerts, weather events.

## Schema (key columns)

| Column | Type | Note |
|---|---|---|
| id | uuid PK | |
| type | text | hazard / sos / lost_disoriented / weatherEvent / etc. |
| severity | text | info / warning / urgent |
| description | text | |
| lat, lon | numeric | |
| created_by | uuid → profiles.id | |
| reported_by_name | text | |
| is_emergency | bool | |
| status | text | open / acknowledged / resolved / flagged |
| photo_url | text | optional photo upload to incident-photos bucket |
| flag_count, verify_count | int | community moderation |
| created_at, updated_at | timestamptz | |

## CRUD locations

- **Streamed** by [[incident_service.dart]] (newest first, filters out resolved/flagged + dummy errors)
- **Created** by:
  - SosScreen → emergency SOS button
  - FieldIntelSheet → drop-pin hazard report
  - [[recording_provider.dart]] `_maybePublishOffTrailAlert` when hiker drifts off-trail >5min
  - [[weather_alert_service.dart]] for proactive weather alerts (severe events mirrored here)
- **Voted** via [[verify_incident]] / [[flag_incident]] / `increment_flag_count` RPCs
- **Read** by [[safety_provider.dart]] (proximity-filtered alerts), [[MissionControlTab]] (map markers)

## Side effects

- New incidents trigger notifications via [[notification_service.dart]] (5km radius for hazards, always for emergencies)
- Flag-count threshold flips status to `flagged` (community-moderated takedown)

## Used by

- [[safety_provider.dart]] — proximity alerts during recording
- [[MissionControlTab]] — map markers + IncidentDetailSheet
- [[TTMapScreen]] — incident layer overlays
