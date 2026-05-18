import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recorded_trail.dart';
import '../models/recording_point.dart';
import '../models/saved_hike.dart';
import 'logger_service.dart';

/// Upload/download + metadata operations for `recorded_trails`. Track points
/// live as `.gpx` files in the `recorded-trails` Storage bucket; metadata is
/// in the `recorded_trails` Postgres table. Downloads are cached on disk so
/// trails you've opened once stay viewable offline.
class RecordedTrailService {
  RecordedTrailService._();

  static const _bucket = 'recorded-trails';

  static SupabaseClient get _db => Supabase.instance.client;

  /// Promote a saved hike to a (private by default) recorded trail. Uploads
  /// the GPX bytes to Storage, inserts the metadata row, and returns the
  /// freshly-created trail. Idempotent on `(user_id, hike_id)` — calling
  /// twice updates instead of duplicating.
  static Future<RecordedTrail?> saveFromHike(
    SavedHike hike,
    String userId,
  ) async {
    if (hike.points.length < 2) {
      LoggerService.log('TRAILS',
          'saveFromHike skipped: ${hike.id} has <2 points');
      return null;
    }

    final trailId = hike.id;
    final gpxPath = '$userId/$trailId.gpx';
    final gpxBytes = utf8.encode(_buildGpx(hike));

    try {
      await _db.storage.from(_bucket).uploadBinary(
            gpxPath,
            Uint8List.fromList(gpxBytes),
            fileOptions: const FileOptions(
              contentType: 'application/gpx+xml',
              upsert: true,
            ),
          );

      final bbox = _bbox(hike.points);
      final row = {
        'hike_id': hike.id,
        'user_id': userId,
        'team_id': hike.teamId,
        'name': hike.name,
        'distance_km': hike.distanceKm,
        'ascent_m': hike.ascentM,
        'descent_m': hike.descentM,
        'duration_seconds': hike.durationSeconds,
        'activity_type': hike.activityType,
        'point_count': hike.points.length,
        'min_lat': bbox?.minLat,
        'max_lat': bbox?.maxLat,
        'min_lon': bbox?.minLon,
        'max_lon': bbox?.maxLon,
        'gpx_path': gpxPath,
      };

      final upserted = await _db
          .from('recorded_trails')
          .upsert(row, onConflict: 'user_id,hike_id')
          .select()
          .single();

      LoggerService.log('TRAILS', 'Promoted hike ${hike.id} to trail');
      return RecordedTrail.fromMap(upserted);
    } catch (e, stack) {
      LoggerService.error(
          'TRAILS', 'saveFromHike failed for ${hike.id}: $e', stack);
      return null;
    }
  }

  /// List trails owned by the current user. Newest first.
  static Future<List<RecordedTrail>> listMine(String userId) async {
    try {
      final rows = await _db
          .from('recorded_trails')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => RecordedTrail.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      LoggerService.error('TRAILS', 'listMine failed: $e', stack);
      return const [];
    }
  }

  /// List publicly-shared community trails. Newest first.
  static Future<List<RecordedTrail>> listCommunity({int limit = 50}) async {
    try {
      final rows = await _db
          .from('recorded_trails')
          .select()
          .eq('sharing', 'public')
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => RecordedTrail.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      LoggerService.error('TRAILS', 'listCommunity failed: $e', stack);
      return const [];
    }
  }

  /// Flip sharing state. RLS already ensures only the owner can update.
  static Future<RecordedTrail?> setSharing(
      String trailId, TrailSharing sharing) async {
    try {
      final row = await _db
          .from('recorded_trails')
          .update({'sharing': sharing.key})
          .eq('id', trailId)
          .select()
          .single();
      LoggerService.log('TRAILS', 'Trail $trailId sharing -> ${sharing.key}');
      return RecordedTrail.fromMap(row);
    } catch (e, stack) {
      LoggerService.error('TRAILS', 'setSharing failed: $e', stack);
      return null;
    }
  }

  /// Delete metadata row AND the underlying GPX object. RLS scopes both to
  /// the owner.
  static Future<bool> delete(RecordedTrail trail) async {
    try {
      // Storage first — if the DB row goes but the object remains, we leak
      // bytes. If storage delete fails we abort so the row stays as a
      // pointer to the (still-present) file rather than orphaning it.
      await _db.storage.from(_bucket).remove([trail.gpxPath]);
      await _db.from('recorded_trails').delete().eq('id', trail.id);
      await _localFile(trail.gpxPath).then((f) async {
        if (await f.exists()) await f.delete();
      });
      LoggerService.log('TRAILS', 'Deleted trail ${trail.id}');
      return true;
    } catch (e, stack) {
      LoggerService.error('TRAILS', 'delete failed: $e', stack);
      return false;
    }
  }

  /// Resolve a trail's track points. Prefers the on-disk cache (so previously-
  /// viewed trails work offline), falling back to a network download which is
  /// then written to cache.
  static Future<List<RecordingPoint>> downloadPoints(
      RecordedTrail trail) async {
    final file = await _localFile(trail.gpxPath);
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        return _parseGpx(utf8.decode(bytes));
      } catch (e) {
        LoggerService.log('TRAILS',
            'Cached GPX for ${trail.id} unreadable ($e); re-downloading');
      }
    }

    try {
      final bytes = await _db.storage.from(_bucket).download(trail.gpxPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      // Best-effort: bump download_count. Failures are non-fatal — the user
      // already has the points loaded by the time this fires.
      unawaited(_incrementDownloadCount(trail.id));
      return _parseGpx(utf8.decode(bytes));
    } catch (e, stack) {
      LoggerService.error('TRAILS', 'downloadPoints failed: $e', stack);
      return const [];
    }
  }

  static Future<void> _incrementDownloadCount(String trailId) async {
    try {
      await _db.rpc('increment_recorded_trail_downloads',
          params: {'p_id': trailId});
    } catch (_) {
      // RPC isn't critical — soft-counter. Silently ignore if the function
      // hasn't been created yet (older schemas).
    }
  }

  static Future<File> _localFile(String gpxPath) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/recorded_trails_cache/$gpxPath');
  }

  // ── GPX serialisation ──────────────────────────────────────────────────

  static String _buildGpx(SavedHike hike) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln(
        '<gpx version="1.1" creator="Trailtether" xmlns="http://www.topografix.com/GPX/1/1">');
    buf.writeln('  <trk>');
    buf.writeln('    <name>${_xml(hike.name)}</name>');
    buf.writeln('    <type>${_xml(hike.activityType)}</type>');
    buf.writeln('    <trkseg>');
    for (final p in hike.points) {
      buf.write('      <trkpt lat="${p.latitude}" lon="${p.longitude}">');
      buf.write('<ele>${p.altitude.toStringAsFixed(2)}</ele>');
      buf.write('<time>${p.timestamp.toUtc().toIso8601String()}</time>');
      buf.writeln('</trkpt>');
    }
    buf.writeln('    </trkseg>');
    buf.writeln('  </trk>');
    buf.writeln('</gpx>');
    return buf.toString();
  }

  static List<RecordingPoint> _parseGpx(String gpx) {
    final points = <RecordingPoint>[];
    // Lightweight regex parse — GPX recorded by saveFromHike is tightly
    // controlled, so we don't need a full XML parser dependency here.
    final trkptRe = RegExp(
        r'<trkpt\s+lat="([-\d\.]+)"\s+lon="([-\d\.]+)">\s*'
        r'(?:<ele>([-\d\.]+)</ele>)?\s*'
        r'(?:<time>([^<]+)</time>)?',
        multiLine: true);
    for (final m in trkptRe.allMatches(gpx)) {
      final lat = double.tryParse(m.group(1) ?? '');
      final lon = double.tryParse(m.group(2) ?? '');
      if (lat == null || lon == null) continue;
      final ele = double.tryParse(m.group(3) ?? '') ?? 0;
      final ts = DateTime.tryParse(m.group(4) ?? '') ?? DateTime.now();
      points.add(RecordingPoint(
        latitude: lat,
        longitude: lon,
        altitude: ele,
        timestamp: ts,
      ));
    }
    return points;
  }

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static _Bbox? _bbox(List<RecordingPoint> points) {
    if (points.isEmpty) return null;
    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLon = points.first.longitude;
    var maxLon = minLon;
    for (final p in points.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    return _Bbox(minLat, maxLat, minLon, maxLon);
  }
}

class _Bbox {
  final double minLat, maxLat, minLon, maxLon;
  const _Bbox(this.minLat, this.maxLat, this.minLon, this.maxLon);
}
