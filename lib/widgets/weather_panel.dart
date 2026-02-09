import 'package:flutter/material.dart';
import '../models/waypoint.dart';
import '../models/weather_data.dart';
import '../models/marine_data.dart';

class WeatherPanel extends StatelessWidget {
  final Waypoint? waypoint;

  const WeatherPanel({super.key, this.waypoint});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1F3C),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  width: 0.5),
              left: BorderSide(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  width: 0.5),
              right: BorderSide(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  width: 0.5),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (waypoint != null) ...[
                _buildSingleWaypointWeather(waypoint!),
              ] else ...[
                const Center(
                    child: Text('地点を選択してください',
                        style: TextStyle(color: Colors.white54))),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleWaypointWeather(Waypoint wp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wp.displayName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00E5FF),
          ),
        ),
        Text(
          '${wp.position.latitude.toStringAsFixed(4)}, ${wp.position.longitude.toStringAsFixed(4)}',
          style: const TextStyle(fontSize: 12, color: Colors.white38),
        ),
        const SizedBox(height: 12),
        if (wp.weatherData != null) _buildWeatherCard(wp.weatherData!),
        if (wp.weatherData == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: const Center(
                child: Text('天気データ読み込み中...',
                    style: TextStyle(color: Colors.white54))),
          ),
        const SizedBox(height: 8),
        if (wp.marineData != null) _buildMarineCard(wp.marineData!),
        if (wp.marineData == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF0A1628), Color(0xFF0D2847)],
              ),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: const Center(
                child: Text('海洋データ読み込み中...',
                    style: TextStyle(color: Colors.white54))),
          ),
        const SizedBox(height: 12),
        if (wp.weatherData != null) _buildHourlyForecast(wp),
      ],
    );
  }

  Widget _buildWeatherCard(WeatherData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '天気',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00E5FF),
            ),
          ),
          Divider(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
          Row(
            children: [
              Text(
                data.weatherIcon,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.weatherDescription,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  Text(
                    '${data.currentTemperature.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.air, '風速',
              '${data.currentWindSpeed.toStringAsFixed(1)} km/h'),
          _infoRow(Icons.explore, '風向',
              '${data.currentWindDirection.toStringAsFixed(0)}°'),
          _infoRow(Icons.water_drop, '降水量',
              '${data.currentPrecipitation.toStringAsFixed(1)} mm'),
        ],
      ),
    );
  }

  Widget _buildMarineCard(MarineData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1628), Color(0xFF0D2847)],
        ),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '海洋気象',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00E5FF),
            ),
          ),
          Divider(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
          _infoRow(Icons.waves, '波高',
              '${data.currentWaveHeight.toStringAsFixed(1)} m'),
          _infoRow(Icons.waves, 'うねり高',
              '${data.currentSwellWaveHeight.toStringAsFixed(1)} m'),
          _infoRow(Icons.waves, '風浪高',
              '${data.currentWindWaveHeight.toStringAsFixed(1)} m'),
          _infoRow(Icons.timer, '波周期',
              '${data.currentWavePeriod.toStringAsFixed(1)} s'),
          _infoRow(Icons.navigation, '波向',
              '${data.currentWaveDirection.toStringAsFixed(0)}°'),
          _infoRow(Icons.thermostat, '海面温度',
              '${data.currentSeaSurfaceTemperature.toStringAsFixed(1)}°C'),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast(Waypoint wp) {
    final weatherHours = wp.weatherData?.hourlyForecast ?? [];
    final marineHours = wp.marineData?.hourlyForecast ?? [];
    final now = DateTime.now();

    // Show next 24 hours
    final futureWeather =
        weatherHours.where((h) => h.time.isAfter(now)).take(24).toList();

    if (futureWeather.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '時間別予報 (24時間)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00E5FF),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: futureWeather.length,
            itemBuilder: (context, index) {
              final w = futureWeather[index];
              // Find matching marine hour
              HourlyMarine? m;
              if (index < marineHours.length) {
                m = marineHours.firstWhere(
                  (mh) => mh.time == w.time,
                  orElse: () => marineHours[0],
                );
              }

              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${w.time.hour}:00',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                    if (w.time.hour == 0)
                      Text(
                        '${w.time.month}/${w.time.day}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white38),
                      ),
                    Text(w.weatherIcon,
                        style: const TextStyle(fontSize: 20)),
                    Text(
                      '${w.temperature.toStringAsFixed(0)}°',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.air,
                            size: 10, color: Colors.white38),
                        Text(
                          '${w.windSpeed.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white54),
                        ),
                      ],
                    ),
                    if (m != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.waves,
                              size: 10,
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.6)),
                          Text(
                            '${m.waveHeight.toStringAsFixed(1)}m',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00E5FF)),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.white)),
        ],
      ),
    );
  }
}
