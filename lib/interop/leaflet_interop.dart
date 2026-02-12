import 'dart:js_interop';

@JS('LeafletBridge.initMap')
external void jsInitMap(
    JSString containerId, JSNumber lat, JSNumber lng, JSNumber zoom);

@JS('LeafletBridge.updateMarkers')
external void jsUpdateMarkers(JSString markersJson);

@JS('LeafletBridge.updateRoute')
external void jsUpdateRoute(JSString pointsJson);

@JS('LeafletBridge.fitBounds')
external void jsFitBounds(JSString pointsJson);

@JS('LeafletBridge.panTo')
external void jsPanTo(JSNumber lat, JSNumber lng);

@JS('LeafletBridge.setView')
external void jsSetView(JSNumber lat, JSNumber lng, JSNumber zoom);

@JS('LeafletBridge.toggleSeaMap')
external void jsToggleSeaMap(JSBoolean enabled);

@JS('LeafletBridge.invalidateSize')
external void jsInvalidateSize();

@JS('LeafletBridge.dispose')
external void jsDispose();

@JS('_dartOnMapTap')
external set dartOnMapTap(JSFunction? callback);

@JS('_dartOnMarkerTap')
external set dartOnMarkerTap(JSFunction? callback);
