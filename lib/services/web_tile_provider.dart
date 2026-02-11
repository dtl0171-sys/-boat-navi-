import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// Custom TileProvider that uses Flutter's built-in NetworkImage
/// instead of flutter_map's http-package-based NetworkTileProvider.
/// This fixes tile loading in dart2js release builds where the
/// http package's RetryClient fails silently.
class WebTileProvider extends TileProvider {
  WebTileProvider({super.headers});

  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return NetworkImage(getTileUrl(coordinates, options));
  }
}
