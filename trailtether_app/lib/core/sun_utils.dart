import 'dart:math';

class SunUtils {
  /// Simple sunrise/sunset algorithm based on date, lat, lon.
  /// Returns { 'sunrise': DateTime, 'sunset': DateTime }
  static Map<String, DateTime?> calculate(
      DateTime date, double lat, double lon) {
    // ── Pre-calculate values ──────────────────────────────────────────────────
    final year = date.year;
    final month = date.month;
    final day = date.day;

    const pi = 3.14159265;
    double rad(double d) => d * pi / 180;
    double deg(double r) => r * 180 / pi;

    // 1. Calculate the day of the year
    final n1 = (275 * month / 9).floor();
    final n2 = ((month + 9) / 12).floor();
    final n3 = (1 + ((year - 4 * (year / 4).floor() + 2) / 3).floor());
    final dayOfYear = n1 - (n2 * n3) + day - 30;

    // 2. Convert longitude to hour value and estimate fraction of day
    final lonHour = lon / 15.0;

    // Rising:
    final tRise = dayOfYear + ((6.0 - lonHour) / 24.0);
    // Setting:
    final tSet = dayOfYear + ((18.0 - lonHour) / 24.0);

    DateTime? calc(double t, bool isRise) {
      // 3. Calculate Sun's mean anomaly
      final m = (0.9856 * t) - 3.2891;

      // 4. Calculate Sun's true longitude
      var l = m + (1.916 * sin(rad(m))) + (0.020 * sin(rad(2 * m))) + 282.634;
      l = (l % 360 + 360) % 360;

      // 5. Calculate Sun's right ascension
      var ra = deg(atan(0.91764 * tan(rad(l))));
      ra = (ra % 360 + 360) % 360;

      // Adjust RA to be in the same quadrant as L
      final lQuad = (l / 90).floor() * 90;
      final raQuad = (ra / 90).floor() * 90;
      ra = ra + (lQuad - raQuad);
      ra = ra / 15.0; // convert to hours

      // 6. Calculate Sun's declination
      final sinDec = 0.39782 * sin(rad(l));
      final cosDec = cos(asin(sinDec));

      // 7. Calculate Sun's local hour angle
      // 90.8333 is standard for zenith
      final cosH = (cos(rad(90.8333)) - (sinDec * sin(rad(lat)))) /
          (cosDec * cos(rad(lat)));

      if (cosH > 1) return null; // Sun never rises
      if (cosH < -1) return null; // Sun never sets

      // 8. Calculate local mean time
      var h = isRise ? 360 - deg(acos(cosH)) : deg(acos(cosH));
      h = h / 15.0;

      final meanT = h + ra - (0.06571 * t) - 6.622;

      // 9. Convert to UTC
      var utcT = meanT - lonHour;
      utcT = (utcT % 24 + 24) % 24;

      final hour = utcT.floor();
      final min = ((utcT - hour) * 60).floor();
      final sec = (((utcT - hour) * 60 - min) * 60).floor();

      return DateTime.utc(year, month, day, hour, min, sec).toLocal();
    }

    return {
      'sunrise': calc(tRise, true),
      'sunset': calc(tSet, false),
    };
  }

  static String formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '0m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
