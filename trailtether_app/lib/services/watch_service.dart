import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger_service.dart';

/// Garmin watch companion: pairing + route hand-off.
///
/// - [mintToken] issues a device token bound to the current user (the user
///   pastes it into the watch app's Garmin Connect settings).
/// - [setActiveRoute] picks which recorded trail the paired watch pulls into
///   its Route Profile (the watch fetches it from the `watch-route` function).
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
}
