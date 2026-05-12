import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import '../core/kalman_filter.dart';

class LocationService {
  static Stream<Position>? _stream;
  static Stream<Position>? _smoothedStream;
  static final _kalman = KalmanFilter();
  static const int _recordingDistanceFilterM =
      2; // Increased frequency for smoother trails

  static Future<LocationPermission> permissionStatus() =>
      Geolocator.checkPermission();

  static Future<bool> requestPermission({bool background = false}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final granted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    if (!granted) return false;

    if (background && Platform.isAndroid) {
      final alwaysStatus = await Permission.locationAlways.status;
      if (!alwaysStatus.isGranted) {
        final requested = await Permission.locationAlways.request();
        if (!requested.isGranted) return false;
      }

      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted &&
          !notificationStatus.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    }

    return true;
  }

  /// Stream of live positions. Fires every 5 metres (battery-friendly).
  static Stream<Position> get positionStream {
    _stream ??= Geolocator.getPositionStream(
      locationSettings: liveLocationSettings,
    );
    return _stream!;
  }

  /// Stream of live positions with Kalman filtering applied.
  static Stream<Position> get smoothedPositionStream {
    _smoothedStream ??= smooth(positionStream);
    return _smoothedStream!;
  }

  /// Wraps a position stream with Kalman filtering.
  static Stream<Position> smooth(Stream<Position> source) {
    return source.map((pos) {
      final (sLat, sLon) = _kalman.process(pos.latitude, pos.longitude);
      return Position(
        latitude: sLat,
        longitude: sLon,
        timestamp: pos.timestamp,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        heading: pos.heading,
        speed: pos.speed,
        speedAccuracy: pos.speedAccuracy,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    });
  }

  static LocationSettings get liveLocationSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: _recordingDistanceFilterM,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: _recordingDistanceFilterM,
    );
  }

  static LocationSettings get recordingLocationSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: _recordingDistanceFilterM,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Trailtether tracking active',
          notificationText:
              'Recording your hike in the background to keep the GPX complete.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: _recordingDistanceFilterM,
    );
  }

  static LocationSettings get batterySaverSettings {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 30,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Trailtether Power Saver',
          notificationText: 'Tracking frequency reduced to save battery.',
          enableWakeLock: false,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 30,
    );
  }

  static Future<Position?> currentPosition() async {
    final granted = await requestPermission();
    if (!granted) return null;
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }

  static void dispose() {
    _stream = null;
  }

  /// Reset the Kalman filter state. Call at the start of each recording so
  /// stale jitter from previous sessions doesn't bias the first few fixes.
  static void resetSmoothing() {
    _kalman.reset();
  }
}
