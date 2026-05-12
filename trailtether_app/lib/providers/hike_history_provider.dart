import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_hike.dart';
import '../services/logger_service.dart';

class HikeHistoryProvider extends ChangeNotifier {
  static const _prefKey = 'saved_hikes_v1';
  final List<SavedHike> _hikes = [];
  bool _loaded = false;

  List<SavedHike> get hikes => List.unmodifiable(_hikes);
  bool get loaded => _loaded;

  HikeHistoryProvider() {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    _hikes
      ..clear()
      ..addAll(raw == null ? <SavedHike>[] : SavedHike.decodeList(raw));
    _hikes.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(SavedHike hike, {String? userId}) async {
    _hikes.removeWhere((h) => h.id == hike.id);
    _hikes.insert(0, hike);
    await _save();

    if (userId != null) {
      await syncToSupabase(hike, userId);
    }

    notifyListeners();
  }

  Future<void> syncToSupabase(SavedHike hike, String userId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('hike_history').upsert({
        'user_id': userId,
        'team_id': hike.teamId,
        'trail_id': hike.benchmarkRouteId,
        'name': hike.name,
        'distance_km': hike.distanceKm,
        'ascent_m': hike.ascentM,
        'peaks_climbed': hike.peaksClimbed,
        'duration_seconds': hike.durationSeconds,
        'activity_type': hike.activityType,
        'activity_context': hike.activityContext,
        'avg_accuracy_m': hike.averageAccuracyM,
        'best_accuracy_m': hike.bestAccuracyM,
        'worst_accuracy_m': hike.worstAccuracyM,
        'accepted_fixes': hike.acceptedFixes,
        'rejected_fixes': hike.rejectedFixes,
        'points': hike.points.map((p) => p.toJson()).toList(),
        'created_at': hike.startedAt.toIso8601String(),
      });
      LoggerService.log('SYNC', 'Hike synced to Supabase: ${hike.id}');
    } catch (e, stack) {
      LoggerService.error(
          'SYNC', 'Failed to sync hike ${hike.id} to Supabase: $e', stack);
    }
  }

  Future<void> remove(String id) async {
    _hikes.removeWhere((h) => h.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _hikes.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, SavedHike.encodeList(_hikes));
  }
}
