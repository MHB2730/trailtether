import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/weather.dart';
import 'weather_service.dart';
import 'logger_service.dart';

/// Aggregates weather observations from multiple free sources and returns a
/// consensus reading. Currently:
///  - Open-Meteo (primary; full hourly + daily forecast)
///  - Met Norway / api.met.no (secondary; current + short-range forecast)
///
/// The aggregator runs both fetches in parallel. The primary source defines the
/// shape of the [WeatherData] response (hourly/daily arrays) — secondary sources
/// are folded into the *current* reading via median/mean so a single misreading
/// can't poison the forecast.
class WeatherAggregatorService {
  static const _metNoBase =
      'https://api.met.no/weatherapi/locationforecast/2.0/compact';

  /// User-Agent is required by met.no's terms of service. Identify the app clearly.
  static const _userAgent =
      'Trailtether/2.0 (https://trailtether.app contact@hilltrek.co.za)';

  /// Fetch + aggregate. Falls back to the primary source alone if any
  /// secondary fetch fails — we never want a partial outage to leave the user
  /// without weather data on the trail.
  static Future<WeatherData?> fetch({
    required double lat,
    required double lon,
  }) async {
    final primaryFuture = WeatherService.fetch(lat: lat, lon: lon);
    final metNoFuture = _fetchMetNo(lat: lat, lon: lon);

    // Defensive outer timeout. The inner HTTP calls already cap connect /
    // close at 10-15s each, but a hung TLS handshake or DNS stall on the
    // platform side can occasionally slip past those — observed in the
    // wild as the Home tab "Fetching… CONNECTING TO STATIONS" spinner
    // sitting forever with no completion notification. 25s is a hard
    // ceiling for the combined fan-out; beyond that the user gets a
    // tappable retry instead of an infinite spinner.
    List<dynamic> results;
    try {
      results = await Future.wait([
        primaryFuture,
        metNoFuture,
      ]).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      LoggerService.error(
          'WEATHER', 'fetch timed out after 25s — both providers slow/blocked');
      return null;
    }

    final primary = results[0] as WeatherData?;
    final metNo = results[1] as _MetNoCurrent?;

    if (primary == null) return null;
    if (metNo == null) return primary; // graceful fallback

    final blended = CurrentWeather(
      temperature: _median([primary.current.temperature, metNo.temperature]),
      feelsLike: primary.current.feelsLike, // Met Norway doesn't expose this directly
      humidity: _medianInt([primary.current.humidity, metNo.humidity]),
      precipitation:
          _median([primary.current.precipitation, metNo.precipitation]),
      cloudCover: _medianInt([primary.current.cloudCover, metNo.cloudCover]),
      windSpeed: _median([primary.current.windSpeed, metNo.windSpeed]),
      windDirection:
          _medianInt([primary.current.windDirection, metNo.windDirection]),
      weatherCode: primary.current.weatherCode,
      uvIndex: primary.current.uvIndex,
    );

    LoggerService.log('WEATHER',
        'Blended current: temp ${primary.current.temperature}→${blended.temperature}°, wind ${primary.current.windSpeed}→${blended.windSpeed}km/h');

    return WeatherData(
      fetchedAt: DateTime.now(),
      current: blended,
      daily: primary.daily,
      hourly: primary.hourly,
    );
  }

  // ── Met Norway fetch ──────────────────────────────────────────────────────

  static Future<_MetNoCurrent?> _fetchMetNo({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(_metNoBase).replace(queryParameters: {
      'lat': lat.toStringAsFixed(4),
      'lon': lon.toStringAsFixed(4),
    });

    // Tight Met Norway budget. This source is the *secondary* signal —
    // the aggregator already returns Open-Meteo on its own if Met Norway
    // is null, so we'd rather give the user a fast Open-Meteo render
    // than wait up to 18s for a blended one. Was 8s connect + 10s read
    // (=18s worst case); now 3s + 4s (=7s) which keeps Met Norway
    // available when fast, drops it cleanly when slow.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 3));
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final response =
          await request.close().timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        debugPrint('met.no returned ${response.statusCode}');
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      final timeseries = (j['properties']?['timeseries'] as List?) ?? const [];
      if (timeseries.isEmpty) return null;

      final entry = timeseries.first as Map<String, dynamic>;
      final details =
          (entry['data']?['instant']?['details'] as Map<String, dynamic>?) ??
              const {};
      final nextHour =
          entry['data']?['next_1_hours']?['details'] as Map<String, dynamic>?;

      return _MetNoCurrent(
        temperature: _toDouble(details['air_temperature']),
        humidity: _toInt(details['relative_humidity']),
        precipitation:
            _toDouble(nextHour?['precipitation_amount']),
        cloudCover: _toInt(details['cloud_area_fraction']),
        windSpeed: _toDouble(details['wind_speed']) * 3.6, // m/s → km/h
        windDirection: _toInt(details['wind_from_direction']),
      );
    } catch (e) {
      debugPrint('met.no fetch failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double _median(List<double> values) {
    final cleaned = values.where((v) => v.isFinite).toList()..sort();
    if (cleaned.isEmpty) return 0.0;
    if (cleaned.length == 1) return cleaned.first;
    final mid = cleaned.length ~/ 2;
    if (cleaned.length.isOdd) return cleaned[mid];
    return (cleaned[mid - 1] + cleaned[mid]) / 2.0;
  }

  static int _medianInt(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  static double _toDouble(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : 0.0);
  static int _toInt(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : 0);
}

class _MetNoCurrent {
  final double temperature;
  final int humidity;
  final double precipitation;
  final int cloudCover;
  final double windSpeed;
  final int windDirection;

  const _MetNoCurrent({
    required this.temperature,
    required this.humidity,
    required this.precipitation,
    required this.cloudCover,
    required this.windSpeed,
    required this.windDirection,
  });
}
