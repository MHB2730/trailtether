/// A simple Kalman Filter for 2D coordinates (lat/lon) to smooth GPS jitter.
class KalmanFilter {
  final double processNoise; // Q
  final double measurementNoise; // R

  double? _lat;
  double? _lon;
  double _variance = -1.0; // P

  KalmanFilter({
    this.processNoise = 0.000001,
    this.measurementNoise = 0.00001,
  });

  /// Processes a new coordinate and returns the smoothed version.
  /// Pass-through for NaN/Infinity inputs so the filter state never poisons.
  (double, double) process(double lat, double lon) {
    if (lat.isNaN || lon.isNaN || lat.isInfinite || lon.isInfinite) {
      return (lat, lon);
    }

    if (_lat == null || _lon == null) {
      _lat = lat;
      _lon = lon;
      _variance = 1.0;
      return (lat, lon);
    }

    // Prediction step
    _variance += processNoise;

    // Kalman Gain
    double k = _variance / (_variance + measurementNoise);

    // Update step
    _lat = _lat! + k * (lat - _lat!);
    _lon = _lon! + k * (lon - _lon!);
    _variance = (1 - k) * _variance;

    return (_lat!, _lon!);
  }

  void reset() {
    _lat = null;
    _lon = null;
    _variance = -1.0;
  }
}
