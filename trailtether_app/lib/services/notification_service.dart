import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'logger_service.dart';

/// Handles local notifications for chat, safety, and SOS feedback.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Returns true if local notifications are supported on this platform.
  static bool get _supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isWindows;

  Future<void> init() async {
    if (_initialized || !_supported) return;

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linux = LinuxInitializationSettings(defaultActionName: 'Open');
      
      // Windows initialization (optional for simple usage but recommended for stability)
      // Note: In some versions of flutter_local_notifications, this is required.
      // We skip it if the desktop implementation is not available.

      const initSettings = InitializationSettings(
        android: android,
        iOS: darwin,
        linux: linux,
      );

      await _local.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          LoggerService.log('NOTIFICATIONS', 'Notification clicked: ${response.payload}');
        },
      );
      
      if (Platform.isAndroid) {
        await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      _initialized = true;
      LoggerService.log('NOTIFICATIONS', 'Service initialized successfully');
    } catch (e) {
      LoggerService.error('NOTIFICATIONS', 'Init failed: $e');
    }
  }

  /// Retained as a no-op for older call sites during rollout.
  Future<void> syncToken() async {
    return;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String sound = 'notification',
    bool isEmergency = false,
  }) async {
    if (!_supported) {
      LoggerService.log('NOTIFICATIONS',
          '[${isEmergency ? "EMERGENCY" : "INFO"}] $title: $body');
      return;
    }

    if (!_initialized) {
      await init();
    }

    try {
      final androidSound = RawResourceAndroidNotificationSound(sound);

      await _local.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            isEmergency ? 'emergency_alerts' : 'general_notifications',
            isEmergency ? 'Emergency Alerts' : 'General Notifications',
            channelDescription: isEmergency
                ? 'Critical notifications for SOS and safety events'
                : 'Updates for chat and community activity',
            importance:
                isEmergency ? Importance.max : Importance.defaultImportance,
            priority: isEmergency ? Priority.high : Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            color:
                isEmergency ? const Color(0xFFE53935) : const Color(0xFFFB8C00),
            enableVibration: true,
            playSound: true,
            sound: androidSound,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: '$sound.aiff',
          ),
          // Simple Windows implementation
          // ignore: deprecated_member_use_from_same_package
        ),
      );
    } catch (e) {
      LoggerService.error('NOTIFICATIONS', 'showNotification failed: $e');
    }
  }
}
