import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/gpx_track.dart';
import '../models/recording_point.dart';
import '../services/gpx_service.dart';
import '../core/runtime_config.dart';
import '../services/logger_service.dart';

const _kPrefKey = 'gpx_tracks_v1';

class GpxProvider extends ChangeNotifier {
  final List<UserGpxTrack> _tracks = [];
  final Map<String, File?> _files = {};
  final Map<String, Uint8List> _bytes = {};

  List<UserGpxTrack> get tracks => List.unmodifiable(_tracks);

  GpxProvider() {
    _loadFromPrefs().then((_) {
      if (kSupabaseAvailable) syncWithCloud();
    });
  }

  bool _syncing = false;
  bool get syncing => _syncing;

  Future<void> syncWithCloud() async {
    if (_syncing) return;
    _syncing = true;
    notifyListeners();
    try {
      LoggerService.log('GPX_PROVIDER', 'Starting cloud sync...');
      final shared = await GpxService.fetchSharedTracks();
      LoggerService.log(
          'GPX_PROVIDER', 'Fetched ${shared.length} tracks from cloud');

      // Avoid duplicates
      final localIds = _tracks.map((t) => t.id).toSet();
      int added = 0;
      for (final track in shared) {
        if (!localIds.contains(track.id)) {
          _tracks.add(track);
          added++;
        }
      }
      unawaited(_saveToPrefs());
      LoggerService.log(
          'GPX_PROVIDER', 'Sync complete. Added $added new tracks.');
    } catch (e, stack) {
      LoggerService.error('GPX_PROVIDER', 'Sync failed: $e', stack);
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  void saveRecording(List<RecordingPoint> recording, String name) {
    if (recording.isEmpty) return;

    final points = recording.map((p) => p.toLatLng).toList();
    final elevations = recording.map((p) => p.altitude).toList();

    double dist = 0;
    int gain = 0;
    for (int i = 1; i < recording.length; i++) {
      dist += Geolocator.distanceBetween(
        recording[i - 1].latitude,
        recording[i - 1].longitude,
        recording[i].latitude,
        recording[i].longitude,
      );
      final diff = recording[i].altitude - recording[i - 1].altitude;
      if (diff > 0) gain += diff.toInt();
    }

    final track = UserGpxTrack(
      id: const Uuid().v4(),
      filename: '${name.replaceAll(' ', '_').toLowerCase()}.gpx',
      displayName: name,
      authorName: 'Me',
      description: 'Recorded on ${DateTime.now().toLocal()}',
      difficulty: 'Moderate',
      points: points,
      elevations: elevations,
      distanceKm: dist / 1000.0,
      elevationGainM: gain,
      color: nextColor(),
    );

    add(track);
  }

  Future<UserGpxTrack> importBytes({
    required Uint8List bytes,
    required String filename,
    String authorName = 'Imported',
  }) async {
    final track = GpxService.parseBytes(bytes, filename, nextColor());
    final imported = track.copyWith(authorName: authorName);
    add(imported, bytes: bytes);
    LoggerService.log(
      'GPX_IMPORT',
      'Imported inbound GPX $filename with ${imported.points.length} points',
    );
    return imported;
  }

  Color nextColor() => kGpxColors[_tracks.length % kGpxColors.length];

  void add(UserGpxTrack track, {File? file, Uint8List? bytes}) {
    final (resP, resE) =
        TrailUtils.simplifyPointsWithElevations(track.points, track.elevations);
    final optimizedTrack = UserGpxTrack(
      id: track.id,
      filename: track.filename,
      displayName: track.displayName,
      authorName: track.authorName,
      description: track.description,
      difficulty: track.difficulty,
      points: resP,
      elevations: resE,
      distanceKm: track.distanceKm,
      elevationGainM: track.elevationGainM,
      color: track.color,
      sharedToCloud: track.sharedToCloud,
      cloudPath: track.cloudPath,
    );

    _tracks.add(optimizedTrack);
    _files[optimizedTrack.id] = file;
    if (bytes != null) _bytes[optimizedTrack.id] = bytes;
    _saveToPrefs();
    notifyListeners();
  }

  File? fileForTrack(String id) => _files[id];

  Uint8List? bytesForTrack(String id) => _bytes[id];

  void update(UserGpxTrack updated) {
    final i = _tracks.indexWhere((t) => t.id == updated.id);
    if (i >= 0) {
      _tracks[i] = updated;
      _saveToPrefs();
      notifyListeners();
    }
  }

  void remove(String id) {
    _tracks.removeWhere((t) => t.id == id);
    _files.remove(id);
    _bytes.remove(id);
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kPrefKey);
      if (stored != null && stored.isNotEmpty) {
        final loaded = UserGpxTrack.decodeList(stored);
        _tracks.addAll(loaded);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('GpxProvider: failed to load tracks - $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefKey, UserGpxTrack.encodeList(_tracks));
    } catch (e) {
      debugPrint('GpxProvider: failed to save tracks - $e');
    }
  }
}
