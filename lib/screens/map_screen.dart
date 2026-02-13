import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
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
    _htmlControls.init(
      onAisToggle: () => context.read<NavigationProvider>().toggleAis(),
      onSeaMapToggle: _toggleSeaMap,
      onAllWeather: _showAllWeather,
      onClearRoute: _showClearConfirm,
      onSettings: _openSettings,
      onGpsFollowToggle: _toggleGpsFollow,
      onSetDeparture: () {
        context.read<NavigationProvider>().setDepartureFromCurrentPosition();
        _panToCurrentPosition();
      },
    );
  }

  @override
  void dispose() {
    _htmlControls.dispose();
    super.dispose();
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
  }

  // --- Clear route confirmation ---
  void _showClearConfirm() async {
    final result = await HtmlOverlay.showClearConfirm();
    if (result && mounted) {
      context.read<NavigationProvider>().clearRoute();
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
    if (mounted) _htmlControls.show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<NavigationProvider>(
        builder: (context, provider, child) {
          if (_gpsFollowEnabled && provider.currentPosition != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _panToCurrentPosition();
            });
          }

          // Update HTML controls with current provider state
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

          return LeafletMapWidget(
            key: _mapKey,
            onMapTap: _onMapTap,
            onMarkerTap: _onMarkerTap,
          );
        },
      ),
    );
  }
}
