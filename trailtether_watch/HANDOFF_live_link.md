# Live watch → phone link (Connect IQ Mobile SDK)

Goal: start a hike **on the watch**, and the phone mirrors it **in real time**
(HR, position, distance, pace…) with **no sensor pairing** — using the device
already paired in Garmin Connect Mobile. Sub-second, no internet required.

```
Watch app (Monkey C)                  Phone app (Flutter)
HikeRecorder.transmitLive()  ──BT──►  Garmin Connect Mobile (bridge)
  Communications.transmit(msg)          │
                                        ▼
                              Connect IQ Mobile SDK (Android .aar)
                                        │  device-app message listener
                                        ▼
                              MainActivity Kotlin plugin
                                        │  EventChannel
                                        ▼
                              WatchLiveService → WatchLiveProvider → WatchLiveScreen
```

## Watch app UUID
`a3f5c8e1b2d4476e9a0c1f3e5d7b8c2a`  (from `manifest.xml`; the phone SDK targets
this app id with `IQApp(...)`.)

## Message protocol (watch transmits ~1 Hz while recording)
`HikeRecorder.transmitLive()` sends this dictionary via `Communications.transmit`:

| key | meaning | type |
|----|---------|------|
| `t` | always `"live"` | String |
| `hr` | current heart rate | Number (bpm) |
| `ahr` | average HR so far | Number |
| `dur` | elapsed seconds | Number |
| `dist` | distance | Number (metres) |
| `spd` | speed | Number (m/s) |
| `alt` | altitude | Number (m) |
| `asc` | ascent | Number (m) |
| `cal` | calories | Number |
| `act` | `hike`/`walk`/`trail_run`/`climb` | String |
| `lat`,`lon` | current position (omitted if no fix) | Number (deg) |

## Status
- ✅ **Watch side** — `HikeRecorder.transmitLive()` + `_LiveTxListener` added
  (`source/HikeRecorder.mc`), called from `tick()`. *Verify it compiles in your
  Connect IQ build (no Monkey C toolchain in CI).*
- ✅ **Flutter side (scaffold)** — `WatchLiveService` (channels), `WatchLiveProvider`,
  `WatchLiveScreen` (reachable from Pair Watch → "Watch live"). Compiles; shows
  the waiting state until the native plugin emits.
- ⏳ **Remaining (needs the SDK):** the Android Kotlin plugin that wraps the
  Connect IQ Mobile SDK and forwards messages to the EventChannel.

## YOU: get the Connect IQ **Mobile** SDK (Android)
This is **not** on any public Maven repo, so it must be added manually.
1. Go to **developer.garmin.com → Connect IQ → SDK / "Mobile SDK"** (sign in with
   your Garmin developer account — the same one used to publish the watch app).
   Download the **Android** Connect IQ Mobile SDK (a `connectiq.aar`).
2. Put it at **`trailtether_app/android/app/libs/connectiq.aar`**.
3. Tell me it's there — I'll add `implementation files('libs/connectiq.aar')` to
   `android/app/build.gradle` and write the plugin.

Requirements on the phone: **Garmin Connect Mobile installed** (the bridge), the
watch paired there, and the Trailtether watch app installed.

## NEXT (me, once the .aar is in): the Android plugin
A Kotlin handler registered in `MainActivity.configureFlutterEngine`, bound to
the existing channels (names must match `WatchLiveService`):
- MethodChannel `trailtether/watch_live` → `start` / `stop`
- EventChannel  `trailtether/watch_live/events` → emits each decoded message Map

Sketch (fills in once the SDK is present):
```kotlin
// import com.garmin.android.connectiq.ConnectIQ
// import com.garmin.android.connectiq.IQApp / IQDevice
// onStart: ConnectIQ.getInstance(ctx, WIRELESS).initialize { ... }
//   getConnectedDevices() -> pick first
//   registerForAppEvents(device, IQApp("a3f5c8e1b2d4476e9a0c1f3e5d7b8c2a")) { _, _, msg, _ ->
//       // msg is a List; first element is the transmitted Dictionary
//       eventSink?.success(msg.firstOrNull())   // -> Flutter as a Map
//   }
```
Then test: open Trailtether on the watch → start a hike → the phone's Watch Live
screen lights up within a second.

## Notes
- The BLE heart-rate path (`HeartRateProvider`) stays as the fallback for
  **phone-recorded** hikes (watch as a strap). This live link is for hikes
  recorded **on the watch**.
- Android-first; iOS would need the iOS Connect IQ Mobile SDK + a parallel plugin.
