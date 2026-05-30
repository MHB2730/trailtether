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

  /// Bucket holding incident photos. PRIVATE — safety-incident photos can be
  /// sensitive (an injured person, an exact hazard location), so the bucket is
  /// not world-readable. Reads go through a short-lived signed URL
  /// ([resolvePhotoUrl]); writes are owner-scoped via storage RLS.
  static const String _incidentBucket = 'incident-photos';

  /// Upload an incident photo and return its STORAGE PATH (not a URL). The
  /// caller threads the path through `Incident.photoUrl` so it lands in the
  /// row; display resolves it to a temporary signed URL via [resolvePhotoUrl].
  /// Storing the path (rather than a permanent public URL) keeps the bucket
  /// private and means a leaked row value can't be opened without a fresh
  /// signed URL minted under the viewer's session.
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
      await _db.storage.from(_incidentBucket).uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      LoggerService.log('INCIDENT', 'Photo uploaded: $path');
      return path;
    } catch (e, stack) {
      LoggerService.error('INCIDENT', 'uploadPhoto failed: $e', stack);
      return null;
    }
  }

  /// Resolve a stored incident-photo value to a viewable URL.
  /// - A storage path → a freshly-minted signed URL (1h TTL) from the private
  ///   bucket, valid only for the current session.
  /// - A legacy full `http(s)` URL (from before the private-bucket switch) →
  ///   returned as-is for backward compatibility.
  /// Returns null if the signed-URL mint fails (caller shows a fallback).
  static Future<String?> resolvePhotoUrl(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    if (stored.startsWith('http://') || stored.startsWith('https://')) {
      return stored; // legacy public URL — no rows like this exist post-switch
    }
    try {
      return await _db.storage
          .from(_incidentBucket)
          .createSignedUrl(stored, 3600);
    } catch (e, stack) {
      LoggerService.error('INCIDENT', 'resolvePhotoUrl failed: $e', stack);
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
      LoggerService.error(
          'INCIDENT_VERIFY', 'verify_incident failed: $e', stack);
      rethrow;
    }
  }

  /// Permanently delete an incident (owner or admin).
  static Future<void> deleteIncident(String incidentId) async {
    await _db.from(kColIncidents).delete().eq('id', incidentId);
  }
}
