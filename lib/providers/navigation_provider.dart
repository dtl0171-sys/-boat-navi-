import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/waypoint.dart';
import '../models/route_leg.dart';
import '../models/ais_vessel.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/route_service.dart';
import '../services/ais_service.dart';

class NavigationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final WeatherService _weatherService = WeatherService();
  final RouteService _routeService = RouteService();
  final AisService _aisService = AisService();

  LatLng? _currentPosition;
  Waypoint? _departure;
  final List<Waypoint> _waypoints = [];
  Waypoint? _destination;
  List<RouteLeg> _routeLegs = [];
  double _boatSpeed = 15.0;
  SpeedUnit _speedUnit = SpeedUnit.knots;
  bool _isLoadingWeather = false;
  bool _isTrackingLocation = false;
  int _waypointCounter = 0;

  // AIS fields
  bool _aisEnabled = false;
  List<AisVessel> _aisVessels = [];
  bool _isLoadingAis = false;

  LatLng? get currentPosition => _currentPosition;
  Waypoint? get departure => _departure;
  List<Waypoint> get waypoints => List.unmodifiable(_waypoints);
  Waypoint? get destination => _destination;
  List<RouteLeg> get routeLegs => List.unmodifiable(_routeLegs);
  double get boatSpeed => _boatSpeed;
  SpeedUnit get speedUnit => _speedUnit;
  bool get isLoadingWeather => _isLoadingWeather;
  bool get isTrackingLocation => _isTrackingLocation;

  // AIS getters
  bool get aisEnabled => _aisEnabled;
  List<AisVessel> get aisVessels => List.unmodifiable(_aisVessels);
  bool get isLoadingAis => _isLoadingAis;

  double get totalDistanceKm => _routeService.totalDistanceKm(_routeLegs);
  double get totalDurationMinutes =>
      _routeService.totalDurationMinutes(_routeLegs);

  String get speedUnitLabel =>
      _speedUnit == SpeedUnit.knots ? 'kt' : 'km/h';

  List<Waypoint> get allWaypoints {
    final list = <Waypoint>[];
    final dep = _departure;
    if (dep != null) list.add(dep);
    list.addAll(_waypoints);
    final dest = _destination;
    if (dest != null) list.add(dest);
    return list;
  }

  String get totalDurationText {
    final mins = totalDurationMinutes;
    if (mins == double.infinity) return '---';
    final hours = mins ~/ 60;
    final m = (mins % 60).round();
    if (hours > 0) return '$hours時間${m}分';
    return '$m分';
  }

  Future<void> init() async {
    try {
      await _loadPreferences();
    } catch (e) {
      print('Failed to load preferences: $e');
    }
    try {
      await startLocationTracking();
    } catch (e) {
      print('Failed to start location tracking: $e');
    }
    if (_aisEnabled) {
      fetchAisVessels();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _boatSpeed = prefs.getDouble('boatSpeed') ?? 15.0;
    final unitStr = prefs.getString('speedUnit') ?? 'knots';
    _speedUnit =
        unitStr == 'kmh' ? SpeedUnit.kmh : SpeedUnit.knots;
    _aisEnabled = prefs.getBool('aisEnabled') ?? false;
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('boatSpeed', _boatSpeed);
    await prefs.setString(
        'speedUnit', _speedUnit == SpeedUnit.kmh ? 'kmh' : 'knots');
    await prefs.setBool('aisEnabled', _aisEnabled);
  }

  Future<void> startLocationTracking() async {
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      _currentPosition = position;
      notifyListeners();
    }

    _locationService.startTracking((pos) {
      _currentPosition = pos;
      _isTrackingLocation = true;
      notifyListeners();
    });
    _isTrackingLocation = true;
    notifyListeners();
  }

  void toggleAis() {
    _aisEnabled = !_aisEnabled;
    _savePreferences();
    if (_aisEnabled) {
      fetchAisVessels();
    } else {
      _aisVessels = [];
    }
    notifyListeners();
  }

  Future<void> fetchAisVessels() async {
    if (!_aisEnabled) return;

    _isLoadingAis = true;
    notifyListeners();

    try {
      _aisVessels = await _aisService.fetchVessels();
    } catch (e) {
      // Keep existing vessels on error
    }

    _isLoadingAis = false;
    notifyListeners();
  }

  void setDepartureFromCurrentPosition() {
    final pos = _currentPosition;
    if (pos == null) return;
    _departure = Waypoint(
      id: 'dep_${_waypointCounter++}',
      position: pos,
      type: WaypointType.departure,
      name: '現在地',
    );
    _recalculateRoute();
    _fetchAllWeather();
    notifyListeners();
  }

  void setDeparture(LatLng position) {
    _departure = Waypoint(
      id: 'dep_${_waypointCounter++}',
      position: position,
      type: WaypointType.departure,
    );
    _recalculateRoute();
    _fetchAllWeather();
    notifyListeners();
  }

  void setDestination(LatLng position) {
    final oldDest = _destination;
    if (oldDest != null) {
      _waypoints.add(oldDest.copyWith(
        type: WaypointType.waypoint,
        id: 'wp_${_waypointCounter++}',
      ));
    }
    _destination = Waypoint(
      id: 'dest_${_waypointCounter++}',
      position: position,
      type: WaypointType.destination,
    );
    _recalculateRoute();
    _fetchAllWeather();
    notifyListeners();
  }

  void addWaypoint(LatLng position) {
    _waypoints.add(Waypoint(
      id: 'wp_${_waypointCounter++}',
      position: position,
      type: WaypointType.waypoint,
    ));
    _recalculateRoute();
    _fetchAllWeather();
    notifyListeners();
  }

  void removeWaypoint(int index) {
    if (index >= 0 && index < _waypoints.length) {
      _waypoints.removeAt(index);
      _recalculateRoute();
      notifyListeners();
    }
  }

  void removeDeparture() {
    _departure = null;
    _recalculateRoute();
    notifyListeners();
  }

  void removeDestination() {
    _destination = null;
    _recalculateRoute();
    notifyListeners();
  }

  void reorderWaypoints(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final wp = _waypoints.removeAt(oldIndex);
    _waypoints.insert(newIndex, wp);
    _recalculateRoute();
    notifyListeners();
  }

  void setBoatSpeed(double speed, SpeedUnit unit) {
    _boatSpeed = speed;
    _speedUnit = unit;
    _recalculateRoute();
    _savePreferences();
    notifyListeners();
  }

  void _recalculateRoute() {
    final all = allWaypoints;
    _routeLegs = _routeService.calculateRoute(all, _boatSpeed, _speedUnit);
  }

  Future<void> _fetchAllWeather() async {
    final all = allWaypoints;
    if (all.isEmpty) return;

    _isLoadingWeather = true;
    notifyListeners();

    for (final wp in all) {
      final weather =
          await _weatherService.fetchWeather(wp.position);
      final marine =
          await _weatherService.fetchMarine(wp.position);
      wp.weatherData = weather;
      wp.marineData = marine;
    }

    _isLoadingWeather = false;
    notifyListeners();
  }

  void clearRoute() {
    _departure = null;
    _waypoints.clear();
    _destination = null;
    _routeLegs = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
