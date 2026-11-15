/// MapLibre basemap. Mapbox token is optional; without it we use OpenFreeMap.
class MapboxConfig {
  static const accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  /// Mapbox GL style id (username/style). Override with dart-define if needed.
  static const styleId = String.fromEnvironment(
    'MAPBOX_STYLE',
    defaultValue: 'mapbox/streets-v12',
  );

  /// OpenFreeMap Liberty: OSM vector tiles, no API key, parks/water in color.
  static const _openFreeMapLiberty =
      'https://tiles.openfreemap.org/styles/liberty';

  static bool get isConfigured =>
      accessToken.trim().isNotEmpty && !accessToken.contains('your_');

  /// Style URL for [MapLibreMap.styleString].
  static String get mapStyleUrl {
    if (!isConfigured) return _openFreeMapLiberty;
    final token = Uri.encodeComponent(accessToken.trim());
    final style = styleId.trim();
    return 'https://api.mapbox.com/styles/v1/$style?access_token=$token';
  }
}
