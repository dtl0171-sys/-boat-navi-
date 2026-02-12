import 'dart:convert';
import 'dart:js_interop';
import 'leaflet_interop.dart';
import '../providers/navigation_provider.dart';

class LeafletMapController {
  bool _initialized = false;

  void initMap(String containerId,
      {double lat = 35.4, double lng = 136.0, int zoom = 6}) {
    jsInitMap(containerId.toJS, lat.toJS, lng.toJS, zoom.toJS);
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  void updateMarkers(NavigationProvider provider) {
    if (!_initialized) return;

    final markers = <Map<String, dynamic>>[];

    // Current position
    if (provider.currentPosition != null) {
      markers.add({
        'type': 'current',
        'lat': provider.currentPosition!.latitude,
        'lng': provider.currentPosition!.longitude,
        'label': '⛵',
      });
    }

    // Departure
    if (provider.departure != null) {
      markers.add({
        'type': 'departure',
        'id': provider.departure!.id,
        'lat': provider.departure!.position.latitude,
        'lng': provider.departure!.position.longitude,
        'label': '▶',
      });
    }

    // Waypoints
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

    // Destination
    if (provider.destination != null) {
      markers.add({
        'type': 'destination',
        'id': provider.destination!.id,
        'lat': provider.destination!.position.latitude,
        'lng': provider.destination!.position.longitude,
        'label': '⚑',
      });
    }

    // AIS vessels
    if (provider.aisEnabled) {
      for (final vessel in provider.aisVessels) {
        markers.add({
          'type': 'ais',
          'lat': vessel.lat,
          'lng': vessel.lon,
          'cog': vessel.cog,
          'name': vessel.name,
          'mmsi': vessel.mmsi,
          'sog': vessel.sog,
        });
      }
    }

    jsUpdateMarkers(jsonEncode(markers).toJS);
  }

  void updateRoute(NavigationProvider provider) {
    if (!_initialized) return;

    final allWaypoints = provider.allWaypoints;
    final points = allWaypoints
        .map((wp) => [wp.position.latitude, wp.position.longitude])
        .toList();

    jsUpdateRoute(jsonEncode(points).toJS);
  }

  void fitBounds(NavigationProvider provider) {
    if (!_initialized) return;

    final allWaypoints = provider.allWaypoints;
    if (allWaypoints.isEmpty) return;

    final points = allWaypoints
        .map((wp) => [wp.position.latitude, wp.position.longitude])
        .toList();

    jsFitBounds(jsonEncode(points).toJS);
  }

  void panTo(double lat, double lng) {
    if (!_initialized) return;
    jsPanTo(lat.toJS, lng.toJS);
  }

  void setView(double lat, double lng, int zoom) {
    if (!_initialized) return;
    jsSetView(lat.toJS, lng.toJS, zoom.toJS);
  }

  void toggleSeaMap(bool enabled) {
    if (!_initialized) return;
    jsToggleSeaMap(enabled.toJS);
  }

  void invalidateSize() {
    if (!_initialized) return;
    jsInvalidateSize();
  }

  void dispose() {
    if (!_initialized) return;
    jsDispose();
    _initialized = false;
  }
}
