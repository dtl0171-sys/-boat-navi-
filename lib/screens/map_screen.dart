import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/waypoint.dart';
import '../models/weather_data.dart';
import '../models/marine_data.dart';
import '../providers/navigation_provider.dart';
import '../widgets/map_widget.dart';
import '../widgets/route_info_bar.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  void _showAllWeatherPanel(BuildContext context) {
    final provider = context.read<NavigationProvider>();
    final allWaypoints = provider.allWaypoints;
    if (allWaypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ルートが設定されていません'),
          backgroundColor: const Color(0xFF0D1F3C),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1F3C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(color: Color(0xFF00E5FF), width: 0.5),
                left: BorderSide(color: Color(0xFF00E5FF), width: 0.5),
                right: BorderSide(color: Color(0xFF00E5FF), width: 0.5),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '全地点の天気情報',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
                if (provider.isLoadingWeather)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E5FF),
                    ),
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
                                child:
                                    WaypointWeatherContent(waypoint: wp),
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          const MapWidget(),

          // Top-left: App title panel
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
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
              ),
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

          // Top-right: Floating control panel
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Consumer<NavigationProvider>(
              builder: (context, provider, _) {
                return Container(
                  decoration: BoxDecoration(
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
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // AIS toggle
                      _ControlButton(
                        icon: Icons.directions_boat,
                        tooltip: 'AIS船舶表示',
                        isActive: provider.aisEnabled,
                        isLoading: provider.isLoadingAis,
                        onPressed: () => provider.toggleAis(),
                        isTop: true,
                      ),
                      _divider(),
                      // Weather
                      _ControlButton(
                        icon: Icons.wb_sunny,
                        tooltip: '全地点の天気',
                        isActive: false,
                        isLoading: provider.isLoadingWeather,
                        isVisible: provider.allWaypoints.isNotEmpty,
                        onPressed: () => _showAllWeatherPanel(context),
                      ),
                      if (provider.allWaypoints.isNotEmpty) _divider(),
                      // Clear route
                      _ControlButton(
                        icon: Icons.clear,
                        tooltip: 'ルートクリア',
                        isActive: false,
                        isVisible: provider.allWaypoints.isNotEmpty,
                        onPressed: () => _showClearDialog(context, provider),
                      ),
                      if (provider.allWaypoints.isNotEmpty) _divider(),
                      // Settings
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

          // Bottom-right: Current location FAB
          Positioned(
            bottom: 100,
            right: 12,
            child: Consumer<NavigationProvider>(
              builder: (context, provider, _) {
                if (provider.currentPosition == null ||
                    provider.departure != null) {
                  return const SizedBox.shrink();
                }
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: FloatingActionButton.small(
                    heroTag: 'currentLoc',
                    onPressed: () {
                      provider.setDepartureFromCurrentPosition();
                    },
                    backgroundColor: const Color(0xFF0D1F3C),
                    foregroundColor: const Color(0xFF00E5FF),
                    shape: CircleBorder(
                      side: BorderSide(
                        color:
                            const Color(0xFF00E5FF).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(Icons.my_location),
                  ),
                );
              },
            ),
          ),

          // Bottom: Route info bar
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RouteInfoBar(),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 28,
      height: 0.5,
      color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
    );
  }

  void _showClearDialog(BuildContext context, NavigationProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F3C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 0.5),
        ),
        title: const Text('ルートクリア',
            style: TextStyle(color: Color(0xFF00E5FF))),
        content: const Text('すべての地点を削除しますか？',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              provider.clearRoute();
              Navigator.pop(ctx);
            },
            child: const Text('クリア',
                style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
    );
  }
}

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

class WaypointWeatherContent extends StatelessWidget {
  final Waypoint waypoint;
  const WaypointWeatherContent({super.key, required this.waypoint});

  @override
  Widget build(BuildContext context) {
    if (waypoint.weatherData == null && waypoint.marineData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${waypoint.position.latitude.toStringAsFixed(4)}, ${waypoint.position.longitude.toStringAsFixed(4)}',
          style: const TextStyle(fontSize: 12, color: Colors.white38),
        ),
        const SizedBox(height: 8),
        if (waypoint.weatherData != null)
          _buildWeatherCard(waypoint.weatherData!),
        const SizedBox(height: 8),
        if (waypoint.marineData != null)
          _buildMarineCard(waypoint.marineData!),
      ],
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
          Divider(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
          Row(
            children: [
              Text(data.weatherIcon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.weatherDescription,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white70)),
                  Text('${data.currentTemperature.toStringAsFixed(1)}°C',
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
          Divider(color: const Color(0xFF00E5FF).withValues(alpha: 0.2)),
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
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.white)),
        ],
      ),
    );
  }
}
