import 'waypoint.dart';

class RouteLeg {
  final Waypoint from;
  final Waypoint to;
  final double distanceKm;
  final double durationMinutes;
  final double bearingDeg;

  RouteLeg({
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.durationMinutes,
    required this.bearingDeg,
  });

  String get distanceText => '${distanceKm.toStringAsFixed(1)} km';

  String get durationText {
    final hours = durationMinutes ~/ 60;
    final mins = (durationMinutes % 60).round();
    if (hours > 0) {
      return '$hours時間${mins}分';
    }
    return '$mins分';
  }
}
