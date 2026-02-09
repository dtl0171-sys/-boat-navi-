import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ais_vessel.dart';

class AisService {
  static const String _baseUrl =
      'https://meri.digitraffic.fi/api/ais/v1/locations';

  List<AisVessel> _cachedVessels = [];
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(seconds: 60);

  bool get _isCacheValid =>
      _lastFetchTime != null &&
      DateTime.now().difference(_lastFetchTime!) < _cacheDuration;

  Future<List<AisVessel>> fetchVessels() async {
    if (_isCacheValid && _cachedVessels.isNotEmpty) {
      return _cachedVessels;
    }

    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Accept': 'application/json',
          'Digitraffic-User': 'boat_navi_app',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];

        _cachedVessels = features.map((feature) {
          final props = feature['properties'] as Map<String, dynamic>? ?? {};
          final geometry =
              feature['geometry'] as Map<String, dynamic>? ?? {};
          final coordinates =
              geometry['coordinates'] as List<dynamic>? ?? [0.0, 0.0];

          return AisVessel.fromJson({
            'mmsi': props['mmsi'],
            'name': props['name'] ?? 'Unknown',
            'lon': coordinates.isNotEmpty ? coordinates[0] : 0.0,
            'lat': coordinates.length > 1 ? coordinates[1] : 0.0,
            'sog': props['sog'],
            'cog': props['cog'],
            'shipType': props['shipType'] ?? 0,
            'timestamp': props['timestampExternal'],
          });
        }).toList();

        _lastFetchTime = DateTime.now();
        return _cachedVessels;
      }
    } catch (e) {
      // Return cached data on error if available
      if (_cachedVessels.isNotEmpty) return _cachedVessels;
    }

    return [];
  }

  void clearCache() {
    _cachedVessels = [];
    _lastFetchTime = null;
  }
}
