import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/trail.dart';

class TrailService {
  static List<Trail>? _cache;

  static Future<List<Trail>> loadTrails() async {
    if (_cache != null) return _cache!;
    try {
      final raw =
          await rootBundle.loadString('assets/data/routes_cleaned.json');
      final list = json.decode(raw) as List<dynamic>;

      final loadedTrails = <Trail>[];
      for (final e in list) {
        try {
          loadedTrails.add(Trail.fromJson(e as Map<String, dynamic>));
        } catch (err) {
          debugPrint(
              'Error parsing trail: ${e['name'] ?? 'unknown'}. Error: $err');
          // Skip corrupt trails instead of failing entirely
        }
      }

      _cache = loadedTrails;
      // Sort alphabetically
      _cache!.sort((a, b) => a.name.compareTo(b.name));
      return _cache!;
    } catch (e) {
      debugPrint('Global trail load failed: $e');
      rethrow;
    }
  }

  static List<Trail> filter(
    List<Trail> all, {
    String query = '',
    String? difficulty,
  }) {
    return all.where((t) {
      final matchesQuery =
          query.isEmpty || t.name.toLowerCase().contains(query.toLowerCase());
      final matchesDiff = difficulty == null ||
          difficulty == 'All' ||
          t.difficulty == difficulty;
      return matchesQuery && matchesDiff;
    }).toList();
  }
}
