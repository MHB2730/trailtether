import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/runtime_config.dart';
import 'core/supabase_options.dart';
import 'services/deep_link_service.dart';
import 'services/logger_service.dart';
import 'services/notification_service.dart';
import 'services/offline_map_service.dart';
import 'providers/app_state_provider.dart';
import 'providers/auth_provider.dart' as ap;
import 'providers/static_data_provider.dart';
import 'providers/safety_provider.dart';
import 'providers/gpx_provider.dart';
import 'providers/recording_provider.dart';
import 'providers/routing_provider.dart';
import 'providers/team_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/community_provider.dart';
import 'providers/review_provider.dart';
import 'providers/hike_history_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/team_tracking_provider.dart';
import 'screens/auth_gate.dart';
import 'widgets/update_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Logger
  await LoggerService.init();
  LoggerService.log('SYSTEM', 'App launching...');

  // 2. Initialize Offline Maps (FMTC)
  try {
    await OfflineMapService.init();
    LoggerService.log('SYSTEM', 'Offline Map Service initialized');
  } catch (e) {
    LoggerService.error('SYSTEM', 'Offline Map Service initialization failed: $e');
  }

  // 3. Initialize Supabase
  try {
    await Supabase.initialize(
      url: kSupabaseUrl,
      anonKey: kSupabaseAnonKey,
      debug: false,
    );
    kSupabaseAvailable = true;
    LoggerService.log('SYSTEM', 'Supabase initialized');
  } catch (e, stack) {
    kSupabaseAvailable = false;
    LoggerService.error('SYSTEM', 'Supabase initialization failed', stack);
  }

  // 4. Initialize Notifications
  try {
    await NotificationService.instance.init();
  } catch (e) {
    LoggerService.error('SYSTEM', 'Notification init failed: $e');
  }

  // 4b. Start the deep-link listener so OAuth callbacks (desktop) and
  // future trailtether:// links route to the right handler.
  try {
    await DeepLinkService.init();
    LoggerService.log('SYSTEM', 'Deep link service initialized');
  } catch (e, stack) {
    LoggerService.error('SYSTEM', 'Deep link init failed', stack);
  }

  // 5. Set orientation/UI overlay
  unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const TrailtetherRoot());
}

class TrailtetherRoot extends StatelessWidget {
  const TrailtetherRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => ap.AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => StaticDataProvider(),
          lazy: false,
        ),
        // SafetyProvider is wired via a proxy below so it receives the hiker's
        // GPS position from RecordingProvider for proximity-based alerting.
        ChangeNotifierProvider(
          create: (_) => GpxProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => RecordingProvider()),
        ChangeNotifierProvider(create: (_) => RoutingProvider()..init()),
        ChangeNotifierProvider(create: (_) => TeamProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => HikeHistoryProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProxyProvider2<RecordingProvider, TeamProvider,
            TeamTrackingProvider>(
          create: (context) => TeamTrackingProvider(),
          update: (context, recording, team, previous) {
            final p = previous ?? TeamTrackingProvider();
            p.recordingProvider = recording;
            p.teamProvider = team;
            return p;
          },
        ),
        // SafetyProvider — fed the hiker's GPS position from RecordingProvider so
        // proximity-based hazard alerts only fire for incidents within radius.
        ChangeNotifierProxyProvider<RecordingProvider, SafetyProvider>(
          create: (_) => SafetyProvider(),
          update: (context, recording, previous) {
            final safety = previous ?? SafetyProvider();
            final pos = recording.currentPosition;
            safety.setUserLocation(pos?.latitude, pos?.longitude);
            return safety;
          },
        ),
      ],
      child: const TrailtetherApp(),
    );
  }
}

class TrailtetherApp extends StatefulWidget {
  const TrailtetherApp({super.key});

  @override
  State<TrailtetherApp> createState() => _TrailtetherAppState();
}

class _TrailtetherAppState extends State<TrailtetherApp> {
  @override
  void initState() {
    super.initState();
    LoggerService.log('SYSTEM', 'TrailtetherApp state initialized');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trailtether',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8541A),
          brightness: Brightness.dark,
          primary: const Color(0xFFE8541A),
          surface: const Color(0xFF141414),
        ),
      ),
      // UpdateGate sits above AuthGate so a critical update can block even
      // unauthenticated users — without it, a safety-fix release couldn't be
      // enforced for someone stuck on a broken sign-in flow.
      home: const UpdateGate(child: AuthGate()),
    );
  }
}
