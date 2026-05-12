import 'dart:io';
import 'dart:math' as math;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TrailUtils {
  static const _safeSchemes = {'tel', 'mailto', 'sms', 'https', 'http'};

  /// Launch a URL after validating its scheme. Drops `javascript:`,
  /// `data:`, `file:`, and any other potentially dangerous scheme.
  static Future<void> launchUrlSafe(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !_safeSchemes.contains(uri.scheme.toLowerCase())) {
      return;
    }
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Unique ID for this device (for incident tracking)
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      return windowsInfo.deviceId;
    }
    return 'unknown_platform';
  }

  /// Simplifies a list of LatLng points using the Douglas-Peucker algorithm.
  /// If [elevations] are provided, they must match [points] length and will be
  /// simplified in parallel (keeping the correct elevation for each kept point).
  static List<LatLng> simplifyPoints(List<LatLng> points,
      {double epsilon = 0.00005}) {
    if (points.length < 3) return points;

    final keptIndices = _douglasPeucker(points, 0, points.length - 1, epsilon);
    final sortedIndices = keptIndices.toList()..sort();

    return sortedIndices.map((i) => points[i]).toList();
  }

  /// Specialized version that also returns the simplified elevations.
  static (List<LatLng>, List<double>) simplifyPointsWithElevations(
      List<LatLng> points, List<double> elevations,
      {double epsilon = 0.00005}) {
    if (points.length < 3 || points.length != elevations.length) {
      return (points, elevations);
    }

    final keptIndices = _douglasPeucker(points, 0, points.length - 1, epsilon);
    final sortedIndices = keptIndices.toList()..sort();

    final resP = sortedIndices.map((i) => points[i]).toList();
    final resE = sortedIndices.map((i) => elevations[i]).toList();

    return (resP, resE);
  }

  static Set<int> _douglasPeucker(
      List<LatLng> points, int start, int end, double epsilon) {
    double dmax = 0;
    int index = -1;

    for (int i = start + 1; i < end; i++) {
      double d = _perpendicularDistance(points[i], points[start], points[end]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    if (dmax > epsilon) {
      final res1 = _douglasPeucker(points, start, index, epsilon);
      final res2 = _douglasPeucker(points, index, end, epsilon);
      return {...res1, ...res2};
    } else {
      return {start, end};
    }
  }

  static double _perpendicularDistance(LatLng p, LatLng p1, LatLng p2) {
    double x = p.latitude;
    double y = p.longitude;
    double x1 = p1.latitude;
    double y1 = p1.longitude;
    double x2 = p2.latitude;
    double y2 = p2.longitude;

    double numerator =
        ((y2 - y1) * x - (x2 - x1) * y + x2 * y1 - y2 * x1).abs();
    double denominator = math.sqrt(math.pow(y2 - y1, 2) + math.pow(x2 - x1, 2));

    if (denominator == 0) return 0.0;
    return numerator / denominator;
  }

  /// Returns a color based on speed (km/h) with smooth blending.
  static Color getSpeedColor(double speedKmh) {
    if (speedKmh < 1.5) {
      return Color.lerp(const Color(0xFFB71C1C), const Color(0xFFF44336),
          (speedKmh / 1.5).clamp(0.0, 1.0))!;
    } else if (speedKmh < 3.5) {
      return Color.lerp(const Color(0xFFF44336), const Color(0xFFFF9800),
          ((speedKmh - 1.5) / 2.0).clamp(0.0, 1.0))!;
    } else if (speedKmh < 5.5) {
      return Color.lerp(const Color(0xFFFF9800), const Color(0xFFFFEB3B),
          ((speedKmh - 3.5) / 2.0).clamp(0.0, 1.0))!;
    } else if (speedKmh < 8.0) {
      return Color.lerp(const Color(0xFFFFEB3B), const Color(0xFF4CAF50),
          ((speedKmh - 5.5) / 2.5).clamp(0.0, 1.0))!;
    } else {
      return Color.lerp(const Color(0xFF4CAF50), const Color(0xFF2196F3),
          ((speedKmh - 8.0) / 4.0).clamp(0.0, 1.0))!;
    }
  }

  /// Returns a hex string (e.g. #FF0000) for speed (km/h) for JS consumption.
  static String getSpeedColorHex(double speedKmh) {
    final c = getSpeedColor(speedKmh);
    return '#${c.value.toRadixString(16).substring(2).padLeft(6, '0')}';
  }
}
