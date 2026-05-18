import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/incident.dart';
import '../core/constants.dart';
import 'logger_service.dart';

SupabaseClient get _db => Supabase.instance.client;

class IncidentService {
  /// Real-time stream of all incidents, newest first.
  /// Malformed rows are dropped (and logged) rather than poisoning the list.
  static Stream<List<Incident>> allIncidents() {
    return _db
        .from(kColIncidents)
        .stream(primaryKey: ['id'])
        .order('reported_at', ascending: false)
        .map((rows) {
          final out = <Incident>[];
          for (final r in rows) {
            final inc = Incident.tryFromMap(r);
            if (inc != null) {
              out.add(inc);
            } else {
              LoggerService.error('INCIDENT_PARSE',
                  'Skipped malformed incident row: id=${r['id']}');
            }
          }
          return out;
        });
  }

  /// Submit a new incident report. Throws on failure so callers can surface
  /// errors to the user — never swallow exceptions for life-safety reports.
  static Future<void> addIncident(Incident incident) async {
    try {
      await _db.from(kColIncidents).insert(incident.toInsertMap());
    } on PostgrestException catch (e, stack) {
      // Schema mismatch (missing column) — fall back to core fields so the
      // report still lands, but log loudly so the deploy gap is visible.
      if (e.code == '42703' || e.code == '400') {
        LoggerService.error(
            'INCIDENT_SCHEMA_MISMATCH',
            'DB schema missing columns for full incident insert (code ${e.code}). '
                'Falling back to core fields — is_emergency may be lost.',
            stack);
        final coreMap = {
          'lat': incident.lat,
          'lon': incident.lon,
          'type': incident.type.key,
          'severity': incident.severity.key,
          'description': incident.description,
          'incident_date': incident.incidentDate.toIso8601String(),
        };
        await _db.from(kColIncidents).insert(coreMap);
      } else {
        rethrow;
      }
    }
  }

  /// Upload an incident photo to the `incident-photos` bucket and return
  /// its public URL. Caller threads the URL through `Incident.photoUrl`
  /// so it lands in the row on insert.
  static Future<String?> uploadPhoto(File file, String userId) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}-${file.uri.pathSegments.last}';
      final bytes = await file.readAsBytes();
      await _db.storage.from('incident-photos').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions:
                FileOptions(contentType: mime, upsert: false),
          );
      final url = _db.storage.from('incident-photos').getPublicUrl(path);
      LoggerService.log('INCIDENT', 'Photo uploaded: $path');
      return url;
    } catch (e, stack) {
      LoggerService.error('INCIDENT', 'uploadPhoto failed: $e', stack);
      return null;
    }
  }

  /// Flag an incident as inaccurate / inappropriate.
  static Future<void> flagIncident(String incidentId) async {
    try {
      await _db.rpc('flag_incident', params: {'p_incident_id': incidentId});
    } catch (e, stack) {
      LoggerService.error('INCIDENT_FLAG', 'flag_incident failed: $e', stack);
    }
  }

  /// Verify an incident as accurate.
  static Future<void> verifyIncident(String incidentId) async {
    try {
      await _db.rpc('verify_incident', params: {
        'p_incident_id': incidentId,
      });
    } catch (e, stack) {
      LoggerService.error('INCIDENT_VERIFY', 'verify_incident failed: $e', stack);
      rethrow;
    }
  }

  /// Permanently delete an incident (owner or admin).
  static Future<void> deleteIncident(String incidentId) async {
    await _db.from(kColIncidents).delete().eq('id', incidentId);
  }
}
