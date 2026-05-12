import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/gpx_track.dart';
import 'logger_service.dart';

SupabaseClient get _db => Supabase.instance.client;

class GpxService {
  static const _uuid = Uuid();
  static const _bucket = 'gpx_uploads';

  /// Fetch all shared tracks from the cloud bucket.
  static Future<List<UserGpxTrack>> fetchSharedTracks() async {
    dynamic response;
    try {
      response = await _db
          .from(kColGpxUploads)
          .select('*, profiles(username)')
          .order('created_at', ascending: false);
    } catch (e) {
      LoggerService.log(
          'GPX_FETCH', 'Join failed, falling back to simple query: $e');
      response = await _db
          .from(kColGpxUploads)
          .select('*')
          .order('created_at', ascending: false);
    }

    final list = response as List;
    final results = <UserGpxTrack>[];

    for (final row in list) {
      try {
        final path = row['storage_path'] as String;
        final bytes = await _db.storage.from(_bucket).download(path);
        final xmlString = utf8.decode(bytes, allowMalformed: true);

        // Use a dummy color or logic to assign unique colors
        final color = kGpxColors[results.length % kGpxColors.length];
        final track =
            _parse(xmlString, row['filename'] ?? 'cloud_track.gpx', color);

        results.add(track.copyWith(
          id: row['id']?.toString() ?? track.id,
          displayName: row['display_name'] ?? track.displayName,
          authorName: row['profiles']?['username'] ?? 'System',
          sharedToCloud: true,
          cloudPath: path,
        ));
      } catch (e) {
        LoggerService.error(
            'GPX_FETCH', 'Failed to fetch/parse shared track: $e');
      }
    }
    return results;
  }

  /// Prompt the user to pick a .gpx file and parse it.
  static Future<({UserGpxTrack track, File? file, Uint8List bytes})?>
      pickAndParse(Color color) async {
    FilePickerResult? result;
    try {
      // On Windows, FileType.custom with 'gpx' often fails silently because
      // .gpx is not a registered system MIME type. Use FileType.any instead
      // and validate the extension manually.
      if (Platform.isWindows) {
        LoggerService.log(
            'GPX_PICKER', 'Windows detected — using FileType.any');
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['gpx'],
          withData: true,
        );
      }
    } on PlatformException catch (e) {
      LoggerService.error(
          'GPX_PICKER', 'Custom filter failed, falling back to any: $e');
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
    } catch (e) {
      LoggerService.error('GPX_PICKER', 'Unexpected picker error: $e');
      rethrow;
    }
    if (result == null || result.files.isEmpty) return null;

    final pickedFile = result.files.first;
    LoggerService.log(
        'GPX_PICKER', 'Picked: ${pickedFile.name} (${pickedFile.size} bytes)');

    // Validate extension
    if (!pickedFile.name.toLowerCase().endsWith('.gpx')) {
      throw Exception(
          'Please select a .gpx file. You selected: ${pickedFile.name}');
    }

    final bytes = pickedFile.bytes ??
        (pickedFile.path != null
            ? await File(pickedFile.path!).readAsBytes()
            : null);

    if (bytes == null) {
      throw Exception(
          'Could not read file data. Please try again or check file permissions.');
    }

    final track = _parse(
        utf8.decode(bytes, allowMalformed: true), pickedFile.name, color);

    return (
      track: track,
      file: pickedFile.path != null ? File(pickedFile.path!) : null,
      bytes: Uint8List.fromList(bytes),
    );
  }

  static UserGpxTrack parseBytes(
      Uint8List bytes, String filename, Color color) {
    final xmlString = utf8.decode(bytes, allowMalformed: true);
    return _parse(xmlString, filename, color);
  }

  static UserGpxTrack _parse(String xmlString, String filename, Color color) {
    final sanitized = xmlString
        .replaceAll(
          RegExp(r'[^\x09\x0A\x0D\x20-\uD7FF\uE000-\uFFFD\u10000-\u10FFFF]'),
          '',
        )
        .trim();

    late final Gpx gpxData;
    try {
      gpxData = GpxReader().fromString(sanitized);
    } catch (e, stack) {
      LoggerService.error('GPX_PARSE', 'Failed to parse GPX: $e', stack);
      throw Exception('Invalid GPX file. Please choose a valid .gpx route.');
    }

    final points = <LatLng>[];
    final elevations = <double>[];

    for (final track in gpxData.trks) {
      for (final seg in track.trksegs) {
        for (final pt in seg.trkpts) {
          if (pt.lat != null && pt.lon != null) {
            points.add(LatLng(pt.lat!, pt.lon!));
            elevations.add(pt.ele ?? 0.0);
          }
        }
      }
    }

    for (final route in gpxData.rtes) {
      for (final pt in route.rtepts) {
        if (pt.lat != null && pt.lon != null) {
          points.add(LatLng(pt.lat!, pt.lon!));
          elevations.add(pt.ele ?? 0.0);
        }
      }
    }

    if (points.isEmpty) {
      throw Exception('This GPX file does not contain route points.');
    }

    return UserGpxTrack(
      id: _uuid.v4(),
      filename: filename,
      points: points,
      elevations: elevations,
      distanceKm: _calcDistKm(points),
      elevationGainM: _calcGain(elevations),
      color: kColorOrange,
    );
  }

  /// Upload GPX data to Supabase Storage and write metadata to the database.
  static Future<UserGpxTrack> upload(
    UserGpxTrack track, {
    File? file,
    Uint8List? bytes,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw Exception('You must be signed in to upload GPX files.');
    }

    LoggerService.log('GPX_UPLOAD', 'Step 1: Auth OK — uid=$uid');

    final deviceId = await TrailUtils.getDeviceId();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$uid/${track.id}_$timestamp.gpx';
    const options = FileOptions(contentType: 'application/gpx+xml');

    LoggerService.log('GPX_UPLOAD',
        'Step 2: Uploading to storage — bucket=$_bucket path=$storagePath');

    try {
      if (bytes != null && bytes.isNotEmpty) {
        await _db.storage.from(_bucket).uploadBinary(
              storagePath,
              bytes,
              fileOptions: options,
            );
      } else if (file != null && await file.exists()) {
        await _db.storage.from(_bucket).upload(
              storagePath,
              file,
              fileOptions: options,
            );
      } else {
        await _db.storage.from(_bucket).uploadBinary(
              storagePath,
              _buildGpxBytes(track),
              fileOptions: options,
            );
      }
    } catch (e) {
      LoggerService.error('GPX_UPLOAD', 'Storage upload failed: $e');
      rethrow;
    }

    LoggerService.log(
        'GPX_UPLOAD', 'Step 3: Storage OK. Inserting DB record...');

    try {
      await _db.from(kColGpxUploads).insert({
        'filename': track.filename,
        'display_name': track.displayName,
        'author_name': track.authorName,
        'description': track.description,
        'difficulty': track.difficulty,
        'storage_path': storagePath,
        'device_id': deviceId,
        'user_id': uid,
        'distance_km': track.distanceKm,
        'point_count': track.points.length,
      });
    } catch (e) {
      LoggerService.error('GPX_UPLOAD', 'DB insert failed: $e');
      rethrow;
    }

    LoggerService.log('GPX_UPLOAD',
        'Step 4: Complete — ${track.filename} uploaded successfully');
    return track.copyWith(sharedToCloud: true, cloudPath: storagePath);
  }

  static Uint8List _buildGpxBytes(UserGpxTrack track) {
    final escape = const HtmlEscape().convert;
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
          '<gpx version="1.1" creator="Trailtether" xmlns="http://www.topografix.com/GPX/1/1">')
      ..writeln('  <metadata>')
      ..writeln('    <name>${escape(track.label)}</name>');

    if (track.description.trim().isNotEmpty) {
      buffer.writeln('    <desc>${escape(track.description.trim())}</desc>');
    }

    buffer
      ..writeln('  </metadata>')
      ..writeln('  <trk>')
      ..writeln('    <name>${escape(track.label)}</name>')
      ..writeln('    <trkseg>');

    for (var i = 0; i < track.points.length; i++) {
      final point = track.points[i];
      final elevation = i < track.elevations.length ? track.elevations[i] : 0.0;
      buffer
        ..write(
            '      <trkpt lat="${point.latitude}" lon="${point.longitude}">')
        ..write('<ele>$elevation</ele>')
        ..writeln('</trkpt>');
    }

    buffer
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static double _calcDistKm(List<LatLng> pts) {
    if (pts.length < 2) return 0;
    double d = 0;
    const r = 6371.0;
    for (int i = 1; i < pts.length; i++) {
      final dLat = _rad(pts[i].latitude - pts[i - 1].latitude);
      final dLon = _rad(pts[i].longitude - pts[i - 1].longitude);
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_rad(pts[i - 1].latitude)) *
              math.cos(_rad(pts[i].latitude)) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      d += r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    }
    return d;
  }

  static int _calcGain(List<double> elevations) {
    double gain = 0;
    for (int i = 1; i < elevations.length; i++) {
      final diff = elevations[i] - elevations[i - 1];
      if (diff > 0.5) gain += diff;
    }
    return gain.round();
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
