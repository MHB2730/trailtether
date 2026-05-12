import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

import '../core/supabase_options.dart';
import '../services/logger_service.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: kSupabaseUrl,
      anonKey: kSupabaseAnonKey,
    );
  } catch (e) {
    // Already initialized
  }

  final supabase = Supabase.instance.client;

  // Set up local notifications to replace FCM
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Listen to Supabase Realtime for SOS/Hazards (Bypasses Firebase completely)
  supabase
      .channel('background_incidents')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'incidents',
        callback: (payload) async {
          final newIncident = payload.newRecord;
          final type = newIncident['type'] ?? 'unknown';
          final desc = newIncident['description'] ?? 'Critical alert reported.';

          final prefs = await SharedPreferences.getInstance();
          final currentTeamId = prefs.getString('current_team_id');

          // Only alert if it's for everyone or our specific team
          final targetTeamId = newIncident['team_id'];
          if (targetTeamId == null || targetTeamId == currentTeamId) {
            String title = 'TEAM ALERT';
            if (type == 'sos') title = '🚨 CRITICAL SOS 🚨';
            if (type == 'hazard_zone') title = '⚠️ HAZARD REPORTED';
            if (type == 'broadcast') title = '📢 COMMAND CENTER BROADCAST';

            const AndroidNotificationDetails androidDetails =
                AndroidNotificationDetails(
              'trailtether_critical_alerts', // id
              'Critical Alerts', // name
              channelDescription: 'High priority SOS and Hazard alerts',
              importance: Importance.max,
              priority: Priority.max,
              playSound: true,
              enableVibration: true,
              fullScreenIntent: true, // Wakes up the screen
            );

            await flutterLocalNotificationsPlugin.show(
              DateTime.now().millisecond,
              title,
              desc,
              const NotificationDetails(android: androidDetails),
            );

            LoggerService.log('BACKGROUND_ALERT',
                'Fired local SOS push notification via Realtime!');
          }
        },
      )
      .subscribe();

  void updateForegroundNotification(Map<String, dynamic>? event) {
    if (service is! AndroidServiceInstance) return;

    final status = event?['status']?.toString() ?? 'active';
    final ghostMode = event?['ghostMode'] == true;
    final teamTracking = event?['teamTracking'] == true;
    final batterySaver = event?['batterySaver'] == true;

    final title = switch (status) {
      'paused' => 'Trailtether Paused',
      'sos' => 'Trailtether SOS Monitoring',
      'stopped' => 'Trailtether Standby',
      _ => 'Trailtether Tracking Active',
    };

    final parts = <String>[
      if (status == 'recording' || status == 'active') 'recording route',
      if (teamTracking) 'sharing team location',
      if (ghostMode) 'ghost mode',
      if (batterySaver) 'battery saver',
      'SOS alerts listening',
    ];

    service.setForegroundNotificationInfo(
      title: title,
      content: parts.join(' | '),
    );
  }

  updateForegroundNotification(const {'status': 'active'});

  service.on('setTrackingState').listen(updateForegroundNotification);

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Position? lastPosition;

  // Background cadence: 15s. Foreground TeamTrackingProvider pushes at 5s when moving;
  // this background loop is the safety net that keeps the dot alive on the command centre
  // when the app is backgrounded.
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    final session = supabase.auth.currentSession;
    if (session == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTeamId = prefs.getString('current_team_id');
      final ghostMode = prefs.getBool('ghost_mode') ?? false;

      if (ghostMode) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Always push at least every tick so the command centre sees a fresh timestamp
      // (= "still alive"). Movement check just decides whether this is a real position update.
      final movedMeters = lastPosition == null
          ? double.infinity
          : Geolocator.distanceBetween(lastPosition!.latitude,
              lastPosition!.longitude, pos.latitude, pos.longitude);
      if (movedMeters > 5) {
        lastPosition = pos;
      }

      {
        final insertData = {
          'uid': session.user.id,
          'lat': pos.latitude,
          'lon': pos.longitude,
          'heading': pos.heading,
          'speed': pos.speed,
          'altitude': pos.altitude,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'display_name': session.user.userMetadata?['display_name'] ?? 'Hiker',
          'team_id': currentTeamId,
          'status': 'recording',
        };

        // Upsert (not insert) — uid is the primary key, so insert fails after the first row.
        // Silently failing inserts here was the reason live tracking stopped appearing on the PC command centre.
        await supabase
            .from('team_member_locations')
            .upsert(insertData, onConflict: 'uid');
        LoggerService.log('BACKGROUND_SYNC',
            'Pushed un-killable background location to Supabase');
      }
    } catch (e) {
      LoggerService.error('BACKGROUND_SYNC', 'Background telemetry error: $e');
    }
  });
}

class BackgroundTrackingService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    if (Platform.isAndroid) {
      final FlutterLocalNotificationsPlugin plugin =
          FlutterLocalNotificationsPlugin();

      // Channel for the persistent background service
      const AndroidNotificationChannel trackingChannel =
          AndroidNotificationChannel(
        'trailtether_background_tracking',
        'Trailtether Background Telemetry',
        description:
            'Keeps your location updating for your team while the app is closed.',
        importance: Importance.low,
      );
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(trackingChannel);

      // Channel for the SOS alerts (High Priority)
      const AndroidNotificationChannel alertChannel =
          AndroidNotificationChannel(
        'trailtether_critical_alerts',
        'Critical Alerts',
        description: 'High priority SOS and Hazard alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(alertChannel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'trailtether_background_tracking',
        initialNotificationTitle: 'Trailtether Telemetry Active',
        initialNotificationContent:
            'Listening for SOS and broadcasting location...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  static Future<void> start() async {
    LoggerService.log('TRACKING', 'Starting background telemetry service');
    final service = FlutterBackgroundService();
    await service.startService();
  }

  static Future<void> stop() async {
    LoggerService.log('TRACKING', 'Stopping background telemetry service');
    final service = FlutterBackgroundService();
    service.invoke("stopService");
  }

  static void updateStatus({
    required String status,
    bool ghostMode = false,
    bool batterySaver = false,
    bool teamTracking = false,
  }) {
    final service = FlutterBackgroundService();
    service.invoke('setTrackingState', {
      'status': status,
      'ghostMode': ghostMode,
      'batterySaver': batterySaver,
      'teamTracking': teamTracking,
    });
  }
}
