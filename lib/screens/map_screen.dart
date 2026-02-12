import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import '../models/waypoint.dart';
import '../providers/navigation_provider.dart';
import '../interop/leaflet_map_controller.dart';
import '../widgets/leaflet_map_widget.dart';
import '../widgets/route_info_bar.dart';
import '../widgets/html_overlay.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapKey = GlobalKey<LeafletMapWidgetState>();
  bool _seaMapEnabled = false;
  bool _gpsFollowEnabled = false;

  LeafletMapController? get _mapController =>
      _mapKey.currentState?.controller;

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
    // Re-read the waypoint in case state changed
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: Leaflet map
          Consumer<NavigationProvider>(
            builder: (context, provider, child) {
              if (_gpsFollowEnabled && provider.currentPosition != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _panToCurrentPosition();
                });
              }
              return LeafletMapWidget(
                key: _mapKey,
                onMapTap: _onMapTap,
                onMarkerTap: _onMarkerTap,
              );
            },
          ),

          // Layer 2: Map controls
          _buildTitlePanel(),
          _buildControlPanel(),
          _buildGpsButtons(),
          _buildRouteInfoBar(),
        ],
      ),
    );
  }

  // --- Title panel (top-left) ---
  Widget _buildTitlePanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      child: PointerInterceptor(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: _panelDecoration(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sailing, color: Color(0xFF00E5FF), size: 20),
              SizedBox(width: 6),
              Text(
                'Boat Navi',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Control panel (top-right) ---
  Widget _buildControlPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 12,
      child: PointerInterceptor(
        child: Consumer<NavigationProvider>(
          builder: (context, provider, _) {
            return Container(
              decoration: _panelDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ControlButton(
                    icon: Icons.directions_boat,
                    tooltip: 'AIS船舶表示',
                    isActive: provider.aisEnabled,
                    isLoading: provider.isLoadingAis,
                    onPressed: () => provider.toggleAis(),
                    isTop: true,
                  ),
                  _divider(),
                  _ControlButton(
                    icon: Icons.map,
                    tooltip: '海図表示',
                    isActive: _seaMapEnabled,
                    onPressed: _toggleSeaMap,
                  ),
                  _divider(),
                  _ControlButton(
                    icon: Icons.wb_sunny,
                    tooltip: '全地点の天気',
                    isActive: false,
                    isLoading: provider.isLoadingWeather,
                    isVisible: provider.allWaypoints.isNotEmpty,
                    onPressed: _showAllWeather,
                  ),
                  if (provider.allWaypoints.isNotEmpty) _divider(),
                  _ControlButton(
                    icon: Icons.delete_sweep,
                    tooltip: 'ルートクリア',
                    isActive: false,
                    isVisible: provider.allWaypoints.isNotEmpty,
                    onPressed: _showClearConfirm,
                  ),
                  if (provider.allWaypoints.isNotEmpty) _divider(),
                  _ControlButton(
                    icon: Icons.settings,
                    tooltip: '設定',
                    isActive: false,
                    onPressed: () =>
                        Navigator.pushNamed(context, '/settings'),
                    isBottom: true,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- GPS buttons (bottom-right) ---
  Widget _buildGpsButtons() {
    return Positioned(
      bottom: 100,
      right: 12,
      child: PointerInterceptor(
        child: Consumer<NavigationProvider>(
          builder: (context, provider, _) {
            if (provider.currentPosition == null) {
              return const SizedBox.shrink();
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _gpsFab(
                  heroTag: 'gpsFollow',
                  onPressed: _toggleGpsFollow,
                  isActive: _gpsFollowEnabled,
                  icon: _gpsFollowEnabled
                      ? Icons.gps_fixed
                      : Icons.gps_not_fixed,
                ),
                const SizedBox(height: 8),
                if (provider.departure == null)
                  _gpsFab(
                    heroTag: 'currentLoc',
                    onPressed: () {
                      provider.setDepartureFromCurrentPosition();
                      _panToCurrentPosition();
                    },
                    isActive: false,
                    icon: Icons.my_location,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _gpsFab({
    required String heroTag,
    required VoidCallback onPressed,
    required bool isActive,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: FloatingActionButton.small(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor:
            isActive ? const Color(0xFF00E5FF) : const Color(0xFF0D1F3C),
        foregroundColor:
            isActive ? const Color(0xFF0D1F3C) : const Color(0xFF00E5FF),
        shape: CircleBorder(
          side: BorderSide(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
          ),
        ),
        child: Icon(icon),
      ),
    );
  }

  // --- Route info bar (bottom) ---
  Widget _buildRouteInfoBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: PointerInterceptor(child: const RouteInfoBar()),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: const Color(0xDD0D1F3C),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
          blurRadius: 8,
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 28,
      height: 0.5,
      color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
    );
  }
}

// --- Control button widget ---
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final bool isLoading;
  final bool isVisible;
  final bool isTop;
  final bool isBottom;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    this.isLoading = false,
    this.isVisible = true,
    this.isTop = false,
    this.isBottom = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(12) : Radius.zero,
          bottom: isBottom ? const Radius.circular(12) : Radius.zero,
        ),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00E5FF),
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: isActive
                        ? const Color(0xFF00E5FF)
                        : Colors.white70,
                  ),
          ),
        ),
      ),
    );
  }
}
