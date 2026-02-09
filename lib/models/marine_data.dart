class HourlyMarine {
  final DateTime time;
  final double waveHeight;
  final double windWaveHeight;
  final double swellWaveHeight;
  final double waveDirection;
  final double wavePeriod;
  final double seaSurfaceTemperature;

  HourlyMarine({
    required this.time,
    required this.waveHeight,
    required this.windWaveHeight,
    required this.swellWaveHeight,
    required this.waveDirection,
    required this.wavePeriod,
    required this.seaSurfaceTemperature,
  });
}

class MarineData {
  final double currentWaveHeight;
  final double currentWindWaveHeight;
  final double currentSwellWaveHeight;
  final double currentWaveDirection;
  final double currentWavePeriod;
  final double currentSeaSurfaceTemperature;
  final List<HourlyMarine> hourlyForecast;
  final DateTime fetchedAt;

  MarineData({
    required this.currentWaveHeight,
    required this.currentWindWaveHeight,
    required this.currentSwellWaveHeight,
    required this.currentWaveDirection,
    required this.currentWavePeriod,
    required this.currentSeaSurfaceTemperature,
    required this.hourlyForecast,
    required this.fetchedAt,
  });

  factory MarineData.fromJson(Map<String, dynamic> json) {
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final waveHeights = (hourly['wave_height'] as List).cast<num?>();
    final windWaveHeights = (hourly['wind_wave_height'] as List).cast<num?>();
    final swellWaveHeights =
        (hourly['swell_wave_height'] as List).cast<num?>();
    final waveDirections = (hourly['wave_direction'] as List).cast<num?>();
    final wavePeriods = (hourly['wave_period'] as List).cast<num?>();
    final seaTemps =
        (hourly['sea_surface_temperature'] as List?)?.cast<num?>() ??
            List.filled(times.length, null);

    final now = DateTime.now();
    int currentIdx = 0;
    for (int i = 0; i < times.length; i++) {
      if (DateTime.parse(times[i]).isAfter(now)) {
        currentIdx = i > 0 ? i - 1 : 0;
        break;
      }
    }

    final hourlyList = <HourlyMarine>[];
    for (int i = 0; i < times.length; i++) {
      hourlyList.add(HourlyMarine(
        time: DateTime.parse(times[i]),
        waveHeight: (waveHeights[i] ?? 0).toDouble(),
        windWaveHeight: (windWaveHeights[i] ?? 0).toDouble(),
        swellWaveHeight: (swellWaveHeights[i] ?? 0).toDouble(),
        waveDirection: (waveDirections[i] ?? 0).toDouble(),
        wavePeriod: (wavePeriods[i] ?? 0).toDouble(),
        seaSurfaceTemperature: (seaTemps[i] ?? 0).toDouble(),
      ));
    }

    return MarineData(
      currentWaveHeight: (waveHeights[currentIdx] ?? 0).toDouble(),
      currentWindWaveHeight: (windWaveHeights[currentIdx] ?? 0).toDouble(),
      currentSwellWaveHeight: (swellWaveHeights[currentIdx] ?? 0).toDouble(),
      currentWaveDirection: (waveDirections[currentIdx] ?? 0).toDouble(),
      currentWavePeriod: (wavePeriods[currentIdx] ?? 0).toDouble(),
      currentSeaSurfaceTemperature: (seaTemps[currentIdx] ?? 0).toDouble(),
      hourlyForecast: hourlyList,
      fetchedAt: now,
    );
  }
}
