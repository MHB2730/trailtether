import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafetyPlan {
  final String trailId;
  final String trailName;
  final DateTime expectedReturn;
  final String notes;
  final String backpackColor;
  final String tentColor;
  final DateTime createdAt;

  const SafetyPlan({
    required this.trailId,
    required this.trailName,
    required this.expectedReturn,
    required this.notes,
    this.backpackColor = '',
    this.tentColor = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'trailId': trailId,
        'trailName': trailName,
        'expectedReturn': expectedReturn.toIso8601String(),
        'notes': notes,
        'backpackColor': backpackColor,
        'tentColor': tentColor,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SafetyPlan.fromMap(Map<String, dynamic> map) => SafetyPlan(
        trailId: map['trailId'] as String? ?? '',
        trailName: map['trailName'] as String? ?? '',
        expectedReturn: DateTime.tryParse(
              map['expectedReturn'] as String? ?? '',
            ) ??
            DateTime.now(),
        notes: map['notes'] as String? ?? '',
        backpackColor: map['backpackColor'] as String? ?? '',
        tentColor: map['tentColor'] as String? ?? '',
        createdAt: DateTime.tryParse(
              map['createdAt'] as String? ?? '',
            ) ??
            DateTime.now(),
      );
}

class AppStateProvider extends ChangeNotifier {
  static const _favoritesKey = 'app_state.favorite_trails';
  static const _completedKey = 'app_state.completed_trails';
  static const _recentSearchesKey = 'app_state.recent_searches';
  static const _offlineReadyKey = 'app_state.offline_ready';
  static const _safetyPlanKey = 'app_state.safety_plan';
  static const _themeModeKey =
      'app_state.theme_mode'; // 'system'|'dark'|'light'
  static const _showAccommodationKey = 'app_state.show_accommodation';

  Set<String> _favoriteTrailIds = <String>{};
  Set<String> _completedTrailIds = <String>{};
  List<String> _recentSearches = <String>[];
  bool _offlineRegionReady = false;
  SafetyPlan? _activeSafetyPlan;
  bool _loading = true;
  ThemeMode _themeMode = ThemeMode.dark;
  // Accommodation pins are first-class on the map alongside trails and caves,
  // so this defaults to ON. Users can still hide them from the map layers
  // sheet — that flips the SharedPreferences value below.
  bool _showAccommodation = true;

  Set<String> get favoriteTrailIds => _favoriteTrailIds;
  Set<String> get completedTrailIds => _completedTrailIds;
  List<String> get recentSearches => _recentSearches;
  bool get offlineRegionReady => _offlineRegionReady;
  SafetyPlan? get activeSafetyPlan => _activeSafetyPlan;
  bool get loading => _loading;
  ThemeMode get themeMode => _themeMode;
  bool get showAccommodation => _showAccommodation;

  AppStateProvider() {
    _load();
  }

  bool isFavorite(String trailId) => _favoriteTrailIds.contains(trailId);
  bool isCompleted(String trailId) => _completedTrailIds.contains(trailId);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteTrailIds =
        (prefs.getStringList(_favoritesKey) ?? <String>[]).toSet();
    _completedTrailIds =
        (prefs.getStringList(_completedKey) ?? <String>[]).toSet();
    _recentSearches = prefs.getStringList(_recentSearchesKey) ?? <String>[];
    _offlineRegionReady = prefs.getBool(_offlineReadyKey) ?? false;
    final rawTheme = prefs.getString(_themeModeKey) ?? 'dark';
    _themeMode = switch (rawTheme) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    _showAccommodation = prefs.getBool(_showAccommodationKey) ?? true;
    final rawPlan = prefs.getString(_safetyPlanKey);
    if (rawPlan != null && rawPlan.isNotEmpty) {
      try {
        _activeSafetyPlan = SafetyPlan.fromMap(
          json.decode(rawPlan) as Map<String, dynamic>,
        );
      } catch (_) {
        _activeSafetyPlan = null;
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> toggleFavorite(String trailId) async {
    if (_favoriteTrailIds.contains(trailId)) {
      _favoriteTrailIds.remove(trailId);
    } else {
      _favoriteTrailIds.add(trailId);
    }
    notifyListeners();
    await _persistStringSet(_favoritesKey, _favoriteTrailIds);
  }

  Future<void> toggleCompleted(String trailId) async {
    if (_completedTrailIds.contains(trailId)) {
      _completedTrailIds.remove(trailId);
    } else {
      _completedTrailIds.add(trailId);
    }
    notifyListeners();
    await _persistStringSet(_completedKey, _completedTrailIds);
  }

  Future<void> addRecentSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    _recentSearches.removeWhere(
      (existing) => existing.toLowerCase() == query.toLowerCase(),
    );
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 6) {
      _recentSearches = _recentSearches.take(6).toList();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = <String>[];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  Future<void> setOfflineRegionReady(bool value) async {
    _offlineRegionReady = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineReadyKey, value);
  }

  Future<void> setSafetyPlan(SafetyPlan? plan) async {
    _activeSafetyPlan = plan;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (plan == null) {
      await prefs.remove(_safetyPlanKey);
      return;
    }
    await prefs.setString(_safetyPlanKey, json.encode(plan.toMap()));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final key = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    };
    await prefs.setString(_themeModeKey, key);
  }

  Future<void> setShowAccommodation(bool value) async {
    _showAccommodation = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAccommodationKey, value);
  }

  Future<void> _persistStringSet(String key, Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, values.toList()..sort());
  }
}
