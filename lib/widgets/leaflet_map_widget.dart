import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import '../interop/leaflet_interop.dart';
import '../interop/leaflet_map_controller.dart';
import '../providers/navigation_provider.dart';

class LeafletMapWidget extends StatefulWidget {
  final void Function(double lat, double lng)? onMapTap;
  final void Function(String waypointId)? onMarkerTap;

  const LeafletMapWidget({super.key, this.onMapTap, this.onMarkerTap});

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
      if (!mounted) return;
      widget.onMapTap?.call(lat.toDartDouble, lng.toDartDouble);
    }).toJS;

    dartOnMarkerTap = ((JSString id) {
      if (!mounted) return;
      widget.onMarkerTap?.call(id.toDart);
    }).toJS;
  }

  @override
  void didUpdateWidget(LeafletMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-setup callbacks if parent changed them
    if (widget.onMapTap != oldWidget.onMapTap ||
        widget.onMarkerTap != oldWidget.onMarkerTap) {
      _setupCallbacks();
    }
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

    final currentCount = provider.allWaypoints.length;
    if (currentCount != _prevWaypointCount && currentCount > 0) {
      _controller.fitBounds(provider);
      _prevWaypointCount = currentCount;
    }
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
