---
tags: [type/source, layer/frontend, domain/weather]
aliases: [weather_aggregator_service]
source_paths: [trailtether_app/lib/services/weather_aggregator_service.dart]
---

# weather_aggregator_service.dart

`WeatherAggregatorService` — fetches weather from multiple free sources in parallel and returns a consensus reading.

## Sources

| Source | Role |
|---|---|
| Open-Meteo (primary) | Full hourly + daily forecast. Defines the shape of `WeatherData`. |
| Met Norway / api.met.no (secondary) | Current + short-range forecast. Folded into the *current* reading only via median/mean. |

## Why two sources

A single misreading from one provider can't poison the forecast. Consensus reduces false alerts and bad hiking-condition scores.

## Key members

| Member | Role |
|---|---|
| `fetch(lat, lon)` | `Future<WeatherData?>` — runs both fetches in parallel (`Future.wait`). Primary defines shape; secondary's current values are blended into the primary result. Returns `null` on total failure. |

## Dependencies

- [[weather_service.dart]] — for the Open-Meteo call
- `dart:io` `HttpClient` — for met.no call
- [[WeatherData]] model

## Used by

- [[weather_provider.dart]]
