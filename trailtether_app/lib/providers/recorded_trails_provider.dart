import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recorded_trail.dart';
import '../models/saved_hike.dart';
import '../services/logger_service.dart';
import '../services/recorded_trail_service.dart';

/// Offline-aware view of recorded trails. Maintains two lists — the
/// current user's trails (always reads from the local cache first, then
/// refreshes from network) and the latest snapshot of community-shared
/// trails. Both lists persist to SharedPreferences so opening the app
/// without signal still shows something useful.
class RecordedTrailsProvider extends ChangeNotifier {
  static const _kPrefMine = 'recorded_trails_mine_v1';
  static const _kPrefCommunity = 'recorded_trails_community_v1';

  final List<RecordedTrail> _mine = [];
  final List<RecordedTrail> _community = [];

  bool _loaded = false;
  bool _refreshing = false;
  String? _lastError;

  List<RecordedTrail> get mine => List.unmodifiable(_mine);
  List<RecordedTrail> get community => List.unmodifiable(_community);
  bool get loaded => _loaded;
  bool get refreshing => _refreshing;
  String? get lastError => _lastError;

  RecordedTrailsProvider() {
    _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    _mine
      ..clear()
      ..addAll(_decode(prefs.getString(_kPrefMine)));
    _community
      ..clear()
      ..addAll(_decode(prefs.getString(_kPrefCommunity)));
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefMine,
        jsonEncode(_mine.map((t) => t.toJson()).toList()));
    await prefs.setString(_kPrefCommunity,
        jsonEncode(_community.map((t) => t.toJson()).toList()));
  }

  List<RecordedTrail> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((m) => RecordedTrail.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      LoggerService.log('TRAILS', 'cache decode failed: $e');
      return const [];
    }
  }

  /// Pull fresh state from Supabase. Safe to call without network — failures
  /// keep the existing cached list so the UI doesn't go blank.
  Future<void> refresh(String userId) async {
    if (_refreshing) return;
    _refreshing = true;
    _lastError = null;
    notifyListeners();
    try {
      final mine = await RecordedTrailService.listMine(userId);
      final community = await RecordedTrailService.listCommunity();
      _mine
        ..clear()
        ..addAll(mine);
      _community
        ..clear()
        ..addAll(community);
      await _persist();
    } catch (e, stack) {
      _lastError = e.toString();
      LoggerService.error('TRAILS', 'refresh failed: $e', stack);
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Upload + record a hike as a private trail. Called from
  /// `HikeHistoryProvider.add` so saving a hike automatically populates
  /// the Trails section.
  Future<void> promoteFromHike(SavedHike hike, String userId) async {
    final created =
        await RecordedTrailService.saveFromHike(hike, userId);
    if (created == null) return;
    _mine.removeWhere((t) => t.hikeId == hike.id);
    _mine.insert(0, created);
    await _persist();
    notifyListeners();
  }

  Future<void> share(String trailId, TrailSharing level) async {
    final updated =
        await RecordedTrailService.setSharing(trailId, level);
    if (updated == null) return;
    _replace(updated);
    notifyListeners();
  }

  Future<bool> delete(RecordedTrail trail) async {
    final ok = await RecordedTrailService.delete(trail);
    if (!ok) return false;
    _mine.removeWhere((t) => t.id == trail.id);
    _community.removeWhere((t) => t.id == trail.id);
    await _persist();
    notifyListeners();
    return true;
  }

  void _replace(RecordedTrail t) {
    final i = _mine.indexWhere((x) => x.id == t.id);
    if (i >= 0) _mine[i] = t;
    final j = _community.indexWhere((x) => x.id == t.id);
    if (j >= 0) _community[j] = t;
    unawaited(_persist());
  }
}
