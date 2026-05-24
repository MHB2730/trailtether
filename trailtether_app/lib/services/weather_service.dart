import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'; // compute()

import '../models/weather.dart';

/// Fetches weather from Open-Meteo (free, no API key required).
/// https://open-meteo.com/
class WeatherService {
  static const String _base = 'https://api.open-meteo.com/v1/forecast';

  static Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.trim().length < 2) return [];
    final uri = Uri.parse('https://geocoding-api.open-meteo.com/v1/search')
        .replace(queryParameters: {
      'name': query.trim(),
      'count': '5',
      'language': 'en',
      'format': 'json'
    });
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 10));
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final body = await response.transform(utf8.decoder).join();

      final j = jsonDecode(body) as Map<String, dynamic>;
      if (j['results'] == null) return [];
      return (j['results'] as List).map((r) {
        String n = r['name'] as String;
        if (r['admin1'] != null) n += ', ${r['admin1']}';
        if (r['country'] != null) n += ', ${r['country']}';
        return {
          'name': n,
          'lat': (r['latitude'] as num).toDouble(),
          'lon': (r['longitude'] as num).toDouble(),
        };
      }).toList();
    } catch (_) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  static Future<WeatherData?> fetch({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': [
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'precipitation',
        'weather_code',
        'cloud_cover',
        'wind_speed_10m',
        'wind_direction_10m',
        'uv_index',
      ].join(','),
      'hourly': [
        'temperature_2m',
        'precipitation_probability',
        'precipitation',
        'weather_code',
        'wind_speed_10m',
        'visibility',
      ].join(','),
      'daily': [
        'weather_code',
        'temperature_2m_max',
        'temperature_2m_min',
        'precipitation_sum',
        'precipitation_probability_max',
        'wind_speed_10m_max',
        'uv_index_max',
        'sunrise',
        'sunset',
      ].join(','),
      'wind_speed_unit': 'kmh',
      'timezone': 'auto',
      'forecast_days': '7',
    });

    // Open-Meteo is the primary signal — if it doesn't return inside ~8s
    // there's something wrong with the network, not the API. Was 10s
    // connect + 10s req + 15s read (= up to 25s worst case). Tightened
    // to 5s + 4s + 6s (= 15s worst case) so the user sees data within
    // 2-3s in the common case and a "TAP TO RETRY" within 15s if the
    // connection is dead.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 4));
      final response =
          await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();

      // Parse JSON in a background isolate — keeps the UI thread free.
      return await compute(_parseBody, body);
    } catch (e) {
      debugPrint('WeatherService error: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // ── Parsing (top-level function so compute() can send it to an isolate) ────
  static WeatherData _parseBody(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return _parse(j);
  }

  static WeatherData _parse(Map<String, dynamic> j) {
    final cur = j['current'] as Map<String, dynamic>;
    final current = CurrentWeather(
      temperature: _toDouble(cur['temperature_2m']),
      feelsLike: _toDouble(cur['apparent_temperature']),
      humidity: _toInt(cur['relative_humidity_2m']),
      precipitation: _toDouble(cur['precipitation']),
      weatherCode: _toInt(cur['weather_code']),
      cloudCover: _toInt(cur['cloud_cover']),
      windSpeed: _toDouble(cur['wind_speed_10m']),
      windDirection: _toInt(cur['wind_direction_10m']),
      uvIndex: _toDouble(cur['uv_index']),
    );

    final d = j['daily'] as Map<String, dynamic>;
    final dates = (d['time'] as List).cast<String>();
    final daily = List.generate(dates.length, (i) {
      final sunrise = DateTime.parse((d['sunrise'] as List)[i] as String);
      final sunset = DateTime.parse((d['sunset'] as List)[i] as String);
      return DailyForecast(
        date: DateTime.parse(dates[i]),
        weatherCode: _toInt((d['weather_code'] as List)[i]),
        tempMax: _toDouble((d['temperature_2m_max'] as List)[i]),
        tempMin: _toDouble((d['temperature_2m_min'] as List)[i]),
        precipSum: _toDouble((d['precipitation_sum'] as List)[i]),
        precipProbability:
            _toInt((d['precipitation_probability_max'] as List)[i]),
        windSpeedMax: _toDouble((d['wind_speed_10m_max'] as List)[i]),
        uvIndexMax: _toDouble((d['uv_index_max'] as List)[i]),
        sunrise: sunrise,
        sunset: sunset,
      );
    });

    final h = j['hourly'] as Map<String, dynamic>;
    final times = (h['time'] as List).cast<String>();
    final hourly = List.generate(
        times.length,
        (i) => HourlySlice(
              time: DateTime.parse(times[i]),
              temperature: _toDouble((h['temperature_2m'] as List)[i]),
              precipProbability:
                  _toInt((h['precipitation_probability'] as List)[i]),
              precipitation: _toDouble((h['precipitation'] as List)[i]),
              weatherCode: _toInt((h['weather_code'] as List)[i]),
              windSpeed: _toDouble((h['wind_speed_10m'] as List)[i]),
              visibility: _toDouble((h['visibility'] as List)[i]),
            ));

    return WeatherData(
      fetchedAt: DateTime.now(),
      current: current,
      daily: daily,
      hourly: hourly,
    );
  }

  static double _toDouble(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
  static int _toInt(dynamic v) => v == null ? 0 : (v as num).toInt();
}
