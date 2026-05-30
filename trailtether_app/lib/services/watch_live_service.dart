import 'package:flutter/services.dart';

/// Receives live hike data streamed from the Garmin watch app over the Connect
/// IQ Mobile SDK (an Android native plugin).
///
/// The native side needs Garmin's Connect IQ **Mobile** SDK (`.aar`) wired in
/// — see `trailtether_watch/HANDOFF_live_link.md`. Until then these channels
/// have no native handler, so [stream] simply never emits and [start]/[stop]
/// are silent no-ops. The watch app already transmits the matching protocol
/// (`HikeRecorder.transmitLive`).
class WatchLiveService {
  static const _events = EventChannel('trailtether/watch_live/events');
  static const _methods = MethodChannel('trailtether/watch_live');

  /// Decoded live messages from the watch — `{t:'live', hr, ahr, dur, dist,
  /// spd, alt, asc, cal, act, lat?, lon?}`.
  static Stream<Map<String, dynamic>> stream() =>
      _events.receiveBroadcastStream().map(
            (e) =>
                (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{},
          );

  /// Ask the native plugin to start listening for the paired device's app.
  static Future<void> start() async {
    try {
      await _methods.invokeMethod('start');
    } on MissingPluginException {
      // Native plugin not present yet (no SDK) — no-op.
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _methods.invokeMethod('stop');
    } on MissingPluginException {
      // ignore
    } catch (_) {}
  }
}
