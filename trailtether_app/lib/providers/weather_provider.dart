import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/runtime_config.dart';
import '../models/weather.dart';
import '../services/weather_aggregator_service.dart';

class WeatherProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _locations = [
    {'name': 'Royal Natal', 'lat': -28.6833, 'lon': 28.9333},
    {'name': 'Cathedral Peak', 'lat': -28.9167, 'lon': 29.1833},
    {'name': 'Monk\'s Cowl', 'lat': -29.0333, 'lon': 29.4000},
    {'name': 'Giant\'s Castle', 'lat': -29.2833, 'lon': 29.5167},
    {'name': 'Sani Pass', 'lat': -29.5833, 'lon': 29.2833},
  ];

  List<Map<String, dynamic>> get locations => _locations;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  String? _currentUid;

  WeatherData? _currentWeather;
  WeatherData? get currentWeather => _currentWeather;

  /// True when the active forecast points at snow conditions over the
  /// next 24 h. Drives the Drakensberg snow-hero swap on the Home
  /// screen. Conservative — requires either:
  ///   • a WMO snow code (71-77 snowfall, 85-86 snow showers), OR
  ///   • forecast minimum below 0 °C with any precipitation (a strong
  ///     proxy when the source returns rain codes for sleet/hail mixes
  ///     that are functionally snow at Berg elevations).
  /// Returns false when no weather data has loaded yet — the dark
  /// (no-snow) hero is the safer default.
  bool get isSnowingInDrakensberg {
    final w = _currentWeather;
    if (w == null) return false;
    // WMO snow codes (per Open-Meteo's reference table).
    bool isSnowCode(int code) =>
        (code >= 71 && code <= 77) || code == 85 || code == 86;
    if (isSnowCode(w.current.weatherCode)) return true;
    for (final d in w.daily.take(2)) {
      if (isSnowCode(d.weatherCode)) return true;
      // Below-freezing forecast with any precip → treat as snow.
      if (d.tempMin <= 0 && d.precipSum > 0.2) return true;
    }
    return false;
  }

  WeatherProvider() {
    _loadLocal();
  }

  void setUserId(String? uid) {
    if (_currentUid == uid) return;
    _currentUid = uid;
    if (uid != null) {
      _loadFromSupabase();
    } else {
      _loadLocal();
    }
  }

  Future<void> fetchWeatherForLocation(int index) async {
    if (index < 0 || index >= _locations.length) return;
    _loading = true;
    _error = null;
    notifyListeners();

    final loc = _locations[index];
    try {
      // Use multi-source aggregator (Open-Meteo + Met Norway, median-blended).
      // WeatherService.fetch remains available as a single-source fallback inside the aggregator.
      final data = await WeatherAggregatorService.fetch(
        lat: (loc['lat'] as num).toDouble(),
        lon: (loc['lon'] as num).toDouble(),
      );
      _currentWeather = data;
      if (data == null) _error = 'Could not load weather. Check connection.';
    } catch (e) {
      debugPrint('WeatherProvider: fetch failed - $e');
      _error = 'Fetch failed: $e';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('custom_weather_locations');
    if (stored != null) {
      try {
        _locations = List<Map<String, dynamic>>.from(jsonDecode(stored));
        notifyListeners();
      } catch (e) {
        debugPrint('WeatherProvider: failed to load local locations - $e');
      }
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_weather_locations', jsonEncode(_locations));
  }

  Future<void> _loadFromSupabase() async {
    if (!kSupabaseAvailable || _currentUid == null) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await Supabase.instance.client
          .from('weather_locations')
          .select()
          .eq('user_id', _currentUid!);

      final remote = (res as List)
          .map((r) => {
                'id': r['id'],
                'name': r['name'],
                'lat': r['latitude'],
                'lon': r['longitude'],
              })
          .toList();

      if (remote.isNotEmpty) {
        _locations = remote;
        unawaited(_saveLocal()); // sync local cache
      }
    } catch (e) {
      debugPrint('WeatherProvider: failed to load from Supabase - $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> addLocation(String name, double lat, double lon) async {
    final newLoc = {'name': name, 'lat': lat, 'lon': lon};
    _locations.add(newLoc);
    notifyListeners();
    unawaited(_saveLocal());

    if (kSupabaseAvailable && _currentUid != null) {
      try {
        final res = await Supabase.instance.client
            .from('weather_locations')
            .insert({
              'user_id': _currentUid,
              'name': name,
              'latitude': lat,
              'longitude': lon,
            })
            .select()
            .single();
        // Update local with the remote ID
        newLoc['id'] = res['id'];
      } catch (e) {
        debugPrint('WeatherProvider: failed to save to Supabase - $e');
      }
    }
  }

  Future<void> removeLocation(int index) async {
    final removed = _locations.removeAt(index);
    notifyListeners();
    unawaited(_saveLocal());

    if (kSupabaseAvailable && _currentUid != null && removed['id'] != null) {
      try {
        await Supabase.instance.client
            .from('weather_locations')
            .delete()
            .eq('id', removed['id']);
      } catch (e) {
        debugPrint('WeatherProvider: failed to delete from Supabase - $e');
      }
    }
  }
}
