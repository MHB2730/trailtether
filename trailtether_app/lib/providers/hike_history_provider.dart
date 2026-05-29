import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_hike.dart';
import '../services/logger_service.dart';
import '../services/recorded_trail_service.dart';

/// Outcome of HikeHistoryProvider.add() — the UI uses this to decide
/// whether to show a green success toast, an amber "saved locally, will
/// sync later" toast, or a red error toast. Each step is independent so
/// a partial success (local OK + trail upload failed) still surfaces
/// what actually happened to the user.
class HikeSaveResult {
  final bool localSaved; // wrote to SharedPreferences
  final bool supabaseSynced; // hike_history upsert succeeded
  final bool trailUploaded; // recorded_trails + GPX file landed
  final String? error; // human-readable last error, if any
  final bool offlineOnly; // userId was null (not signed in)
  const HikeSaveResult({
    required this.localSaved,
    required this.supabaseSynced,
    required this.trailUploaded,
    this.error,
    this.offlineOnly = false,
  });
  bool get isFullSuccess => localSaved && supabaseSynced && trailUploaded;
}

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

  /// Persist the hike locally and (if signed in) sync to Supabase + upload
  /// the GPX. Returns a HikeSaveResult so the UI can show meaningful
  /// feedback per step. Local save errors are caught and turned into a
  /// failed HikeSaveResult; remote sync errors propagate as `error` text.
  Future<HikeSaveResult> add(SavedHike hike, {String? userId}) async {
    bool localSaved = false;
    bool supabaseSynced = false;
    bool trailUploaded = false;
    String? lastError;

    try {
      _hikes.removeWhere((h) => h.id == hike.id);
      _hikes.insert(0, hike);
      await _save();
      localSaved = true;
    } catch (e, stack) {
      LoggerService.error(
          'HISTORY', 'local save failed for ${hike.id}: $e', stack);
      lastError = 'Could not save locally: $e';
      notifyListeners();
      return HikeSaveResult(
        localSaved: false,
        supabaseSynced: false,
        trailUploaded: false,
        error: lastError,
      );
    }

    if (userId == null) {
      // Not signed in — local save only. The janitor edge function will
      // still pick up any orphaned team_member_track_points on its hourly
      // run, but the user-facing message should make clear that nothing
      // synced from this device this time.
      notifyListeners();
      return const HikeSaveResult(
        localSaved: true,
        supabaseSynced: false,
        trailUploaded: false,
        offlineOnly: true,
      );
    }

    try {
      await syncToSupabase(hike, userId);
      supabaseSynced = true;
    } catch (e, stack) {
      LoggerService.error(
          'SYNC', 'hike_history sync failed for ${hike.id}: $e', stack);
      lastError = 'hike_history sync failed: $e';
    }

    try {
      // Promote the hike to a (private) recorded trail so it appears in the
      // Trails section with an elevation profile, ready to be shared to the
      // community via the share button on the detail screen.
      final trail = await RecordedTrailService.saveFromHike(hike, userId);
      trailUploaded = (trail != null);
      if (!trailUploaded) {
        lastError ??=
            'recorded_trails save returned null (likely DB validation)';
      }
    } catch (e, stack) {
      LoggerService.error('TRAILS', 'promoteFromHike failed: $e', stack);
      lastError = 'recorded_trails upload failed: $e';
    }

    notifyListeners();
    return HikeSaveResult(
      localSaved: localSaved,
      supabaseSynced: supabaseSynced,
      trailUploaded: trailUploaded,
      error: lastError,
    );
  }

  /// Now throws on failure (instead of swallowing) so add() can capture it
  /// in HikeSaveResult.error and the UI can show a real error toast.
  Future<void> syncToSupabase(SavedHike hike, String userId) async {
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

    // The matching community feed row is created server-side by the
    // `on_hike_saved` AFTER INSERT trigger on hike_history. We deliberately
    // do NOT post it from the client too: that produced duplicate feed
    // entries on a fresh save, plus an extra duplicate on every re-save
    // (the trigger only fires on INSERT, but a client post would run on
    // every upsert).
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
