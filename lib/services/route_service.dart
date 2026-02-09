import 'package:latlong2/latlong.dart';
import '../models/waypoint.dart';
import '../models/route_leg.dart';

enum SpeedUnit { knots, kmh }

class RouteService {
  static const _distance = Distance();

  double calculateDistanceKm(LatLng from, LatLng to) {
    return _distance.as(LengthUnit.Kilometer, from, to);
  }

  double calculateBearing(LatLng from, LatLng to) {
    return _distance.bearing(from, to);
  }

  double calculateDurationMinutes(
      double distanceKm, double speed, SpeedUnit unit) {
    if (speed <= 0) return double.infinity;
    final speedKmh =
        unit == SpeedUnit.knots ? speed * 1.852 : speed;
    return (distanceKm / speedKmh) * 60;
  }

  List<RouteLeg> calculateRoute(
      List<Waypoint> waypoints, double speed, SpeedUnit unit) {
    if (waypoints.length < 2) return [];

    final legs = <RouteLeg>[];
    for (int i = 0; i < waypoints.length - 1; i++) {
      final from = waypoints[i];
      final to = waypoints[i + 1];
      final distanceKm = calculateDistanceKm(from.position, to.position);
      final durationMinutes =
          calculateDurationMinutes(distanceKm, speed, unit);
      final bearing = calculateBearing(from.position, to.position);

      legs.add(RouteLeg(
        from: from,
        to: to,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        bearingDeg: bearing,
      ));
    }
    return legs;
  }

  double totalDistanceKm(List<RouteLeg> legs) {
    return legs.fold(0.0, (sum, leg) => sum + leg.distanceKm);
  }

  double totalDurationMinutes(List<RouteLeg> legs) {
    return legs.fold(0.0, (sum, leg) => sum + leg.durationMinutes);
  }
}
