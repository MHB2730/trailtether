import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger_service.dart';

/// Garmin watch companion: pairing + route hand-off + status.
///
/// - [mintToken] issues a device token bound to the current user (the user
///   pastes it into the watch app's Garmin Connect settings).
/// - [setActiveRoute] picks which recorded trail the paired watch pulls into
///   its Route Profile (the watch fetches it from the `watch-route` function).
/// - [listDevices] returns every paired watch with its last-seen timestamp +
///   active route, for the Profile status widget.
class WatchService {
  WatchService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<String?> mintToken({String label = 'Garmin Watch'}) async {
    try {
      final token =
          await _db.rpc('mint_watch_token', params: {'p_label': label});
      return token as String?;
    } catch (e, stack) {
      LoggerService.error('WATCH', 'mintToken failed: $e', stack);
      return null;
    }
  }

  static Future<bool> setActiveRoute(String routeId) async {
    try {
      await _db.rpc('set_watch_active_route', params: {'p_route_id': routeId});
      return true;
    } catch (e, stack) {
      LoggerService.error('WATCH', 'setActiveRoute failed: $e', stack);
      return false;
    }
  }

  static Future<List<WatchDeviceInfo>> listDevices() async {
    try {
      final raw = await _db.rpc('list_watch_devices');
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(WatchDeviceInfo.fromJson)
          .toList(growable: false);
    } catch (e, stack) {
      LoggerService.error('WATCH', 'listDevices failed: $e', stack);
      return const [];
    }
  }
}

/// One paired watch as returned by `list_watch_devices`. `lastSeenAt` is null
/// until the watch makes its first sync upload.
class WatchDeviceInfo {
  final String deviceToken;
  final String label;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final String? activeRouteId;
  final String? activeRouteName;

  const WatchDeviceInfo({
    required this.deviceToken,
    required this.label,
    required this.createdAt,
    this.lastSeenAt,
    this.activeRouteId,
    this.activeRouteName,
  });

  factory WatchDeviceInfo.fromJson(Map<String, dynamic> j) => WatchDeviceInfo(
        deviceToken: (j['device_token'] ?? '') as String,
        label: (j['label'] ?? 'Garmin Watch') as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        lastSeenAt: j['last_seen_at'] == null
            ? null
            : DateTime.parse(j['last_seen_at'] as String),
        activeRouteId: j['active_route_id'] as String?,
        activeRouteName: j['active_route_name'] as String?,
      );
}
