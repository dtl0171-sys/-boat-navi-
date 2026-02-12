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

  // --- Map tap → push opaque route for waypoint selection ---
  void _onMapTap(double lat, double lng) async {
    final position = LatLng(lat, lng);
    final result = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: true,
        pageBuilder: (_, __, ___) =>
            _WaypointSelectorPage(position: position),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    _mapController?.invalidateSize();
    if (!mounted || result == null) return;
    final provider = context.read<NavigationProvider>();
    switch (result) {
      case 'departure':
        provider.setDeparture(position);
      case 'waypoint':
        provider.addWaypoint(position);
      case 'destination':
        provider.setDestination(position);
    }
  }

  // --- Marker tap → push opaque route for marker actions ---
  void _onMarkerTap(String id) async {
    final result = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        opaque: true,
        pageBuilder: (_, __, ___) => _MarkerActionPage(waypointId: id),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    _mapController?.invalidateSize();
    if (!mounted || result != 'delete') return;
    final provider = context.read<NavigationProvider>();
    final wp = provider.allWaypoints.where((w) => w.id == id).firstOrNull;
    if (wp == null) return;
    if (wp.type == WaypointType.departure) {
      provider.removeDeparture();
    } else if (wp.type == WaypointType.destination) {
      provider.removeDestination();
    } else {
      final idx = provider.waypoints.indexWhere((w) => w.id == wp.id);
      if (idx >= 0) provider.removeWaypoint(idx);
    }
  }

  // --- Clear route confirmation ---
  void _showClearConfirm() async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: true,
        pageBuilder: (_, __, ___) => const _ClearConfirmPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    _mapController?.invalidateSize();
    if (result == true && mounted) {
      context.read<NavigationProvider>().clearRoute();
    }
  }

  // --- All weather panel ---
  void _showAllWeather() async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => const _AllWeatherPage(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    _mapController?.invalidateSize();
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

          // Layer 2: Map controls (always visible)
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

// =============================================
// Control button widget
// =============================================

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

// =============================================
// Shared UI helpers (file-level)
// =============================================

BoxDecoration _dialogDecoration() {
  return BoxDecoration(
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

Widget _weatherCard(WeatherData data) {
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

Widget _marineCard(MarineData data) {
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

// =============================================
// Overlay Pages (pushed as opaque routes)
// =============================================

/// Waypoint type selector - shown when user taps the map
class _WaypointSelectorPage extends StatelessWidget {
  final LatLng position;
  const _WaypointSelectorPage({required this.position});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Absorb taps on the dialog itself
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(20),
              decoration: _dialogDecoration(),
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
                    '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(height: 16),
                  _option(context, Icons.play_circle,
                      const Color(0xFF00E676), '出発地', 'departure'),
                  const SizedBox(height: 8),
                  _option(context, Icons.circle,
                      const Color(0xFFFF9100), '経由地', 'waypoint'),
                  const SizedBox(height: 8),
                  _option(context, Icons.flag,
                      const Color(0xFFFF5252), '目的地', 'destination'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext context, IconData icon, Color color,
      String label, String result) {
    return InkWell(
      onTap: () => Navigator.pop(context, result),
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
}

/// Marker action panel - shown when user taps a waypoint marker
class _MarkerActionPage extends StatelessWidget {
  final String waypointId;
  const _MarkerActionPage({required this.waypointId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: () {}, // Absorb taps on the panel
              child: Consumer<NavigationProvider>(
                builder: (context, provider, _) {
                  final wp = provider.allWaypoints
                      .where((w) => w.id == waypointId)
                      .firstOrNull;
                  if (wp == null) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.of(context).size.height * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1F3C),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                      border: Border(
                        top: BorderSide(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.5),
                            width: 0.5),
                        left: BorderSide(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.5),
                            width: 0.5),
                        right: BorderSide(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.5),
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
                              margin:
                                  const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.5),
                                borderRadius:
                                    BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Title row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                          fontSize: 12,
                                          color: Colors.white38),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    Navigator.pop(context, 'delete'),
                                icon: const Icon(Icons.delete,
                                    color: Color(0xFFFF5252)),
                                tooltip: '削除',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Weather info
                          if (wp.weatherData != null)
                            _weatherCard(wp.weatherData!),
                          if (wp.weatherData == null)
                            _loadingCard('天気データ読み込み中...'),
                          const SizedBox(height: 8),
                          if (wp.marineData != null)
                            _marineCard(wp.marineData!),
                          if (wp.marineData == null)
                            _loadingCard('海洋データ読み込み中...'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route clear confirmation dialog
class _ClearConfirmPage extends StatelessWidget {
  const _ClearConfirmPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: GestureDetector(
        onTap: () => Navigator.pop(context, false),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(20),
              decoration: _dialogDecoration(),
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
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: const Text('キャンセル',
                            style:
                                TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        child: const Text('クリア',
                            style: TextStyle(
                                color: Color(0xFF00E5FF))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// All-weather panel showing weather for every waypoint
class _AllWeatherPage extends StatelessWidget {
  const _AllWeatherPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Consumer<NavigationProvider>(
          builder: (context, provider, _) {
            final allWaypoints = provider.allWaypoints;
            if (allWaypoints.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('地点がありません',
                        style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('戻る',
                          style:
                              TextStyle(color: Color(0xFF00E5FF))),
                    ),
                  ],
                ),
              );
            }

            return Column(
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
                        onPressed: () => Navigator.pop(context),
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
                              .map(
                                  (wp) => Tab(text: wp.displayName))
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
                                      _weatherCard(
                                          wp.weatherData!),
                                    if (wp.weatherData == null)
                                      _loadingCard(
                                          '天気データ読み込み中...'),
                                    const SizedBox(height: 8),
                                    if (wp.marineData != null)
                                      _marineCard(
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
            );
          },
        ),
      ),
    );
  }
}
