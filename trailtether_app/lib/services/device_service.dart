import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/utils.dart';

class DeviceService {
  static String? _cachedId;

  /// Returns a stable anonymous device identifier across Android, iOS,
  /// and Windows. Falls back to a persisted UUID when the platform doesn't
  /// expose a stable hardware ID.
  static Future<String> getDeviceId() async {
    if (_cachedId != null) return _cachedId!;

    try {
      final id = await TrailUtils.getDeviceId();
      if (id.isNotEmpty && id != 'unknown_platform' && id != 'unknown_ios') {
        _cachedId = id;
        return _cachedId!;
      }
    } catch (_) {/* fall through to UUID */}

    final prefs = await SharedPreferences.getInstance();
    var stored = prefs.getString('device_uuid');
    if (stored == null) {
      stored = const Uuid().v4();
      await prefs.setString('device_uuid', stored);
    }
    _cachedId = stored;
    return _cachedId!;
  }

  /// Returns a display-friendly short ID for the UI (e.g. "Hiker #3F2A").
  static Future<String> getDisplayId() async {
    final id = await getDeviceId();
    final tag = id.length >= 4 ? id.substring(0, 4) : id;
    return 'Hiker #${tag.toUpperCase()}';
  }
}
