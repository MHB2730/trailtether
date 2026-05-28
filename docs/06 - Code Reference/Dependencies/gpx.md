---
tags: [type/dep, layer/frontend, status/stable, domain/trails]
aliases: [gpx package]
source_paths: [trailtether_app/pubspec.yaml]
---

# gpx

`gpx: ^2.2.0`

GPX file format parsing + writing.

## Primitives used

- `Gpx`, `Trk`, `Trkseg`, `Wpt` — model classes
- `GpxReader().fromString(xml)` — parse
- `GpxWriter().asString(gpx, pretty: true)` — serialise

## Consumers

- [[gpx_service.dart]] (`_parse`, `parseBytes`)
- [[recording_provider.dart]] (`exportGpx` — produces shareable GPX from recording)
- [[recorded_trail_service.dart]] (manual GPX string build for storage, simpler than going through this lib)

## Used in conjunction with

- `file_picker` (pick `.gpx`)
- `share_plus` (share to other apps)
