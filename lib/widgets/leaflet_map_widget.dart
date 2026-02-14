import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import '../interop/leaflet_map_controller.dart';

class LeafletMapWidget extends StatefulWidget {
  const LeafletMapWidget({super.key});

  @override
  State<LeafletMapWidget> createState() => LeafletMapWidgetState();
}

class LeafletMapWidgetState extends State<LeafletMapWidget> {
  static const _viewType = 'leaflet-map-view';
  static bool _factoryRegistered = false;
  static const _containerId = 'leaflet-map-container';

  final LeafletMapController _controller = LeafletMapController();
  bool _mapReady = false;

  LeafletMapController get controller => _controller;

  @override
  void initState() {
    super.initState();
    try {
      _registerFactory();
    } catch (e) {
      print('registerFactory error: $e');
    }
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

  void _initMapDelayed() {
    if (_mapReady) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      try {
        _controller.initMap(_containerId);
        if (mounted) {
          setState(() => _mapReady = true);
        }
      } catch (e) {
        print('initMap error: $e');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: _viewType,
      onPlatformViewCreated: (_) => _initMapDelayed(),
    );
  }
}
