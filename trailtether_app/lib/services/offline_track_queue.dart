// Persistent local FIFO queue for GPS fixes that couldn't be pushed to
// Supabase because the device was offline. Drained whenever
// `connectivity_plus` reports wifi/mobile back. Lives entirely on the
// phone — SharedPreferences-backed JSON list — so a kill-and-relaunch
// doesn't lose offline fixes.
//
// Each entry mirrors the row layout of `team_member_track_points`. We
// store the timestamp captured at GPS-fix time (not at insert time) so
// the PC reconstructs the actual route walked, not a smeared timeline.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

class OfflineTrackQueue {
  static const _key = 'offline_track_queue_v1';
  // Soft cap so a multi-day outage can't blow up SharedPreferences. At
  // the default ~5 s cadence this is roughly 5.5 hours of continuous
  // offline recording before we start dropping the oldest entries —
  // long enough for any realistic Drakensberg day-hike where signal
  // returns at the next saddle / hut.
  static const _maxItems = 4000;

  /// Append a fix that we just failed to push live. Trims the head of
  /// the queue if we've crossed the soft cap.
  static Future<void> enqueue(Map<String, dynamic> fix) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? <String>[];
      raw.add(jsonEncode(fix));
      if (raw.length > _maxItems) {
        // Keep the newest _maxItems — dropping ancient history is
        // strictly better than dropping the most recent moves.
        raw.removeRange(0, raw.length - _maxItems);
      }
      await prefs.setStringList(_key, raw);
      LoggerService.log(
          'TRACKING', 'Offline-queued fix · queue size ${raw.length}');
    } catch (e, stack) {
      LoggerService.error('TRACKING', 'enqueue failed: $e', stack);
    }
  }

  /// Pop the entire queue. Caller is responsible for re-enqueueing on
  /// drain failure (the queue is atomically cleared on read to avoid
  /// double-publishes if drain succeeds partway then crashes).
  static Future<List<Map<String, dynamic>>> drainAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? <String>[];
      if (raw.isEmpty) return const [];
      final items = raw
          .map((s) {
            try {
              final v = jsonDecode(s);
              if (v is Map<String, dynamic>) return v;
              return null;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      await prefs.remove(_key);
      LoggerService.log(
          'TRACKING', 'Drained ${items.length} offline fixes from queue');
      return items;
    } catch (e, stack) {
      LoggerService.error('TRACKING', 'drainAll failed: $e', stack);
      return const [];
    }
  }

  /// Push a batch back onto the queue (used when a drain attempt fails
  /// mid-flight and we want to retry later instead of losing fixes).
  static Future<void> reenqueue(List<Map<String, dynamic>> fixes) async {
    if (fixes.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? <String>[];
      raw.insertAll(0, fixes.map((f) => jsonEncode(f)));
      if (raw.length > _maxItems) {
        raw.removeRange(0, raw.length - _maxItems);
      }
      await prefs.setStringList(_key, raw);
      LoggerService.log('TRACKING',
          'Re-queued ${fixes.length} offline fixes after drain failure');
    } catch (e, stack) {
      LoggerService.error('TRACKING', 'reenqueue failed: $e', stack);
    }
  }

  static Future<int> count() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const []).length;
    } catch (_) {
      return 0;
    }
  }
}
