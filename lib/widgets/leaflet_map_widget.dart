import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import '../interop/leaflet_interop.dart';
import '../interop/leaflet_map_controller.dart';
import '../models/waypoint.dart';
import '../providers/navigation_provider.dart';
import 'weather_panel.dart';

class LeafletMapWidget extends StatefulWidget {
  const LeafletMapWidget({super.key});

  /// Access the controller from parent widgets via GlobalKey
  static LeafletMapController? controllerOf(BuildContext context) {
    final state = context.findAncestorStateOfType<LeafletMapWidgetState>();
    return state?.controller;
  }

  @override
  State<LeafletMapWidget> createState() => LeafletMapWidgetState();
}

class LeafletMapWidgetState extends State<LeafletMapWidget> {
  static const _viewType = 'leaflet-map-view';
  static bool _factoryRegistered = false;
  static const _containerId = 'leaflet-map-container';

  final LeafletMapController _controller = LeafletMapController();
  bool _mapReady = false;
  int _prevWaypointCount = 0;

  LeafletMapController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _registerFactory();
    _setupCallbacks();
  }

  void _registerFactory() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = _containerId;
      div.style.width = '100%';
      div.style.height = '100%';
      return div;
    });
  }

  void _setupCallbacks() {
    dartOnMapTap = ((JSNumber lat, JSNumber lng) {
      _onMapTap(lat.toDartDouble, lng.toDartDouble);
    }).toJS;

    dartOnMarkerTap = ((JSString id) {
      _onMarkerTap(id.toDart);
    }).toJS;
  }

  void _initMapDelayed() {
    if (_mapReady) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _controller.initMap(_containerId);
      if (mounted) {
        setState(() => _mapReady = true);
        _syncMapState();
      }
    });
  }

  void _syncMapState() {
    if (!_controller.isInitialized) return;
    final provider = context.read<NavigationProvider>();
    _controller.updateMarkers(provider);
    _controller.updateRoute(provider);

    // Auto-fit when waypoints change
    final currentCount = provider.allWaypoints.length;
    if (currentCount != _prevWaypointCount && currentCount > 0) {
      _controller.fitBounds(provider);
      _prevWaypointCount = currentCount;
    }
  }

  void _onMapTap(double lat, double lng) {
    if (!mounted) return;
    _showWaypointTypeDialog(lat, lng);
  }

  void _onMarkerTap(String id) {
    if (!mounted) return;
    final provider = context.read<NavigationProvider>();
    final allWaypoints = provider.allWaypoints;
    final wp = allWaypoints.where((w) => w.id == id).firstOrNull;
    if (wp != null) {
      _showMarkerActionDialog(wp);
    }
  }

  void _showMarkerActionDialog(Waypoint waypoint) {
    final provider = context.read<NavigationProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.15,
        minChildSize: 0.1,
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
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF00E5FF).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title + delete button row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            waypoint.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                          Text(
                            '${waypoint.position.latitude.toStringAsFixed(4)}, ${waypoint.position.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    // Weather button
                    IconButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showWeatherPanel(waypoint);
                      },
                      icon: const Icon(Icons.cloud, color: Color(0xFF00E5FF)),
                      tooltip: '天気情報',
                    ),
                    // Delete button
                    IconButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteWaypoint(provider, waypoint);
                      },
                      icon: const Icon(Icons.delete, color: Color(0xFFFF5252)),
                      tooltip: '削除',
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _deleteWaypoint(NavigationProvider provider, Waypoint waypoint) {
    if (waypoint.type == WaypointType.departure) {
      provider.removeDeparture();
    } else if (waypoint.type == WaypointType.destination) {
      provider.removeDestination();
    } else {
      final idx = provider.waypoints.indexWhere((w) => w.id == waypoint.id);
      if (idx >= 0) {
        provider.removeWaypoint(idx);
      }
    }
  }

  void _showWaypointTypeDialog(double lat, double lng) {
    final provider = context.read<NavigationProvider>();
    final position = LatLng(lat, lng);
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

  @override
  void dispose() {
    dartOnMapTap = null;
    dartOnMarkerTap = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, provider, child) {
        if (_mapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncMapState();
          });
        }
        return HtmlElementView(
          viewType: _viewType,
          onPlatformViewCreated: (_) => _initMapDelayed(),
        );
      },
    );
  }
}
