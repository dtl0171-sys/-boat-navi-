import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/weather_data.dart';
import '../models/marine_data.dart';

class WeatherService {
  final Map<String, _CacheEntry> _cache = {};
  static const _cacheDuration = Duration(minutes: 30);

  String _cacheKey(String type, double lat, double lon) =>
      '$type:${lat.toStringAsFixed(2)}:${lon.toStringAsFixed(2)}';

  bool _isCacheValid(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    return DateTime.now().difference(entry.timestamp) < _cacheDuration;
  }

  Future<WeatherData?> fetchWeather(LatLng position) async {
    final key = _cacheKey('weather', position.latitude, position.longitude);
    if (_isCacheValid(key)) {
      return _cache[key]!.data as WeatherData;
    }

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&hourly=temperature_2m,precipitation,weathercode,windspeed_10m,winddirection_10m'
        '&timezone=auto'
        '&forecast_days=3',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = WeatherData.fromJson(json);
      _cache[key] = _CacheEntry(data: data, timestamp: DateTime.now());
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<MarineData?> fetchMarine(LatLng position) async {
    final key = _cacheKey('marine', position.latitude, position.longitude);
    if (_isCacheValid(key)) {
      return _cache[key]!.data as MarineData;
    }

    try {
      final url = Uri.parse(
        'https://marine-api.open-meteo.com/v1/marine'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&hourly=wave_height,wind_wave_height,swell_wave_height,wave_direction,wave_period,sea_surface_temperature'
        '&timezone=auto'
        '&forecast_days=3',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = MarineData.fromJson(json);
      _cache[key] = _CacheEntry(data: data, timestamp: DateTime.now());
      return data;
    } catch (e) {
      return null;
    }
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  _CacheEntry({required this.data, required this.timestamp});
}
