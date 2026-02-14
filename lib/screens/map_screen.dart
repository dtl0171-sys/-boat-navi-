import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../models/waypoint.dart';
import '../providers/navigation_provider.dart';
import '../interop/leaflet_map_controller.dart';
import '../widgets/leaflet_map_widget.dart';
import '../widgets/html_overlay.dart';
import '../widgets/html_controls.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapKey = GlobalKey<LeafletMapWidgetState>();
  bool _seaMapEnabled = false;
  bool _gpsFollowEnabled = false;
  final _htmlControls = HtmlControls();

  LeafletMapController? get _mapController =>
      _mapKey.currentState?.controller;

  @override
  void initState() {
    super.initState();
    try {
      _htmlControls.init(
        onAisToggle: () {
          context.read<NavigationProvider>().toggleAis();
          _syncMap();
        },
        onSeaMapToggle: _toggleSeaMap,
        onAllWeather: _showAllWeather,
        onClearRoute: _showClearConfirm,
        onSettings: _openSettings,
        onGpsFollowToggle: _toggleGpsFollow,
        onSetDeparture: () {
          context
              .read<NavigationProvider>()
              .setDepartureFromCurrentPosition();
          _panToCurrentPosition();
          _syncMap();
        },
      );
    } catch (e) {
      print('HtmlControls.init error: $e');
    }
    try {
      _setupDomListeners();
    } catch (e) {
      print('setupDomListeners error: $e');
    }
  }

  /// Listen for map tap and marker tap events dispatched by leaflet_bridge.js.
  /// Uses DOM events instead of @JS callbacks to avoid dart2js $flags errors.
  void _setupDomListeners() {
    final syncEl = web.document.getElementById('boat-sync');
    if (syncEl == null) return;

    syncEl.addEventListener(
        'maptap',
        ((JSAny? e) {
          if (!mounted) return;
          final latStr = syncEl.getAttribute('data-tap-lat');
          final lngStr = syncEl.getAttribute('data-tap-lng');
          if (latStr == null || lngStr == null) return;
          final lat = double.tryParse(latStr);
          final lng = double.tryParse(lngStr);
          if (lat == null || lng == null) return;
          _onMapTap(lat, lng);
        }).toJS);

    syncEl.addEventListener(
        'markertap',
        ((JSAny? e) {
          if (!mounted) return;
          final id = syncEl.getAttribute('data-marker-id');
          if (id == null) return;
          _onMarkerTap(id);
        }).toJS);
  }

  @override
  void dispose() {
    _htmlControls.dispose();
    super.dispose();
  }

  /// Sync markers/route/bounds to JS via DOM attributes + custom event.
  /// Avoids dart2js @JS interop $flags issues entirely.
  void _syncMap() {
    try {
      final syncEl = web.document.getElementById('boat-sync');
      if (syncEl == null) {
        _showDebug('ERR: #boat-sync not found');
        return;
      }

      final provider = context.read<NavigationProvider>();

      // Build markers JSON
      final markers = <Map<String, dynamic>>[];
      final pos = provider.currentPosition;
      if (pos != null) {
        markers.add({
          'type': 'current',
          'lat': pos.latitude,
          'lng': pos.longitude,
          'label': '\u26F5',
        });
      }
      final dep = provider.departure;
      if (dep != null) {
        markers.add({
          'type': 'departure',
          'id': dep.id,
          'lat': dep.position.latitude,
          'lng': dep.position.longitude,
          'label': '\u25B6',
        });
      }
      for (int i = 0; i < provider.waypoints.length; i++) {
        final wp = provider.waypoints[i];
        markers.add({
          'type': 'waypoint',
          'id': wp.id,
          'lat': wp.position.latitude,
          'lng': wp.position.longitude,
          'label': '${i + 1}',
        });
      }
      final dest = provider.destination;
      if (dest != null) {
        markers.add({
          'type': 'destination',
          'id': dest.id,
          'lat': dest.position.latitude,
          'lng': dest.position.longitude,
          'label': '\u2691',
        });
      }
      if (provider.aisEnabled) {
        for (final v in provider.aisVessels) {
          markers.add({
            'type': 'ais',
            'lat': v.lat,
            'lng': v.lon,
            'cog': v.cog,
            'name': v.name,
            'mmsi': v.mmsi,
            'sog': v.sog,
          });
        }
      }

      // Set data as DOM attributes (plain strings, no dart2js wrapping)
      syncEl.setAttribute('data-markers', jsonEncode(markers));

      // Route + bounds
      final allWp = provider.allWaypoints;
      final points = allWp
          .map((wp) => [wp.position.latitude, wp.position.longitude])
          .toList();
      final pointsJson = jsonEncode(points);
      syncEl.setAttribute('data-route', pointsJson);
      syncEl.setAttribute('data-bounds',
          points.isNotEmpty ? pointsJson : '');

      // Dispatch custom event to trigger JS listener
      syncEl.dispatchEvent(web.Event('boatsync'));

      _showDebug('OK: ${markers.length} markers');
    } catch (e) {
      _showDebug('ERR: $e');
    }
  }

  void _showDebug(String msg) {
    try {
      final body = web.document.body;
      if (body == null) return;
      final existing = web.document.getElementById('sync-debug');
      if (existing != null) existing.remove();
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = 'sync-debug';
      div.style.cssText =
          'position:fixed;bottom:80px;left:10px;background:rgba(0,0,0,0.85);'
          'color:#0f0;padding:8px 14px;z-index:999999;font:12px monospace;'
          'border-radius:6px;border:1px solid #0f0;pointer-events:none;';
      div.textContent = msg;
      body.appendChild(div);
      Future.delayed(const Duration(seconds: 6), () {
        if (div.parentElement != null) div.remove();
      });
    } catch (_) {}
  }

  // --- Map tap → show HTML overlay for waypoint selection ---
  void _onMapTap(double lat, double lng) async {
    final result = await HtmlOverlay.showWaypointSelector(lat, lng);
    if (!mounted || result == null) return;
    final provider = context.read<NavigationProvider>();
    switch (result) {
      case 'departure':
        provider.setDeparture(LatLng(lat, lng));
      case 'waypoint':
        provider.addWaypoint(LatLng(lat, lng));
      case 'destination':
        provider.setDestination(LatLng(lat, lng));
    }
    // Directly sync map - don't rely on Consumer chain
    _syncMap();
  }

  // --- Marker tap → show HTML overlay for marker actions ---
  void _onMarkerTap(String id) async {
    final provider = context.read<NavigationProvider>();
    final wp = provider.allWaypoints.where((w) => w.id == id).firstOrNull;
    if (wp == null) return;
    final result = await HtmlOverlay.showMarkerAction(
      name: wp.displayName,
      lat: wp.position.latitude,
      lng: wp.position.longitude,
      weatherData: wp.weatherData,
      marineData: wp.marineData,
    );
    if (!mounted || result != 'delete') return;
    final current =
        provider.allWaypoints.where((w) => w.id == id).firstOrNull;
    if (current == null) return;
    if (current.type == WaypointType.departure) {
      provider.removeDeparture();
    } else if (current.type == WaypointType.destination) {
      provider.removeDestination();
    } else {
      final idx = provider.waypoints.indexWhere((w) => w.id == id);
      if (idx >= 0) provider.removeWaypoint(idx);
    }
    // Directly sync map after deletion
    _syncMap();
  }

  // --- Clear route confirmation ---
  void _showClearConfirm() async {
    final result = await HtmlOverlay.showClearConfirm();
    if (result && mounted) {
      context.read<NavigationProvider>().clearRoute();
      _syncMap();
    }
  }

  // --- All weather panel ---
  void _showAllWeather() async {
    final provider = context.read<NavigationProvider>();
    await HtmlOverlay.showAllWeather(provider.allWaypoints);
  }

  // --- Feature toggles ---
  void _toggleSeaMap() {
    setState(() => _seaMapEnabled = !_seaMapEnabled);
    _mapController?.toggleSeaMap(_seaMapEnabled);
  }

  void _toggleGpsFollow() {
    setState(() => _gpsFollowEnabled = !_gpsFollowEnabled);
    if (_gpsFollowEnabled) _panToCurrentPosition();
  }

  void _panToCurrentPosition() {
    final pos = context.read<NavigationProvider>().currentPosition;
    if (pos != null) {
      _mapController?.panTo(pos.latitude, pos.longitude);
    }
  }

  void _openSettings() async {
    _htmlControls.hide();
    await Navigator.pushNamed(context, '/settings');
    if (mounted) {
      _htmlControls.show();
      _syncMap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<NavigationProvider>(
        builder: (context, provider, child) {
          try {
            if (_gpsFollowEnabled && provider.currentPosition != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _panToCurrentPosition();
              });
            }

            _htmlControls.updateState(
              aisEnabled: provider.aisEnabled,
              aisLoading: provider.isLoadingAis,
              seaMapEnabled: _seaMapEnabled,
              weatherLoading: provider.isLoadingWeather,
              hasWaypoints: provider.allWaypoints.isNotEmpty,
              gpsFollowEnabled: _gpsFollowEnabled,
              hasGps: provider.currentPosition != null,
              hasDeparture: provider.departure != null,
              routeLegs: provider.routeLegs,
              totalDistanceKm: provider.totalDistanceKm,
              totalDurationText: provider.totalDurationText,
              boatSpeed: provider.boatSpeed,
              speedUnitLabel: provider.speedUnitLabel,
            );
          } catch (e) {
            print('Consumer builder error: $e');
          }

          return LeafletMapWidget(
            key: _mapKey,
          );
        },
      ),
    );
  }
}
