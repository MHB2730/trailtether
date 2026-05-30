---
tags: [type/module, layer/client, status/sideload, domain/recording, hardware/garmin]
aliases: [Garmin Watch App, Trailtether Watch, Instinct 3 App]
source_paths: [trailtether_watch/]
---

# Watch App Module

**Connect IQ watch-app** for the Garmin Instinct 3 AMOLED 45mm. Records hikes on the wrist, draws a live track map with off-route detection, and uploads to Supabase via the phone's Garmin Connect Bluetooth bridge. Standalone — *not* BLE-paired with the Trailtether phone app.

## What it does

- Activity picker (Hike / Trail Run / Walk / Climb) → maps to Garmin sport + `activity_type` string.
- Route picker pulls from [[watch-route]] (curated `public.trails` catalogue + the user's `recorded_trails`).
- GPS acquire → records with `ActivityRecording.Session`, filters jitter (`DIST_FILTER_M = 5m`, `MIN_SPEED_MPS = 0.7`, etc.).
- 4 live data pages (UP/DOWN paged): Timer, Elevation, Heart Rate, Map. + Route Profile when a course is loaded.
- Map page draws the live track as a glowing ember polyline, planned route in dimmed amber underneath, **OFF ROUTE pill** when >50 m off.
- Paused (RESUME / SAVE / DISCARD) → Summary (effort dial + 6-cell stat grid).
- Dedicated **Sync** screen on the SAVE → upload path: animated packets between watch and phone glyphs, progress bar, returns to summary with ✓SYNCED / FAILED chip.

## Architecture (decided 2026-05-29)

Cloud-mediated, "Strava-shaped" rather than BLE-paired:

```
Watch ── Communications.makeWebRequest ──► phone's Garmin Connect BT bridge
                                            │
                                            ▼
                                        Supabase Edge Functions
                                            │
                                            ▼
                                   [[watch-ingest]]  +  [[watch-route]]
                                            │
                                            ▼
                                  hike_history + recorded_trails (RLS by user_id)
```

The Instinct has no WiFi — HTTP rides the phone's BT bridge. Off-grid the request fails fast ("No phone"); on reconnect the user retries.

## Auth

- Anon JWT satisfies `verify_jwt: true` on the edge functions.
- User is resolved server-side from the **`x-device-token`** header against [[watch_devices]] (RLS-locked, service-role bypass inside the function).
- Token is set on the watch via Connect IQ app-setting **`pairingToken`**, baked as default in `resources/settings/properties.xml`. Real users overwrite via Connect IQ Mobile after pairing through [[PairWatchScreen|the phone app's Pair Watch flow]]. The fallback in code is `""` — unpaired = fail-closed with "Pair watch" message.

## File layout (`trailtether_watch/`)

| File | Role |
|---|---|
| `manifest.xml` | Connect IQ manifest; minApiLevel 3.2.0; permissions Positioning / Fit / Communications |
| `monkey.jungle` | Build config |
| `source/TrailtetherWatchApp.mc` | App entry; wires recorder, view, delegate, RouteService |
| `source/HikeRecorder.mc` | State machine + GPS recording + activity mapping + `_points` cap (4000, in-place halve) |
| `source/HikeView.mc` | All drawing — picker, acquire, live pages, map, paused, summary, sync |
| `source/HikeDelegate.mc` | Button routing (START / BACK / UP / DOWN / MENU) |
| `source/RouteCourse.mc` | Route data model (`dist[]`, `elev[]`, `lat[]`, `lon[]`) + off-route math |
| `source/RouteService.mc` | HTTP fetch (`fetch`, `fetchList`, `fetchById`) with callback-stomp defence |
| `source/SyncService.mc` | Upload to [[watch-ingest]]; fail-closed if `deviceToken()` empty |
| `resources/drawables/` | 28 px, 56 px, 128 px Trailtether logo bitmaps |
| `resources/settings/` | `properties.xml` (default token) + `settings.xml` (Garmin Connect Mobile UI) |
| `bin/trailtether_watch.prg` | Release artefact (71 KB) |

## State machine

```
STATE_PICKING          ← launch state (Hike / Trail Run / Walk / Climb)
   │ START → commitActivity
STATE_ROUTE_PICKING    ← fetchList from [[watch-route]] (None + saved trails)
   │ START → commitRoute (fetchById if real route, clear() if None)
STATE_IDLE             ← brief; auto-→ acquire
STATE_ACQUIRING        ← GPS sweep wedge; auto-→ recording on QUALITY_GOOD
   │ BACK → discard → STATE_PICKING
STATE_RECORDING        ← Timer / Elevation / HR / Map / (Route Profile)
   │ START → pause
STATE_PAUSED           ← RESUME / SAVE / DISCARD pills
   │ SAVE → state = SUMMARY (and ActivityRecording.save)
   │ DISCARD → state = PICKING (and ActivityRecording.discard)
STATE_SUMMARY          ← effort dial + 6-cell grid + SYNC chip
   │ START → state = SYNCING + sync.upload()
STATE_SYNCING          ← dedicated screen (packets + bar)
   │ callback → state = SUMMARY with ✓SYNCED / FAILED chip
```

## Hardening (security + reliability pass 2026-05-30)

- `DEFAULT_TOKEN` fallback removed from source — unpaired = fail-closed.
- `_points` capped at 4000 with in-place halving to prevent OOM on multi-hour hikes.
- `RouteCourse.hasGeo()` rejects `(0,0)` to stop spurious OFF ROUTE pills.
- `syncProgress` reset to 0 before retry seed.
- `RouteService` callbacks snapshot-and-clear before invoke; late responses no longer overwrite the loaded course.
- Async callbacks (`onRouteList`, `onRouteLoaded`, `onSyncDone`) state-guarded against late firing in the wrong state.
- `_elev` in-place left-shift instead of `slice()` — eliminates ~3600 allocs / session.
- `getMapPoints()` memoized — drops ~600 dict allocs/sec at the Map page.
- `onMenu` swallowed during `STATE_SYNCING` — no route fetch racing the upload.
- `commitSelectedRoute` blocks double-press while a `fetchById` is in flight.
- [[watch-ingest]] caps `points[]` at 10 000 — Storage-bucket DoS defence.

## Build + sideload

```pwsh
$SDK = "$env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b"
$KEY = "$env:APPDATA\Garmin\ConnectIQ\developer_key.der"
& "$SDK\bin\monkeyc.bat" -f trailtether_watch\monkey.jungle `
    -o trailtether_watch\bin\trailtether_watch.prg -y $KEY `
    -d instinct3amoled45mm -r       # -r strips debug info
```

Sideload: Instinct 3 mounts as MTP (no drive letter) — copy `trailtether_watch/bin/trailtether_watch.prg` to **Internal Storage\GARMIN\Apps** via Explorer or `Shell.Application` COM.

## Publish-time checklist

⚠️ Before submitting to the Connect IQ Store, clear the default in `trailtether_watch/resources/settings/properties.xml`:

```xml
<property id="pairingToken" type="string"></property>
```

Otherwise unpaired production installs write to whichever account the dev token is bound to.

## Design source

Claude Design handoff at `.design_handoff_watch/trailtether/project/watch.html` (+ `watch/*.jsx`). Palette: ember `#ff6a2c` / `#ff8a4d`, bg `#07090c`, amber `#f2a93b` (replaces brand green per user pref), JetBrains Mono numerals. 11-screen UX defined; Watch Face (screen 01) is out of scope (different `type="watchface"` app type); satellite Map (07) substituted with the Route Profile + the live-track Map page.

## Sim testing

- Boot sim: `connectiq.bat`. Load: `monkeydo bin/trailtether_watch.prg instinct3amoled45mm`.
- Phone bridge: `adb forward tcp:7381 tcp:7381` to the user's Galaxy S24 with Garmin Connect Mobile + Connect IQ Mobile running.
- Default token in properties.xml means the sim works without a separate Settings Editor step.

## Related

- [[watch-route]] — route list + by-id course fetch
- [[watch-ingest]] — hike upload (POST writes hike_history + recorded_trails + GPX)
- [[mint_watch_token]] — phone-app RPC that the watch's token comes from
- [[set_watch_active_route]] — phone-app RPC to push a chosen route to the watch
- [[watch_devices]] — token → user_id mapping table
- [[PairWatchScreen]] — phone app UI (Profile → Pair Garmin Watch)
