import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import '../models/waypoint.dart';
import '../models/weather_data.dart';
import '../models/marine_data.dart';
import '../providers/navigation_provider.dart';
import '../interop/leaflet_map_controller.dart';
import '../widgets/leaflet_map_widget.dart';
import '../widgets/route_info_bar.dart';
import '../widgets/weather_panel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapKey = GlobalKey<LeafletMapWidgetState>();
  bool _seaMapEnabled = false;
  bool _gpsFollowEnabled = false;

  // Overlay states
  LatLng? _pendingTapPosition;
  Waypoint? _activeWaypoint;
  bool _showClearConfirm = false;
  bool _showAllWeather = false;

  // --- Map controller access via GlobalKey ---
  LeafletMapController? get _mapController =>
      _mapKey.currentState?.controller;

  // --- Map visibility helper ---
  void _hideMap() {
    _mapController?.setMapHidden(true);
  }

  void _showMap() {
    _mapController?.setMapHidden(false);
  }

  // --- Map tap handler ---
  void _onMapTap(double lat, double lng) {
    setState(() {
      _pendingTapPosition = LatLng(lat, lng);
      _activeWaypoint = null;
      _showClearConfirm = false;
      _showAllWeather = false;
    });
    _hideMap();
  }

  // --- Marker tap handler ---
  void _onMarkerTap(String id) {
    final provider = context.read<NavigationProvider>();
    final wp = provider.allWaypoints.where((w) => w.id == id).firstOrNull;
    if (wp != null) {
      setState(() {
        _activeWaypoint = wp;
        _pendingTapPosition = null;
        _showClearConfirm = false;
        _showAllWeather = false;
      });
      _hideMap();
    }
  }

  void _dismissOverlay() {
    setState(() {
      _pendingTapPosition = null;
      _activeWaypoint = null;
      _showClearConfirm = false;
      _showAllWeather = false;
    });
    _showMap();
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

  // --- Waypoint actions ---
  void _setDeparture(LatLng position) {
    context.read<NavigationProvider>().setDeparture(position);
    _dismissOverlay();
  }

  void _addWaypoint(LatLng position) {
    context.read<NavigationProvider>().addWaypoint(position);
    _dismissOverlay();
  }

  void _setDestination(LatLng position) {
    context.read<NavigationProvider>().setDestination(position);
    _dismissOverlay();
  }

  void _deleteWaypoint(Waypoint wp) {
    final provider = context.read<NavigationProvider>();
    if (wp.type == WaypointType.departure) {
      provider.removeDeparture();
    } else if (wp.type == WaypointType.destination) {
      provider.removeDestination();
    } else {
      final idx = provider.waypoints.indexWhere((w) => w.id == wp.id);
      if (idx >= 0) provider.removeWaypoint(idx);
    }
    _dismissOverlay();
  }

  void _clearRoute() {
    context.read<NavigationProvider>().clearRoute();
    _dismissOverlay();
  }

  bool get _hasOverlay =>
      _pendingTapPosition != null ||
      _activeWaypoint != null ||
      _showClearConfirm ||
      _showAllWeather;

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

          // Layer 2: Map controls (always visible)
          if (!_hasOverlay) ...[
            _buildTitlePanel(),
            _buildControlPanel(),
            _buildGpsButtons(),
            _buildRouteInfoBar(),
          ],

          // Layer 3: Overlay panels (above map via PointerInterceptor)
          if (_pendingTapPosition != null) _buildWaypointSelector(),
          if (_activeWaypoint != null) _buildMarkerActionPanel(),
          if (_showClearConfirm) _buildClearConfirmPanel(),
          if (_showAllWeather) _buildAllWeatherPanel(),
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
                    onPressed: () {
                      setState(() {
                        _showAllWeather = true;
                      });
                      _hideMap();
                    },
                  ),
                  if (provider.allWaypoints.isNotEmpty) _divider(),
                  _ControlButton(
                    icon: Icons.delete_sweep,
                    tooltip: 'ルートクリア',
                    isActive: false,
                    isVisible: provider.allWaypoints.isNotEmpty,
                    onPressed: () {
                      setState(() {
                        _showClearConfirm = true;
                      });
                      _hideMap();
                    },
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

  // =============================================
  // OVERLAY PANELS (shown ABOVE map via PointerInterceptor)
  // =============================================

  /// Full-screen backdrop that dismisses overlay on tap
  Widget _backdrop() {
    return Positioned.fill(
      child: PointerInterceptor(
        child: GestureDetector(
          onTap: _dismissOverlay,
          child: Container(color: const Color(0xAA0A1628)),
        ),
      ),
    );
  }

  // --- Waypoint type selector (on map tap) ---
  Widget _buildWaypointSelector() {
    final pos = _pendingTapPosition!;
    return Stack(
      children: [
        _backdrop(),
        Center(
          child: PointerInterceptor(
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1F3C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '地点を設定',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                  Text(
                    '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(height: 16),
                  _selectorOption(
                    Icons.play_circle,
                    const Color(0xFF00E676),
                    '出発地',
                    () => _setDeparture(pos),
                  ),
                  const SizedBox(height: 8),
                  _selectorOption(
                    Icons.circle,
                    const Color(0xFFFF9100),
                    '経由地',
                    () => _addWaypoint(pos),
                  ),
                  const SizedBox(height: 8),
                  _selectorOption(
                    Icons.flag,
                    const Color(0xFFFF5252),
                    '目的地',
                    () => _setDestination(pos),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectorOption(
      IconData icon, Color color, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1628),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // --- Marker action panel (on marker tap) ---
  Widget _buildMarkerActionPanel() {
    final wp = _activeWaypoint!;
    return Stack(
      children: [
        _backdrop(),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: PointerInterceptor(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF)
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wp.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                              Text(
                                '${wp.position.latitude.toStringAsFixed(4)}, ${wp.position.longitude.toStringAsFixed(4)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white38),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _deleteWaypoint(wp),
                          icon: const Icon(Icons.delete,
                              color: Color(0xFFFF5252)),
                          tooltip: '削除',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Weather info inline
                    if (wp.weatherData != null)
                      _buildWeatherCard(wp.weatherData!),
                    if (wp.weatherData == null)
                      _loadingCard('天気データ読み込み中...'),
                    const SizedBox(height: 8),
                    if (wp.marineData != null)
                      _buildMarineCard(wp.marineData!),
                    if (wp.marineData == null)
                      _loadingCard('海洋データ読み込み中...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Clear confirm panel ---
  Widget _buildClearConfirmPanel() {
    return Stack(
      children: [
        _backdrop(),
        Center(
          child: PointerInterceptor(
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1F3C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ルートクリア',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E5FF))),
                  const SizedBox(height: 12),
                  const Text('すべての地点を削除しますか？',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _dismissOverlay,
                        child: const Text('キャンセル',
                            style: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _clearRoute,
                        child: const Text('クリア',
                            style: TextStyle(color: Color(0xFF00E5FF))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- All weather panel ---
  Widget _buildAllWeatherPanel() {
    final provider = context.read<NavigationProvider>();
    final allWaypoints = provider.allWaypoints;
    if (allWaypoints.isEmpty) {
      _dismissOverlay();
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        _backdrop(),
        Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 12,
          right: 12,
          bottom: 12,
          child: PointerInterceptor(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1F3C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '全地点の天気情報',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _dismissOverlay,
                          icon: const Icon(Icons.close,
                              color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  if (provider.isLoadingWeather)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                          color: Color(0xFF00E5FF)),
                    ),
                  Expanded(
                    child: DefaultTabController(
                      length: allWaypoints.length,
                      child: Column(
                        children: [
                          TabBar(
                            isScrollable: true,
                            labelColor: const Color(0xFF00E5FF),
                            unselectedLabelColor: Colors.white54,
                            indicatorColor: const Color(0xFF00E5FF),
                            dividerColor: Colors.transparent,
                            tabs: allWaypoints
                                .map((wp) => Tab(text: wp.displayName))
                                .toList(),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: allWaypoints.map((wp) {
                                return SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${wp.position.latitude.toStringAsFixed(4)}, ${wp.position.longitude.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white38),
                                      ),
                                      const SizedBox(height: 8),
                                      if (wp.weatherData != null)
                                        _buildWeatherCard(
                                            wp.weatherData!),
                                      if (wp.weatherData == null)
                                        _loadingCard(
                                            '天気データ読み込み中...'),
                                      const SizedBox(height: 8),
                                      if (wp.marineData != null)
                                        _buildMarineCard(
                                            wp.marineData!),
                                      if (wp.marineData == null)
                                        _loadingCard(
                                            '海洋データ読み込み中...'),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =============================================
  // Shared UI building blocks
  // =============================================

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

  Widget _loadingCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(text,
            style: const TextStyle(color: Colors.white54)),
      ),
    );
  }

  Widget _buildWeatherCard(WeatherData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('天気',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E5FF))),
          Divider(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
          Row(
            children: [
              Text(data.weatherIcon,
                  style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.weatherDescription,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white70)),
                  Text(
                      '${data.currentTemperature.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow(Icons.air, '風速',
              '${data.currentWindSpeed.toStringAsFixed(1)} km/h'),
          _infoRow(Icons.explore, '風向',
              '${data.currentWindDirection.toStringAsFixed(0)}°'),
          _infoRow(Icons.water_drop, '降水量',
              '${data.currentPrecipitation.toStringAsFixed(1)} mm'),
        ],
      ),
    );
  }

  Widget _buildMarineCard(MarineData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1628), Color(0xFF0D2847)],
        ),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('海洋気象',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E5FF))),
          Divider(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
          _infoRow(Icons.waves, '波高',
              '${data.currentWaveHeight.toStringAsFixed(1)} m'),
          _infoRow(Icons.waves, 'うねり高',
              '${data.currentSwellWaveHeight.toStringAsFixed(1)} m'),
          _infoRow(Icons.waves, '風浪高',
              '${data.currentWindWaveHeight.toStringAsFixed(1)} m'),
          _infoRow(Icons.timer, '波周期',
              '${data.currentWavePeriod.toStringAsFixed(1)} s'),
          _infoRow(Icons.navigation, '波向',
              '${data.currentWaveDirection.toStringAsFixed(0)}°'),
          _infoRow(Icons.thermostat, '海面温度',
              '${data.currentSeaSurfaceTemperature.toStringAsFixed(1)}°C'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00E5FF)),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.white)),
        ],
      ),
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
