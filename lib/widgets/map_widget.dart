import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/waypoint.dart';
import '../models/ais_vessel.dart';
import '../providers/navigation_provider.dart';
import 'weather_panel.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    _showWaypointTypeDialog(position);
  }

  void _showWaypointTypeDialog(LatLng position) {
    final provider = context.read<NavigationProvider>();
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF0D1F3C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 0.5),
        ),
        title: const Text(
          '地点を設定',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              provider.setDeparture(position);
              Navigator.pop(ctx);
            },
            child: const Row(
              children: [
                Icon(Icons.play_circle, color: Color(0xFF00E676)),
                SizedBox(width: 8),
                Text('出発地', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              provider.addWaypoint(position);
              Navigator.pop(ctx);
            },
            child: const Row(
              children: [
                Icon(Icons.circle, color: Color(0xFFFF9100)),
                SizedBox(width: 8),
                Text('経由地', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              provider.setDestination(position);
              Navigator.pop(ctx);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: Color(0xFFFF5252)),
                SizedBox(width: 8),
                Text('目的地', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWeatherPanel(Waypoint waypoint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WeatherPanel(waypoint: waypoint),
    );
  }

  List<Marker> _buildMarkers(NavigationProvider provider) {
    final markers = <Marker>[];

    // Current position marker
    if (provider.currentPosition != null) {
      markers.add(Marker(
        point: provider.currentPosition!,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.sailing, color: Colors.white, size: 24),
        ),
      ));
    }

    // Departure marker
    if (provider.departure != null) {
      markers.add(Marker(
        point: provider.departure!.position,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showWeatherPanel(provider.departure!),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF00E676), Color(0xFF00C853)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E676).withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
          ),
        ),
      ));
    }

    // Waypoint markers
    for (int i = 0; i < provider.waypoints.length; i++) {
      final wp = provider.waypoints[i];
      markers.add(Marker(
        point: wp.position,
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showWeatherPanel(wp),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFF9100), Color(0xFFFF6D00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9100).withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ));
    }

    // Destination marker
    if (provider.destination != null) {
      markers.add(Marker(
        point: provider.destination!.position,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showWeatherPanel(provider.destination!),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFF5252), Color(0xFFD50000)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.flag, color: Colors.white, size: 24),
          ),
        ),
      ));
    }

    // AIS vessel markers
    if (provider.aisEnabled) {
      for (final vessel in provider.aisVessels) {
        markers.add(_buildAisMarker(vessel));
      }
    }

    return markers;
  }

  Marker _buildAisMarker(AisVessel vessel) {
    return Marker(
      point: LatLng(vessel.lat, vessel.lon),
      width: 28,
      height: 28,
      child: Tooltip(
        message: '${vessel.name}\nMMSI: ${vessel.mmsi}\nSOG: ${vessel.sog.toStringAsFixed(1)} kt',
        child: Transform.rotate(
          angle: vessel.cog * (math.pi / 180),
          child: CustomPaint(
            size: const Size(28, 28),
            painter: _AisTrianglePainter(),
          ),
        ),
      ),
    );
  }

  List<LatLng> _buildRoutePoints(NavigationProvider provider) {
    final all = provider.allWaypoints;
    return all.map((wp) => wp.position).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, provider, child) {
        final routePoints = _buildRoutePoints(provider);

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(35.4, 136.0),
            initialZoom: 6,
            onTap: _onMapTap,
          ),
          children: [
            // OpenStreetMap base layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.boat_navi',
            ),
            // OpenSeaMap overlay
            TileLayer(
              urlTemplate:
                  'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.boat_navi',
            ),
            // Route glow line (shadow)
            if (routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 8.0,
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                  ),
                ],
              ),
            // Route main line
            if (routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 3.0,
                    color: const Color(0xFF00E5FF),
                  ),
                ],
              ),
            // Markers
            MarkerLayer(markers: _buildMarkers(provider)),
          ],
        );
      },
    );
  }
}

class _AisTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = ui.Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width * 0.8, size.height * 0.85);
    path.lineTo(size.width / 2, size.height * 0.65);
    path.lineTo(size.width * 0.2, size.height * 0.85);
    path.close();

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
