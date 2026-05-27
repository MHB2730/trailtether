import 'package:flutter/foundation.dart';
import '../models/trail.dart';
import '../models/cave_waypoint.dart';
import '../models/accommodation.dart';
import '../services/trail_service.dart';
import '../services/cave_waypoint_service.dart';
import '../services/accommodation_service.dart';
import '../services/logger_service.dart';

/// Central provider for local assets that don't change often (Trails, Caves).
/// Consolidates TrailProvider and CaveWaypointProvider to reduce listener overhead.
class StaticDataProvider extends ChangeNotifier {
  List<Trail> _allTrails = [];
  List<Trail> _filteredTrails = [];
  List<CaveWaypoint> _caves = [];
  List<Accommodation> _accommodations = [];

  Trail? _selectedTrail;
  TrailCoord? _profileCursor;
  String _query = '';
  String _difficulty = 'All';
  bool _loading = true;

  List<Trail> get trails => _filteredTrails;
  List<Trail> get allTrails => _allTrails;
  List<CaveWaypoint> get caves => _caves;
  List<Accommodation> get accommodations => _accommodations;
  Trail? get selectedTrail => _selectedTrail;
  TrailCoord? get profileCursor => _profileCursor;
  String get query => _query;
  String get difficulty => _difficulty;
  bool get loading => _loading;

  StaticDataProvider() {
    load();
  }

  Future<void> load() async {
    try {
      _loading = true;
      _allTrails = [];
      _filteredTrails = [];
      _caves = [];
      _accommodations = [];
      notifyListeners();

      // 1. Immediate sync load for accommodations
      _accommodations = AccommodationService.loadAccommodations();
      LoggerService.log(
          'STATIC_DATA', 'Loaded ${_accommodations.length} accommodations');

      // 2. Parallel async loads with individual error handling
      await Future.wait([
        TrailService.loadTrails().then((list) {
          _allTrails = list;
          _filteredTrails = List.of(_allTrails);
          LoggerService.log(
              'STATIC_DATA', 'Loaded ${_allTrails.length} trails');
        }).catchError((e) {
          LoggerService.error('STATIC_DATA', 'Trail load failed: $e');
        }),
        CaveWaypointService.loadCaves().then((list) {
          _caves = list;
          LoggerService.log('STATIC_DATA', 'Loaded ${_caves.length} caves');
        }).catchError((e) {
          LoggerService.error('STATIC_DATA', 'Cave load failed: $e');
        }),
      ]);
    } catch (e) {
      LoggerService.error('STATIC_DATA', 'Global load failure: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Force a fresh fetch from Supabase. Called by the PC Trails admin
  /// section after edit / add / delete / seed so the change is reflected
  /// across the rest of the app (map, list, search) without a restart.
  Future<void> refreshTrails() async {
    TrailService.invalidateCache();
    try {
      final list = await TrailService.loadTrails(forceRefresh: true);
      _allTrails = list;
      _filteredTrails = TrailService.filter(
        _allTrails,
        query: _query,
        difficulty: _difficulty == 'All' ? null : _difficulty,
      );
      LoggerService.log(
          'STATIC_DATA', 'Refreshed ${_allTrails.length} trails');
    } catch (e) {
      LoggerService.error('STATIC_DATA', 'refreshTrails failed: $e');
    }
    notifyListeners();
  }

  void selectTrail(Trail? trail) {
    _selectedTrail = trail;
    _profileCursor = null;
    notifyListeners();
  }

  void setProfileCursor(TrailCoord? coord) {
    _profileCursor = coord;
    notifyListeners();
  }

  void clearProfileCursor() {
    _profileCursor = null;
    notifyListeners();
  }

  void setFilter(String q, String d) {
    _query = q;
    _difficulty = d;
    _filteredTrails = TrailService.filter(
      _allTrails,
      query: _query,
      difficulty: _difficulty == 'All' ? null : _difficulty,
    );
    notifyListeners();
  }

  static const difficulties = ['All', 'Easy', 'Moderate', 'Hard', 'Extreme'];
}
