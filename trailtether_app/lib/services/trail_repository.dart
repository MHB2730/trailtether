// Curated-trails repository — owns the Supabase round-trip + on-disk
// cache for the catalogue that mobile + PC read from. Mirrors the older
// bundled assets/data/routes_cleaned.json shape so Trail.fromJson can
// keep working unchanged.
//
// Reads:
//   fetchAll()   → Supabase (RLS gates unpublished rows to admins) +
//                  refreshes the local cache
//   loadCache()  → SharedPreferences snapshot for offline / first-paint
//
// Writes (admin-only via RLS):
//   upsertFromBundleJson()  bulk seed from the bundled JSON
//   updateMeta()            edit name/difficulty/category/description/published
//   delete()                hard-delete a row
//
// The PC Trails section is the only caller for the write methods; mobile
// stays read-only. RLS does the actual enforcement — these methods just
// surface the result back to the UI.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger_service.dart';

class TrailRepository {
  TrailRepository._();

  static const _kCacheKey = 'trails_supabase_cache_v1';
  static const _kBundlePath = 'assets/data/routes_cleaned.json';

  static SupabaseClient get _db => Supabase.instance.client;

  // ── Reads ──────────────────────────────────────────────────────────────

  /// Fetch all visible trails from Supabase. Returns rows in the same
  /// shape TrailService.fromJson expects (camelCase, coords as
  /// `[[lon, lat, ele], ...]`). Refreshes the local cache on success.
  ///
  /// Throws on network/RLS failure — callers should catch and fall back
  /// to [loadCache] or [loadBundleAsRows].
  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _db
        .from('trails')
        .select(
          'id,name,description,difficulty,category,distance_km,'
          'elevation_gain_m,elevation_descent_m,est_time_hours,'
          'min_ele,max_ele,coords,min_lat,max_lat,min_lon,max_lon,'
          'published,updated_at',
        )
        .order('name');
    final list = (rows as List)
        .map((r) => _rowToBundleShape(r as Map<String, dynamic>))
        .toList();
    LoggerService.log('TRAILS_REPO', 'Fetched ${list.length} trails');
    unawaited(saveCache(list));
    return list;
  }

  /// Read whatever was cached on disk after the last successful fetch.
  /// Empty list if there's nothing yet.
  static Future<List<Map<String, dynamic>>> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e, stack) {
      LoggerService.error('TRAILS_REPO', 'cache decode failed: $e', stack);
      return const [];
    }
  }

  static Future<void> saveCache(List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(rows));
    } catch (e) {
      LoggerService.log('TRAILS_REPO', 'cache save failed: $e');
    }
  }

  /// Last-resort source for the catalogue: the JSON that ships with the
  /// app. Used on first launch before the Supabase fetch completes, or
  /// when the device is offline and the cache is empty.
  static Future<List<Map<String, dynamic>>> loadBundleAsRows() async {
    final raw = await rootBundle.loadString(_kBundlePath);
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ── Writes (admin only — RLS enforces) ─────────────────────────────────

  /// Update editable metadata. Pass only the fields the admin changed —
  /// nulls are skipped, so this is safe to call with a partial change set
  /// (e.g. just renaming).
  static Future<bool> updateMeta({
    required String id,
    String? name,
    String? description,
    String? difficulty,
    String? category,
    int? elevationGainM,
    bool? published,
  }) async {
    try {
      final patch = <String, dynamic>{};
      if (name != null) patch['name'] = name;
      if (description != null) patch['description'] = description;
      if (difficulty != null) patch['difficulty'] = difficulty;
      if (category != null) patch['category'] = category;
      if (elevationGainM != null) patch['elevation_gain_m'] = elevationGainM;
      if (published != null) patch['published'] = published;
      if (patch.isEmpty) return true;

      await _db.from('trails').update(patch).eq('id', id);
      LoggerService.log('TRAILS_REPO', 'Updated $id (${patch.keys.join(",")})');
      return true;
    } catch (e, stack) {
      LoggerService.error('TRAILS_REPO', 'updateMeta($id) failed: $e', stack);
      return false;
    }
  }

  /// Hard-delete. RLS already scopes to admin.
  static Future<bool> delete(String id) async {
    try {
      await _db.from('trails').delete().eq('id', id);
      LoggerService.log('TRAILS_REPO', 'Deleted $id');
      return true;
    } catch (e, stack) {
      LoggerService.error('TRAILS_REPO', 'delete($id) failed: $e', stack);
      return false;
    }
  }

  /// Insert (or replace) a single trail. Used by the "Add trail" GPX
  /// upload flow on PC. `bundleRow` is the same shape that
  /// `routes_cleaned.json` uses — id, name, coords, etc.
  static Future<bool> upsertOne(Map<String, dynamic> bundleRow) async {
    try {
      final payload = _bundleShapeToRow(bundleRow);
      await _db
          .from('trails')
          .upsert(payload, onConflict: 'id')
          .select()
          .single();
      LoggerService.log(
          'TRAILS_REPO', 'Upserted ${payload['id']} (${payload['name']})');
      return true;
    } catch (e, stack) {
      LoggerService.error('TRAILS_REPO', 'upsertOne failed: $e', stack);
      return false;
    }
  }

  /// One-shot bulk seed from the bundled JSON. Inserts one row at a time
  /// (rather than a single huge batch) so a single failure doesn't
  /// take the whole catalogue down. Idempotent via `on_conflict id`.
  ///
  /// Returns (inserted, skipped) counts. Inserted = newly created or
  /// replaced rows; skipped = rows that failed (logged).
  static Future<({int inserted, int skipped})> seedFromBundle({
    void Function(int done, int total)? onProgress,
  }) async {
    final rows = await loadBundleAsRows();
    var ok = 0;
    var fail = 0;
    for (var i = 0; i < rows.length; i++) {
      final success = await upsertOne(rows[i]);
      if (success) {
        ok++;
      } else {
        fail++;
      }
      onProgress?.call(i + 1, rows.length);
    }
    LoggerService.log(
        'TRAILS_REPO', 'Seed complete: inserted=$ok skipped=$fail');
    return (inserted: ok, skipped: fail);
  }

  // ── Shape conversion ───────────────────────────────────────────────────

  /// Supabase row → bundled-JSON shape that Trail.fromJson already groks.
  /// The bundled file uses camelCase; the table uses snake_case.
  static Map<String, dynamic> _rowToBundleShape(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'description': row['description'] ?? '',
      'difficulty': row['difficulty'] ?? 'Moderate',
      'category': row['category'] ?? 'hike',
      'distanceKm': row['distance_km'] ?? 0,
      'elevationGainM': row['elevation_gain_m'] ?? 0,
      'elevationLossM': row['elevation_descent_m'] ?? 0,
      'estTimeHours': row['est_time_hours'] ?? 0,
      'minEle': row['min_ele'] ?? 0,
      'maxEle': row['max_ele'] ?? 0,
      'coords': row['coords'] ?? const [],
      'published': row['published'] ?? true,
    };
  }

  /// Bundled-JSON shape → row payload ready for upsert. Computes the
  /// bbox columns from coords so the index can do viewport queries.
  static Map<String, dynamic> _bundleShapeToRow(Map<String, dynamic> b) {
    final coords = (b['coords'] is List)
        ? b['coords'] as List<dynamic>
        : const <dynamic>[];

    double? minLat, maxLat, minLon, maxLon;
    for (final c in coords) {
      if (c is! List || c.length < 2) continue;
      final lon = (c[0] as num?)?.toDouble();
      final lat = (c[1] as num?)?.toDouble();
      if (lon == null || lat == null) continue;
      minLat = minLat == null ? lat : (lat < minLat ? lat : minLat);
      maxLat = maxLat == null ? lat : (lat > maxLat ? lat : maxLat);
      minLon = minLon == null ? lon : (lon < minLon ? lon : minLon);
      maxLon = maxLon == null ? lon : (lon > maxLon ? lon : maxLon);
    }

    final rawName = (b['name'] ?? '').toString();
    // Derive a sensible default category if the bundle row doesn't carry
    // one — admins can override later via updateMeta.
    final category = (b['category'] as String?) ??
        (rawName.toLowerCase().contains('cave') ? 'cave' : 'hike');

    return {
      'id': b['id'],
      'name': rawName,
      'description': b['description'] ?? '',
      'difficulty': _normalizeDifficulty(b['difficulty']),
      'category': category,
      'distance_km': b['distanceKm'] ?? 0,
      'elevation_gain_m': b['elevationGainM'] ?? 0,
      'elevation_descent_m': b['elevationLossM'] ?? b['elevationDescentM'] ?? 0,
      'est_time_hours': b['estTimeHours'] ?? 0,
      'min_ele': b['minEle'] ?? 0,
      'max_ele': b['maxEle'] ?? 0,
      'coords': coords,
      'min_lat': minLat,
      'max_lat': maxLat,
      'min_lon': minLon,
      'max_lon': maxLon,
      'published': b['published'] ?? true,
    };
  }

  /// The bundle has a few raw values that don't match our table check
  /// constraint (e.g. 'Hard' vs 'Challenging'). Map to a known set.
  static String _normalizeDifficulty(dynamic raw) {
    final s = (raw ?? 'Moderate').toString();
    const allowed = {'Easy', 'Moderate', 'Challenging', 'Hard', 'Extreme'};
    if (allowed.contains(s)) return s;
    // Common synonyms / casings.
    switch (s.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'moderate':
        return 'Moderate';
      case 'challenging':
        return 'Challenging';
      case 'hard':
        return 'Hard';
      case 'extreme':
      case 'expert':
        return 'Extreme';
      default:
        return 'Moderate';
    }
  }
}
