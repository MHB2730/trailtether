class CurrentWeather {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double precipitation;
  final int cloudCover;
  final double windSpeed;
  final int windDirection;
  final int weatherCode;
  final double uvIndex;

  const CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.precipitation,
    required this.cloudCover,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    required this.uvIndex,
  });
}

class DailyForecast {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final double precipSum;
  final int precipProbability;
  final double windSpeedMax;
  final int weatherCode;
  final double uvIndexMax;
  final DateTime sunrise;
  final DateTime sunset;

  const DailyForecast({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.precipSum,
    required this.precipProbability,
    required this.windSpeedMax,
    required this.weatherCode,
    required this.uvIndexMax,
    required this.sunrise,
    required this.sunset,
  });

  Duration get daylightHours => sunset.difference(sunrise);

  HikingCondition get hikingCondition {
    if (weatherCode >= 95 ||
        windSpeedMax > 65 ||
        precipProbability > 70 ||
        precipSum > 12 ||
        tempMin < -5 ||
        tempMax > 36) {
      return HikingCondition.bad;
    }

    if (windSpeedMax > 40 ||
        precipProbability > 40 ||
        precipSum > 4 ||
        tempMin < 2 ||
        tempMax > 30) {
      return HikingCondition.caution;
    }

    return HikingCondition.good;
  }
}

class HourlySlice {
  final DateTime time;
  final double temperature;
  final int precipProbability;
  final double precipitation;
  final int weatherCode;
  final double windSpeed;
  final double visibility;

  const HourlySlice({
    required this.time,
    required this.temperature,
    required this.precipProbability,
    required this.precipitation,
    required this.weatherCode,
    required this.windSpeed,
    required this.visibility,
  });
}

class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> daily;
  final List<HourlySlice> hourly;
  final DateTime fetchedAt;

  const WeatherData({
    required this.current,
    required this.daily,
    required this.hourly,
    required this.fetchedAt,
  });

  List<HourlySlice> hoursForDay(int dayIndex) {
    if (dayIndex < 0 || dayIndex >= daily.length) {
      return const [];
    }

    final start = daily[dayIndex].date;
    return hourly
        .where((h) =>
            h.time.year == start.year &&
            h.time.month == start.month &&
            h.time.day == start.day)
        .toList();
  }
}

// Helpers

/// WMO weather code -> emoji icon
String weatherEmoji(int code) {
  if (code == 0) return '☀️';
  if (code <= 2) return '🌤';
  if (code == 3) return '☁️';
  if (code <= 48) return '🌫';
  if (code <= 55) return '🌦';
  if (code <= 57) return '🌨';
  if (code <= 65) return '🌧';
  if (code <= 67) return '🌨';
  if (code <= 77) return '❄️';
  if (code <= 82) return '🌦';
  if (code <= 86) return '❄️';
  if (code <= 99) return '⛈';
  return '🌡';
}

/// WMO weather code -> short text
String weatherDescription(int code) {
  if (code == 0) return 'Clear sky';
  if (code == 1) return 'Mainly clear';
  if (code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45) return 'Fog';
  if (code == 48) return 'Icy fog';
  if (code <= 55) return 'Drizzle';
  if (code <= 57) return 'Freezing drizzle';
  if (code <= 65) return 'Rain';
  if (code <= 67) return 'Freezing rain';
  if (code <= 77) return 'Snow';
  if (code <= 82) return 'Rain showers';
  if (code <= 86) return 'Snow showers';
  if (code == 95) return 'Thunderstorm';
  if (code <= 99) return 'Thunderstorm + hail';
  return 'Unknown';
}

enum HikingCondition { good, caution, bad }

extension HikingConditionX on HikingCondition {
  String get label {
    switch (this) {
      case HikingCondition.good:
        return 'Good';
      case HikingCondition.caution:
        return 'Caution';
      case HikingCondition.bad:
        return 'Bad';
    }
  }

  String get emoji {
    switch (this) {
      case HikingCondition.good:
        return '✅';
      case HikingCondition.caution:
        return '⚠️';
      case HikingCondition.bad:
        return '⛔';
    }
  }
}
