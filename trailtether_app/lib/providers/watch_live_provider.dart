import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/watch_live_service.dart';

enum WatchLinkState { idle, listening, receiving }

/// Holds the latest live hike state streamed from the watch app (HR, position,
/// distance, duration…) for the "Watch Live" screen. Driven by
/// [WatchLiveService]; goes live the moment the Connect IQ Mobile SDK plugin is
/// wired on the native side.
class WatchLiveProvider extends ChangeNotifier {
  WatchLinkState _state = WatchLinkState.idle;
  Map<String, dynamic> _data = const {};
  DateTime? _lastMsgAt;
  StreamSubscription<Map<String, dynamic>>? _sub;

  WatchLinkState get state => _state;

  int? get hr => (_data['hr'] as num?)?.toInt();
  int? get avgHr => (_data['ahr'] as num?)?.toInt();
  int? get durationSec => (_data['dur'] as num?)?.toInt();
  double? get distanceM => (_data['dist'] as num?)?.toDouble();
  double? get speedMps => (_data['spd'] as num?)?.toDouble();
  double? get altitudeM => (_data['alt'] as num?)?.toDouble();
  int? get calories => (_data['cal'] as num?)?.toInt();
  double? get lat => (_data['lat'] as num?)?.toDouble();
  double? get lon => (_data['lon'] as num?)?.toDouble();
  String? get activity => _data['act'] as String?;

  /// True while fresh frames are arriving (the watch sends ~1 Hz).
  bool get isLive =>
      _lastMsgAt != null &&
      DateTime.now().difference(_lastMsgAt!) < const Duration(seconds: 6);

  Future<void> start() async {
    if (_sub != null) return;
    _state = WatchLinkState.listening;
    notifyListeners();
    _sub = WatchLiveService.stream().listen((msg) {
      if (msg.isEmpty) return;
      _data = msg;
      _lastMsgAt = DateTime.now();
      _state = WatchLinkState.receiving;
      notifyListeners();
    });
    await WatchLiveService.start();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await WatchLiveService.stop();
    _state = WatchLinkState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    WatchLiveService.stop();
    super.dispose();
  }
}
