import 'dart:io' show Platform;

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/saved_hike.dart';
import 'logger_service.dart';

enum HealthConnectStatus {
  success,
  unsupportedPlatform,
  sdkUnavailable,
  sdkUpdateRequired,
  permissionDenied,
  invalidHike,
  writeFailed,
  error,
}

class HealthConnectResult {
  final HealthConnectStatus status;
  final String? detail;
  const HealthConnectResult(this.status, [this.detail]);

  bool get ok => status == HealthConnectStatus.success;

  String get userMessage {
    switch (status) {
      case HealthConnectStatus.success:
        return 'Activity written to Health Connect';
      case HealthConnectStatus.unsupportedPlatform:
        return 'Health Connect is only supported on Android and iOS';
      case HealthConnectStatus.sdkUnavailable:
        return 'Health Connect app is not installed on this device';
      case HealthConnectStatus.sdkUpdateRequired:
        return 'Health Connect needs to be updated from the Play Store';
      case HealthConnectStatus.permissionDenied:
        return 'Health Connect permissions were not granted';
      case HealthConnectStatus.invalidHike:
        return 'Hike has too few GPS points to sync';
      case HealthConnectStatus.writeFailed:
        return 'Health Connect rejected the write${detail != null ? " ($detail)" : ""}';
      case HealthConnectStatus.error:
        return 'Health Connect error${detail != null ? ": $detail" : ""}';
    }
  }
}

class HealthConnectService {
  HealthConnectService._();

  static final Health _health = Health();
  static bool _configured = false;

  // Platform-specific data types.
  // On Android, writeWorkoutData inserts a TotalCaloriesBurnedRecord for
  // totalEnergyBurned, so we must request TOTAL_CALORIES_BURNED permission.
  // On iOS, only ACTIVE_ENERGY_BURNED exists for HKWorkout.totalEnergyBurned.
  static List<HealthDataType> get _writeTypes => [
        HealthDataType.WORKOUT,
        HealthDataType.DISTANCE_DELTA,
        if (Platform.isAndroid)
          HealthDataType.TOTAL_CALORIES_BURNED
        else
          HealthDataType.ACTIVE_ENERGY_BURNED,
      ];

  static List<HealthDataAccess> get _writePermissions => List.filled(
        _writeTypes.length,
        HealthDataAccess.READ_WRITE,
      );

  static Future<void> configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  static Future<HealthConnectStatus> _checkAvailability() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return HealthConnectStatus.unsupportedPlatform;
    }
    await configure();
    if (!Platform.isAndroid) return HealthConnectStatus.success;

    final status = await _health.getHealthConnectSdkStatus();
    LoggerService.log('HEALTH_CONNECT', 'sdkStatus=$status');
    switch (status) {
      case HealthConnectSdkStatus.sdkAvailable:
        return HealthConnectStatus.success;
      case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
        return HealthConnectStatus.sdkUpdateRequired;
      case HealthConnectSdkStatus.sdkUnavailable:
      default:
        return HealthConnectStatus.sdkUnavailable;
    }
  }

  static Future<bool> isAvailable() async =>
      await _checkAvailability() == HealthConnectStatus.success;

  static Future<HealthConnectStatus> _ensureAuthorized() async {
    final availability = await _checkAvailability();
    if (availability != HealthConnectStatus.success) return availability;

    if (Platform.isAndroid) {
      await Permission.activityRecognition.request();
      await Permission.location.request();
    }

    final hasPerms = await _health.hasPermissions(
      _writeTypes,
      permissions: _writePermissions,
    );
    LoggerService.log('HEALTH_CONNECT', 'hasPermissions=$hasPerms');

    if (hasPerms == true) return HealthConnectStatus.success;

    final granted = await _health.requestAuthorization(
      _writeTypes,
      permissions: _writePermissions,
    );
    LoggerService.log('HEALTH_CONNECT', 'requestAuthorization=$granted');
    return granted
        ? HealthConnectStatus.success
        : HealthConnectStatus.permissionDenied;
  }

  static Future<HealthConnectResult> writeHike(SavedHike hike) async {
    if (hike.points.length < 2 || hike.endedAt.isBefore(hike.startedAt)) {
      return const HealthConnectResult(HealthConnectStatus.invalidHike);
    }

    try {
      final authStatus = await _ensureAuthorized();
      if (authStatus != HealthConnectStatus.success) {
        return HealthConnectResult(authStatus);
      }

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
      return ok
          ? const HealthConnectResult(HealthConnectStatus.success)
          : const HealthConnectResult(HealthConnectStatus.writeFailed);
    } catch (e, stack) {
      LoggerService.error('HEALTH_CONNECT', 'writeHike failed: $e', stack);
      return HealthConnectResult(HealthConnectStatus.error, e.toString());
    }
  }

  static int _estimateKilocalories(SavedHike hike) {
    final distanceComponent = hike.distanceKm * 65;
    final ascentComponent = hike.ascentM * 0.12;
    return (distanceComponent + ascentComponent).round();
  }
}
