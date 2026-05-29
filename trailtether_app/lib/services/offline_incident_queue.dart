// Persistent local FIFO queue for off-trail incident alerts that couldn't be
// pushed to Supabase because the device was offline. Drained whenever
// `connectivity_plus` reports wifi/mobile back.
//
// SharedPreferences-backed JSON list.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

class OfflineIncidentQueue {
  static const _key = 'offline_incident_queue_v1';
  static const _maxItems =
      100; // Cap to prevent excessive SharedPreferences usage for alerts

  /// Append an incident insert map that failed to publish.
  static Future<void> enqueue(Map<String, dynamic> incident) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? <String>[];
      raw.add(jsonEncode(incident));
      if (raw.length > _maxItems) {
        raw.removeRange(0, raw.length - _maxItems);
      }
      await prefs.setStringList(_key, raw);
      LoggerService.log('OFF_TRAIL',
          'Offline-queued incident alert · queue size ${raw.length}');
    } catch (e, stack) {
      LoggerService.error('OFF_TRAIL', 'Incident enqueue failed: $e', stack);
    }
  }

  /// Pop the entire queue. Clear on read to avoid duplicate uploads.
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
          'OFF_TRAIL', 'Drained ${items.length} offline incidents from queue');
      return items;
    } catch (e, stack) {
      LoggerService.error('OFF_TRAIL', 'Incident drainAll failed: $e', stack);
      return const [];
    }
  }

  /// Re-enqueue on push failure.
  static Future<void> reenqueue(List<Map<String, dynamic>> incidents) async {
    if (incidents.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? <String>[];
      raw.insertAll(0, incidents.map((f) => jsonEncode(f)));
      if (raw.length > _maxItems) {
        raw.removeRange(0, raw.length - _maxItems);
      }
      await prefs.setStringList(_key, raw);
      LoggerService.log('OFF_TRAIL',
          'Re-queued ${incidents.length} offline incidents after drain failure');
    } catch (e, stack) {
      LoggerService.error('OFF_TRAIL', 'Incident reenqueue failed: $e', stack);
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
