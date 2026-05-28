---
tags: [type/config, layer/frontend, status/stable]
aliases: [pubspec.yaml]
source_paths: [trailtether_app/pubspec.yaml]
---

# Pubspec Configuration

`trailtether_app/pubspec.yaml` — the Flutter project manifest. Current version: **3.7.6+61** (after the recent commit).

## Versioning

Pattern: `<semver>+<build_code>`. `version_code` (the int after `+`) is what Android uses for upgrade detection; `version_name` (the semver) is what users see.

## dependency_overrides

```yaml
dependency_overrides:
  app_links: 6.4.1
```

Pinned because of a regression in OAuth callback handling on desktop. See [[app_links]].

> [!warning] Verify
> Check if newer `app_links` versions have fixed the regression. If yes, remove the override.

## flutter section

Assets bundled:
- `assets/data/routes_cleaned.json` — 239-trail fallback for [[trail_service.dart]]
- `assets/data/caves.gpx` — cave waypoint data
- `assets/map/map3d.html`, `maplibre-gl.js`, `maplibre-gl.css` — bundled MapLibre GL JS
- `assets/icon/` — launcher icons

## Build configs

| Section | Purpose |
|---|---|
| `flutter_native_splash` | Color-only splash on Android (avoids stale hero image flash) |
| `flutter_launcher_icons` | Android + Windows launcher icons |
| `msix_config` | Windows MSIX packaging: identity, signing config (PFX outside repo), `protocol_activation: trailtether` for OAuth callback |

## dev_dependencies

- `flutter_lints ^4.0.0`
- `flutter_launcher_icons ^0.14.1`
- `flutter_native_splash ^2.4.1`
- `msix ^3.16.1`

No `flutter_test` packages beyond the SDK's built-in — no automated tests currently. See [[Build & Deploy]].

## See also

- [[Tech Stack]]
- [[External Dependencies]]
- [[Workflow - Release]] (when to bump version)
