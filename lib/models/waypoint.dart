import 'package:latlong2/latlong.dart';
import 'weather_data.dart';
import 'marine_data.dart';

enum WaypointType { departure, waypoint, destination }

class Waypoint {
  final String id;
  final LatLng position;
  final WaypointType type;
  final String name;
  WeatherData? weatherData;
  MarineData? marineData;

  Waypoint({
    required this.id,
    required this.position,
    required this.type,
    this.name = '',
    this.weatherData,
    this.marineData,
  });

  String get displayName {
    if (name.isNotEmpty) return name;
    switch (type) {
      case WaypointType.departure:
        return '出発地';
      case WaypointType.waypoint:
        return '経由地';
      case WaypointType.destination:
        return '目的地';
    }
  }

  Waypoint copyWith({
    String? id,
    LatLng? position,
    WaypointType? type,
    String? name,
    WeatherData? weatherData,
    MarineData? marineData,
  }) {
    return Waypoint(
      id: id ?? this.id,
      position: position ?? this.position,
      type: type ?? this.type,
      name: name ?? this.name,
      weatherData: weatherData ?? this.weatherData,
      marineData: marineData ?? this.marineData,
    );
  }
}
