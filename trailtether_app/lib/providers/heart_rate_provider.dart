import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/logger_service.dart';

/// Live heart rate from a BLE heart-rate broadcaster — the Garmin watch in
/// "Broadcast Heart Rate" mode, or any standard BLE chest strap.
///
/// We speak the standard Bluetooth Heart Rate Profile: scan for service
/// `0x180D`, connect, subscribe to the Heart Rate Measurement characteristic
/// `0x2A37`, and decode the BPM. Battery (`0x180F`/`0x2A19`) is read once if the
/// device exposes it. The BLE link itself is the source of truth for the
/// connected/disconnected indicator — no cloud round-trip.
enum HrStatus { off, idle, scanning, connecting, connected, error }

/// A heart-rate broadcaster found during a scan.
class HrScanItem {
  final String id;
  final String name;
  final int rssi;
  const HrScanItem({required this.id, required this.name, required this.rssi});
}

// Standard Bluetooth SIG 16-bit UUIDs.
final Guid _hrService = Guid('180D');
final Guid _hrMeasure = Guid('2A37');
final Guid _battService = Guid('180F');
final Guid _battLevel = Guid('2A19');

const _kPrefDeviceId = 'hr_device_id';
const _kPrefDeviceName = 'hr_device_name';

class HeartRateProvider extends ChangeNotifier {
  HrStatus _status = HrStatus.idle;
  int? _bpm;
  int? _battery;
  String? _deviceId;
  String? _deviceName;
  String? _error;
  DateTime? _lastBeatAt;
  final List<HrScanItem> _found = [];

  HrStatus get status => _status;
  int? get bpm => _bpm;
  int? get battery => _battery;
  String? get deviceName => _deviceName;
  String? get deviceId => _deviceId;
  String? get error => _error;
  bool get isConnected => _status == HrStatus.connected;
  bool get isBusy =>
      _status == HrStatus.scanning || _status == HrStatus.connecting;
  bool get hasSavedDevice => _deviceId != null;

  /// A short copy line for tiles ("● 72 bpm", "Connecting…", "Pair a watch").
  String get summary {
    switch (_status) {
      case HrStatus.connected:
        return _bpm != null ? '$_bpm bpm' : 'Connected';
      case HrStatus.connecting:
        return 'Connecting…';
      case HrStatus.scanning:
        return 'Scanning…';
      case HrStatus.off:
        return 'Bluetooth off';
      case HrStatus.error:
        return _error ?? 'Not connected';
      case HrStatus.idle:
        return _deviceName != null
            ? 'Tap to reconnect'
            : 'Pair a watch / strap';
    }
  }

  /// Stale-data guard: a strap can hold a connection but stop sending beats.
  bool get isStale =>
      _lastBeatAt == null ||
      DateTime.now().difference(_lastBeatAt!) > const Duration(seconds: 10);

  List<HrScanItem> get found => List.unmodifiable(_found);

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _hrSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  bool _disposed = false;
  bool _userDisconnected = false;

  Future<void> init() async {
    if (!await FlutterBluePlus.isSupported) {
      _set(HrStatus.error, error: 'Bluetooth not supported on this device');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_kPrefDeviceId);
    _deviceName = prefs.getString(_kPrefDeviceName);

    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      if (s == BluetoothAdapterState.on) {
        // Adapter came on — silently try to get our saved watch back.
        if (_deviceId != null &&
            !isConnected &&
            !isBusy &&
            !_userDisconnected) {
          unawaited(reconnect());
        }
      } else if (!isConnected) {
        _set(HrStatus.off);
      }
    });

    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on &&
        _deviceId != null) {
      unawaited(reconnect());
    } else {
      notifyListeners();
    }
  }

  /// Ask for the runtime BLE permissions (Android 12+: scan + connect).
  Future<bool> _ensurePermissions() async {
    final res = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    final granted = res.values.every((s) => s.isGranted || s.isLimited);
    if (!granted) {
      _set(HrStatus.error, error: 'Bluetooth permission denied');
    }
    return granted;
  }

  /// Scan for nearby heart-rate broadcasters. Results land in [found].
  Future<void> startScan() async {
    if (isBusy) return;
    if (!await _ensurePermissions()) return;

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn(); // Android prompt to enable Bluetooth
      } catch (_) {/* user declined */}
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        _set(HrStatus.off, error: 'Turn on Bluetooth, then scan again');
        return;
      }
    }

    _found.clear();
    _set(HrStatus.scanning);
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : (r.device.platformName.isNotEmpty
                ? r.device.platformName
                : 'Unknown device');
        final existing = _found.indexWhere((d) => d.id == id);
        final item = HrScanItem(id: id, name: name, rssi: r.rssi);
        if (existing >= 0) {
          _found[existing] = item;
        } else {
          _found.add(item);
        }
      }
      _found.sort((a, b) => b.rssi.compareTo(a.rssi));
      notifyListeners();
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [_hrService],
        timeout: const Duration(seconds: 12),
      );
    } catch (e, st) {
      LoggerService.error('HR', 'scan failed: $e', st);
    }
    // startScan resolves when the timeout elapses.
    await _scanSub?.cancel();
    _scanSub = null;
    if (_status == HrStatus.scanning) {
      _set(_found.isEmpty ? HrStatus.error : HrStatus.idle,
          error: _found.isEmpty
              ? 'No heart-rate sensor found. On the watch, enable Broadcast Heart Rate, then scan again.'
              : null);
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
    if (_status == HrStatus.scanning) _set(HrStatus.idle);
  }

  Future<void> connectTo(HrScanItem item) =>
      _connect(BluetoothDevice.fromId(item.id), name: item.name);

  /// Reconnect to the previously-saved device (auto on startup / adapter-on).
  Future<void> reconnect() async {
    if (_deviceId == null) return;
    if (!await _ensurePermissions()) return;
    await _connect(BluetoothDevice.fromId(_deviceId!), name: _deviceName);
  }

  Future<void> _connect(BluetoothDevice device, {String? name}) async {
    await stopScan();
    _userDisconnected = false;
    _device = device;
    _set(HrStatus.connecting);
    try {
      await _connSub?.cancel();
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && !_disposed) {
          _onDisconnected();
        }
      });

      await device.connect(
          timeout: const Duration(seconds: 15), autoConnect: false);

      final services = await device.discoverServices();
      final hr = services.firstWhereOrNull((s) => s.uuid == _hrService);
      final hrChar =
          hr?.characteristics.firstWhereOrNull((c) => c.uuid == _hrMeasure);
      if (hrChar == null) {
        await device.disconnect();
        _set(HrStatus.error,
            error: 'That device has no heart-rate broadcast. '
                'Enable Broadcast Heart Rate on the watch.');
        return;
      }

      await hrChar.setNotifyValue(true);
      await _hrSub?.cancel();
      _hrSub = hrChar.onValueReceived.listen(_parseHr);

      // Battery is optional — read it once if exposed.
      final batt = services.firstWhereOrNull((s) => s.uuid == _battService);
      final battChar =
          batt?.characteristics.firstWhereOrNull((c) => c.uuid == _battLevel);
      if (battChar != null) {
        try {
          final v = await battChar.read();
          if (v.isNotEmpty) _battery = v.first;
        } catch (_) {/* not all expose it */}
      }

      _deviceId = device.remoteId.str;
      _deviceName = (name != null && name.isNotEmpty)
          ? name
          : (device.platformName.isNotEmpty
              ? device.platformName
              : 'HR sensor');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefDeviceId, _deviceId!);
      await prefs.setString(_kPrefDeviceName, _deviceName!);

      _set(HrStatus.connected);
      LoggerService.log('HR', 'connected to $_deviceName');
    } catch (e, st) {
      LoggerService.error('HR', 'connect failed: $e', st);
      _set(HrStatus.error, error: 'Could not connect. Move closer and retry.');
    }
  }

  void _parseHr(List<int> data) {
    if (data.isEmpty) return;
    final flags = data[0];
    int value;
    if ((flags & 0x01) == 0) {
      if (data.length < 2) return;
      value = data[1]; // uint8
    } else {
      if (data.length < 3) return;
      value = data[1] | (data[2] << 8); // uint16, little-endian
    }
    if (value <= 0) return;
    _bpm = value;
    _lastBeatAt = DateTime.now();
    if (_status != HrStatus.connected) {
      _status = HrStatus.connected;
    }
    notifyListeners();
  }

  void _onDisconnected() {
    _hrSub?.cancel();
    _hrSub = null;
    _bpm = null;
    _battery = null;
    if (_userDisconnected) {
      _set(HrStatus.idle);
    } else {
      // Unexpected drop (out of range / watch left broadcast). Keep the saved
      // device so the adapter-on / manual retry can bring it back.
      _set(HrStatus.error, error: 'Lost connection — move closer to retry.');
    }
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    await _hrSub?.cancel();
    _hrSub = null;
    try {
      await _device?.disconnect();
    } catch (_) {}
    _bpm = null;
    _battery = null;
    _set(HrStatus.idle);
  }

  /// Forget the saved device entirely.
  Future<void> forget() async {
    await disconnect();
    _deviceId = null;
    _deviceName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefDeviceId);
    await prefs.remove(_kPrefDeviceName);
    notifyListeners();
  }

  void _set(HrStatus s, {String? error}) {
    if (_disposed) return;
    _status = s;
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _scanSub?.cancel();
    _connSub?.cancel();
    _hrSub?.cancel();
    _adapterSub?.cancel();
    _device?.disconnect();
    super.dispose();
  }
}
