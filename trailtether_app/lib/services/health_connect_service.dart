import 'dart:io' show Platform;

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/saved_hike.dart';
import 'logger_service.dart';

class HealthConnectService {
  HealthConnectService._();

  static final Health _health = Health();
  static bool _configured = false;

  static const List<HealthDataType> _writeTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static const List<HealthDataAccess> _writePermissions = [
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
  ];

  static Future<void> configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  static Future<bool> isAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    await configure();

    if (!Platform.isAndroid) return true;
    final status = await _health.getHealthConnectSdkStatus();
    return status == HealthConnectSdkStatus.sdkAvailable;
  }

  static Future<bool> requestWriteAccess() async {
    if (!await isAvailable()) return false;

    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
      await Permission.location.request();
    }

    return _health.requestAuthorization(
      _writeTypes,
      permissions: _writePermissions,
    );
  }

  static Future<bool> writeHike(SavedHike hike) async {
    if (hike.points.length < 2 || hike.endedAt.isBefore(hike.startedAt)) {
      return false;
    }

    try {
      final authorized = await requestWriteAccess();
      if (!authorized) return false;

      final workoutType = switch (hike.activityType.toLowerCase()) {
        'run' || 'running' => HealthWorkoutActivityType.RUNNING,
        'walk' || 'walking' => HealthWorkoutActivityType.WALKING,
        'bike' || 'cycling' || 'ride' => HealthWorkoutActivityType.BIKING,
        _ => HealthWorkoutActivityType.HIKING,
      };

      final distanceMeters = (hike.distanceKm * 1000).round();
      final calories = _estimateKilocalories(hike);

      final ok = await _health.writeWorkoutData(
        activityType: workoutType,
        title: hike.name,
        start: hike.startedAt,
        end: hike.endedAt,
        totalDistance: distanceMeters > 0 ? distanceMeters : null,
        totalEnergyBurned: calories > 0 ? calories : null,
        recordingMethod: RecordingMethod.active,
      );

      LoggerService.log(
        'HEALTH_CONNECT',
        'writeHike ${ok ? "ok" : "failed"}: ${hike.name}',
      );
      return ok;
    } catch (e, stack) {
      LoggerService.error('HEALTH_CONNECT', 'writeHike failed: $e', stack);
      return false;
    }
  }

  static int _estimateKilocalories(SavedHike hike) {
    final distanceComponent = hike.distanceKm * 65;
    final ascentComponent = hike.ascentM * 0.12;
    return (distanceComponent + ascentComponent).round();
  }
}
