class HourlyWeather {
  final DateTime time;
  final double temperature;
  final double precipitation;
  final int weatherCode;
  final double windSpeed;
  final double windDirection;

  HourlyWeather({
    required this.time,
    required this.temperature,
    required this.precipitation,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
  });

  String get weatherDescription => _wmoCodeToDescription(weatherCode);

  String get weatherIcon => _wmoCodeToIcon(weatherCode);

  static String _wmoCodeToDescription(int code) {
    switch (code) {
      case 0:
        return '快晴';
      case 1:
        return 'ほぼ晴れ';
      case 2:
        return '一部曇り';
      case 3:
        return '曇り';
      case 45:
      case 48:
        return '霧';
      case 51:
      case 53:
      case 55:
        return '霧雨';
      case 61:
      case 63:
      case 65:
        return '雨';
      case 71:
      case 73:
      case 75:
        return '雪';
      case 80:
      case 81:
      case 82:
        return 'にわか雨';
      case 95:
        return '雷雨';
      case 96:
      case 99:
        return '雷雨(雹)';
      default:
        return '不明';
    }
  }

  static String _wmoCodeToIcon(int code) {
    if (code == 0 || code == 1) return '☀️';
    if (code == 2) return '⛅';
    if (code == 3) return '☁️';
    if (code == 45 || code == 48) return '🌫️';
    if (code >= 51 && code <= 55) return '🌦️';
    if (code >= 61 && code <= 65) return '🌧️';
    if (code >= 71 && code <= 75) return '🌨️';
    if (code >= 80 && code <= 82) return '🌧️';
    if (code >= 95) return '⛈️';
    return '❓';
  }
}

class WeatherData {
  final double currentTemperature;
  final double currentPrecipitation;
  final int currentWeatherCode;
  final double currentWindSpeed;
  final double currentWindDirection;
  final List<HourlyWeather> hourlyForecast;
  final DateTime fetchedAt;

  WeatherData({
    required this.currentTemperature,
    required this.currentPrecipitation,
    required this.currentWeatherCode,
    required this.currentWindSpeed,
    required this.currentWindDirection,
    required this.hourlyForecast,
    required this.fetchedAt,
  });

  String get weatherDescription =>
      HourlyWeather._wmoCodeToDescription(currentWeatherCode);

  String get weatherIcon =>
      HourlyWeather._wmoCodeToIcon(currentWeatherCode);

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final temps = (hourly['temperature_2m'] as List).cast<num>();
    final precips = (hourly['precipitation'] as List).cast<num>();
    final codes = (hourly['weathercode'] as List).cast<num>();
    final winds = (hourly['windspeed_10m'] as List).cast<num>();
    final windDirs = (hourly['winddirection_10m'] as List).cast<num>();

    final now = DateTime.now();
    int currentIdx = 0;
    for (int i = 0; i < times.length; i++) {
      if (DateTime.parse(times[i]).isAfter(now)) {
        currentIdx = i > 0 ? i - 1 : 0;
        break;
      }
    }

    final hourlyList = <HourlyWeather>[];
    for (int i = 0; i < times.length; i++) {
      hourlyList.add(HourlyWeather(
        time: DateTime.parse(times[i]),
        temperature: temps[i].toDouble(),
        precipitation: precips[i].toDouble(),
        weatherCode: codes[i].toInt(),
        windSpeed: winds[i].toDouble(),
        windDirection: windDirs[i].toDouble(),
      ));
    }

    return WeatherData(
      currentTemperature: temps[currentIdx].toDouble(),
      currentPrecipitation: precips[currentIdx].toDouble(),
      currentWeatherCode: codes[currentIdx].toInt(),
      currentWindSpeed: winds[currentIdx].toDouble(),
      currentWindDirection: windDirs[currentIdx].toDouble(),
      hourlyForecast: hourlyList,
      fetchedAt: now,
    );
  }
}
