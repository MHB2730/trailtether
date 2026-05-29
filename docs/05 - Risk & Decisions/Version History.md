---
type: changelog
status: current
area: history
aliases:
  - Version History
---

# 🗒️ Version History

## v3.7.6+61 — Production Hardening
- **Telemetry**: Integrated `sentry_flutter` with GDPR/POPIA-compliant PII scrubbing via [[telemetry_service.dart]].
- **CI/CD**: Added GitHub Actions pipeline (analyze, test, format, dry-run APK build).
- **Safety**: Built [[offline_incident_queue.dart]] persistent retry queue for off-trail alerts.
- **Tests**: 23 automated tests covering offline queue, model parsing, and widget rendering.
- **Storage RLS**: Documented all 31 production storage policies in migration file.
- **Edge Functions**: Standardised all imports to `jsr:` specifiers.
- **Audit**: Resolved all P1 findings — CORS hardening, Turnstile timeout, off-trail resilience.

## v2.0.0 — Production Scaling Patch
- **Unification**: Merged detail-sheet logic for both 2D and 3D map views.
- **Maps**: Integrated Satellite hybrid styles as the primary tactical view.
- **UI**: Implemented high-performance sidebar search using MapLibre filters.
- **Terrain**: Added 3D DEM support with 1.5x exaggeration.

## v1.5.0 — Intelligence Update
- **Weather**: Added 3D Storm Mode with animated precipitation radar.
- **Telemetry**: Integrated Open-Meteo for live center-point weather reporting.
- **GPX**: Added client-side GPX import and elevation gain calculator.

## v1.0.0 — Initial Release
- Core GPS tracking and Leaflet map integration.
- Basic route list and distance calculations.
