import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:h3_flutter/h3_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/current_zone_overview.dart';
import '../../shared/models/layer_settings.dart';
import '../../shared/models/report.dart';
import '../../shared/models/zone.dart';
import '../../shared/network/api_client.dart';

final authTokenProvider = StateProvider<String?>((ref) => null);
final authUserEmailProvider = StateProvider<String?>((ref) => null);
final selectedZoneProvider = StateProvider<ZoneModel?>((ref) => null);
final activeZoneFilterProvider = StateProvider<String?>((ref) => null);
final currentUserLocationProvider = StateProvider<LatLng?>((ref) => null);
final exploreFocusLocationProvider = StateProvider<LatLng?>((ref) => null);
final zoneDataNoticeProvider = StateProvider<String?>((ref) => null);
final layerSettingsProvider = StateProvider<LayerSettings>(
  (ref) => const LayerSettings(),
);

class MapViewport {
  const MapViewport({
    required this.center,
    required this.zoom,
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });

  final LatLng center;
  final double zoom;
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  MapViewport copyWith({
    LatLng? center,
    double? zoom,
    double? minLat,
    double? minLng,
    double? maxLat,
    double? maxLng,
  }) {
    return MapViewport(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      minLat: minLat ?? this.minLat,
      minLng: minLng ?? this.minLng,
      maxLat: maxLat ?? this.maxLat,
      maxLng: maxLng ?? this.maxLng,
    );
  }

  /// Legacy helper kept for any remaining call sites that expect a single
  /// `minLng,minLat,maxLng,maxLat` string.
  String get bbox => '$minLng,$minLat,$maxLng,$maxLat';
}

final mapViewportProvider = StateProvider<MapViewport>(
  (ref) => const MapViewport(
    center: LatLng(10.3157, 123.8854),
    zoom: 12,
    minLat: 10.24,
    minLng: 123.82,
    maxLat: 10.39,
    maxLng: 123.97,
  ),
);

final visibleZonesProvider = FutureProvider<List<ZoneModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final viewport = ref.watch(mapViewportProvider);
  final filter = ref.watch(activeZoneFilterProvider);
  const cacheKey = 'last_good_visible_zones';
  try {
    final response = await dio.get(
      '/zones',
      queryParameters: {
        'min_lat': viewport.minLat,
        'min_lng': viewport.minLng,
        'max_lat': viewport.maxLat,
        'max_lng': viewport.maxLng,
        'zoom': viewport.zoom.round(),
        if (filter != null && filter.isNotEmpty) 'filter': filter,
      },
    );
    final zones = (response.data as List)
        .map((zone) => ZoneModel.fromJson(zone as Map<String, dynamic>))
        .where((zone) => zone.boundary.length >= 3)
        .toList();
    unawaited(_writeZoneCache(cacheKey, response.data));
    ref.read(zoneDataNoticeProvider.notifier).state = null;
    return zones;
  } on DioException {
    return _cachedOrFallbackZones(ref, cacheKey, filter);
  } on FormatException {
    return _cachedOrFallbackZones(ref, cacheKey, filter);
  } on TypeError {
    return _cachedOrFallbackZones(ref, cacheKey, filter);
  }
});

final feedProvider = FutureProvider<List<ReportModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/reports/feed');
    return (response.data as List)
        .map((item) => ReportModel.fromJson(item as Map<String, dynamic>))
        .toList();
  } on DioException {
    return _fallbackFeed();
  } on FormatException {
    return _fallbackFeed();
  } on TypeError {
    return _fallbackFeed();
  }
});

String? _zoneFeedApiFilter(String chipLabel) {
  switch (chipLabel.toLowerCase()) {
    case 'following':
      return 'for_you';
    case 'nearby':
      return 'local_picks';
    case 'trending':
      return 'popular_now';
    case 'food':
      return 'food';
    case 'crowd':
      return 'popular_now';
    case 'safety':
      return 'safe_areas';
    default:
      return null;
  }
}

double? _quantizeGeo(double? value, {required int decimals}) {
  if (value == null) return null;
  return double.parse(value.toStringAsFixed(decimals));
}

/// Selected chip on the zone feed screen; drives `/zones/feed` `filter`.
final zoneFeedChipProvider = StateProvider<String>((ref) => 'Nearby');

final zoneFeedProvider = FutureProvider<List<ZoneModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final chip = ref.watch(zoneFeedChipProvider);
  final location = ref.watch(currentUserLocationProvider);
  final apiFilter = _zoneFeedApiFilter(chip);
  final userLat = _quantizeGeo(location?.latitude, decimals: 4);
  final userLng = _quantizeGeo(location?.longitude, decimals: 4);

  const cacheKey = 'last_good_zone_feed';

  try {
    final queryParameters = <String, dynamic>{'limit': 40};
    final f = apiFilter;
    if (f != null && f.isNotEmpty) {
      queryParameters['filter'] = f;
    }
    final lat = userLat;
    if (lat != null) {
      queryParameters['user_lat'] = lat;
    }
    final lng = userLng;
    if (lng != null) {
      queryParameters['user_lng'] = lng;
    }
    final response = await dio.get(
      '/zones/feed',
      queryParameters: queryParameters,
    );
    final zones = (response.data as List)
        .map((z) => ZoneModel.fromJson(z as Map<String, dynamic>))
        .where((z) => z.boundary.length >= 3 || z.sourceH3Rings.isNotEmpty)
        .toList();
    unawaited(_writeZoneCache(cacheKey, response.data));
    ref.read(zoneDataNoticeProvider.notifier).state = null;
    return zones;
  } on DioException {
    return _cachedOrFallbackZones(ref, cacheKey, null);
  } on FormatException {
    return _cachedOrFallbackZones(ref, cacheKey, null);
  } on TypeError {
    return _cachedOrFallbackZones(ref, cacheKey, null);
  }
});

Future<void> _writeZoneCache(String key, Object data) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('${key}_json', jsonEncode(data));
  await prefs.setInt('${key}_saved_at', DateTime.now().millisecondsSinceEpoch);
}

Future<List<ZoneModel>> _cachedOrFallbackZones(
  Ref ref,
  String key,
  String? filter,
) async {
  final cached = await _readCachedZones(key);
  if (cached != null && cached.zones.isNotEmpty) {
    ref.read(zoneDataNoticeProvider.notifier).state =
        'Showing cached zone data from ${_formatCacheTime(cached.savedAt)}';
    return _filterFallbackZones(cached.zones, filter);
  }
  ref.read(zoneDataNoticeProvider.notifier).state = null;
  return _fallbackVisibleZones(filter);
}

Future<_CachedZones?> _readCachedZones(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('${key}_json');
  final savedAtMs = prefs.getInt('${key}_saved_at');
  if (raw == null || savedAtMs == null) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! List) return null;
  final zones = decoded
      .map((z) => ZoneModel.fromJson(z as Map<String, dynamic>))
      .where((z) => z.boundary.length >= 3 || z.sourceH3Rings.isNotEmpty)
      .toList();
  return _CachedZones(
    zones: zones,
    savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMs),
  );
}

String _formatCacheTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

class _CachedZones {
  const _CachedZones({required this.zones, required this.savedAt});

  final List<ZoneModel> zones;
  final DateTime savedAt;
}

class CityPulseSnapshot {
  const CityPulseSnapshot({
    required this.cityActivity,
    required this.crowdLevelPercent,
    required this.localPresencePercent,
    required this.peakTimeWindow,
    required this.topCategories,
    required this.activeZoneCount,
  });

  final String cityActivity;
  final double crowdLevelPercent;
  final double localPresencePercent;
  final String? peakTimeWindow;
  final List<String> topCategories;
  final int activeZoneCount;

  factory CityPulseSnapshot.fromJson(Map<String, dynamic> json) {
    return CityPulseSnapshot(
      cityActivity: (json['city_activity'] ?? 'quiet').toString(),
      crowdLevelPercent: _asDouble(json['crowd_level_percent']),
      localPresencePercent: _asDouble(json['local_presence_percent']),
      peakTimeWindow: json['peak_time_window'] as String?,
      topCategories: ((json['top_active_categories'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      activeZoneCount: (json['active_zone_count'] is num)
          ? (json['active_zone_count'] as num).toInt()
          : 0,
    );
  }

  static double _asDouble(Object? v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
}

final cityPulseProvider = FutureProvider<CityPulseSnapshot>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/analytics/city-pulse');
    return CityPulseSnapshot.fromJson(response.data as Map<String, dynamic>);
  } on DioException {
    return const CityPulseSnapshot(
      cityActivity: 'active',
      crowdLevelPercent: 64,
      localPresencePercent: 52,
      peakTimeWindow: '4PM-9PM',
      topCategories: ['food', 'transport', 'cafes'],
      activeZoneCount: 8,
    );
  }
});

final currentZoneOverviewProvider = FutureProvider<CurrentZoneOverviewModel?>((
  ref,
) async {
  final location = ref.watch(currentUserLocationProvider);
  if (location == null) return null;

  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get(
      '/zones/current',
      queryParameters: {
        'lat': location.latitude,
        'lng': location.longitude,
        'ring': 2,
        'limit': 8,
      },
    );
    return CurrentZoneOverviewModel.fromJson(
      response.data as Map<String, dynamic>,
    );
  } on DioException {
    return null;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
});

/// Matches backend `h3_resolution` (8) and `_display_h3_rings` uncompact (+1).
const int _kFallbackH3AggregateRes = 8;
const int _kFallbackH3DisplayRes = 9;
const int _kFallbackH3MaxDisplayCells = 600;

List<ZoneModel> _fallbackVisibleZones(String? filter) {
  try {
    final h3 = const H3Factory().load();
    try {
      return _filterFallbackZones(_h3FallbackZoneList(h3), filter);
    } catch (_) {
      return _filterFallbackZones(_legacyBlobFallbackZoneList(), filter);
    }
  } catch (_) {
    return _filterFallbackZones(_legacyBlobFallbackZoneList(), filter);
  }
}

List<ZoneModel> _filterFallbackZones(List<ZoneModel> zones, String? filter) {
  if (filter == null || filter.isEmpty || filter == 'for_you') {
    return zones;
  }
  return zones
      .where((zone) {
        final f = filter.toLowerCase();
        return zone.functionType.contains(f) ||
            zone.behaviorType.contains(f) ||
            zone.displayName.toLowerCase().contains(f);
      })
      .toList(growable: false);
}

List<ZoneModel> _h3FallbackZoneList(H3 h3) {
  return [
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-it-park',
      displayName: 'IT Park Commercial + Food Zone',
      behaviorType: 'tourist_area',
      functionType: 'commercial_zone',
      summary:
          'Mixed food, coworking, study, and nightlife behavior around IT Park.',
      liveStatus: 'busy_now',
      lat: 10.3315,
      lng: 123.9062,
      crowd: 78,
      localPresence: 38,
      confidence: 82,
      priority: 94,
      reports: 64,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-ayala',
      displayName: 'Ayala Commercial + Cafe Zone',
      behaviorType: 'mixed_area',
      functionType: 'commercial_zone',
      summary:
          'Commercial cafe and mall movement with mixed local and visitor activity.',
      liveStatus: 'active_now',
      lat: 10.3182,
      lng: 123.9058,
      crowd: 67,
      localPresence: 55,
      confidence: 76,
      priority: 90,
      reports: 58,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-colon',
      displayName: 'Colon Heritage + Local Food Zone',
      behaviorType: 'local_area',
      functionType: 'food_hotspot',
      summary:
          'Local-heavy heritage, street food, market, and shopping behavior.',
      liveStatus: 'busy_now',
      lat: 10.2966,
      lng: 123.8992,
      crowd: 72,
      localPresence: 74,
      confidence: 79,
      priority: 88,
      reports: 61,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-lahug',
      displayName: 'Lahug Local Neighborhood Zone',
      behaviorType: 'local_area',
      functionType: 'residential_zone',
      summary:
          'Mostly local neighborhood activity with carinderias and quiet side streets.',
      liveStatus: 'quiet_now',
      lat: 10.3388,
      lng: 123.8950,
      crowd: 42,
      localPresence: 76,
      confidence: 67,
      priority: 74,
      reports: 35,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-university',
      displayName: 'USC Main Student Activity Zone',
      behaviorType: 'local_area',
      functionType: 'student_area',
      summary: 'Student movement around study hubs, cafes, and budget meals.',
      liveStatus: 'active_now',
      lat: 10.3075,
      lng: 123.8940,
      crowd: 58,
      localPresence: 69,
      confidence: 73,
      priority: 82,
      reports: 49,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-port',
      displayName: 'Pier Transit + Safety Zone',
      behaviorType: 'mixed_area',
      functionType: 'transport_zone',
      summary:
          'Transport pressure, terminal movement, and safety awareness near the port.',
      liveStatus: 'peak_now',
      lat: 10.3044,
      lng: 123.9129,
      crowd: 81,
      localPresence: 48,
      confidence: 71,
      priority: 86,
      reports: 52,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-carbon',
      displayName: 'Carbon Market Local Food + Shopping Zone',
      behaviorType: 'local_area',
      functionType: 'food_hotspot',
      summary:
          'Wet-market food, budget meals, and practical shopping movement.',
      liveStatus: 'busy_now',
      lat: 10.2944,
      lng: 123.9006,
      crowd: 74,
      localPresence: 86,
      confidence: 81,
      priority: 87,
      reports: 55,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-fuente',
      displayName: 'Fuente Transit + Food Zone',
      behaviorType: 'local_area',
      functionType: 'transport_zone',
      summary:
          'Evening commute, Larsian food, and shopping overlap near Fuente.',
      liveStatus: 'busy_now',
      lat: 10.3105,
      lng: 123.8921,
      crowd: 70,
      localPresence: 78,
      confidence: 77,
      priority: 84,
      reports: 50,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-busay',
      displayName: 'Busay Nature + Sunset Zone',
      behaviorType: 'tourist_area',
      functionType: 'tourist_hotspot',
      summary: 'Sunset drives, mountain cafes, and sightseeing near Tops.',
      liveStatus: 'active_now',
      lat: 10.3700,
      lng: 123.8780,
      crowd: 62,
      localPresence: 24,
      confidence: 74,
      priority: 83,
      reports: 46,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-mactan',
      displayName: 'Mactan Resort + Beach Zone',
      behaviorType: 'tourist_area',
      functionType: 'tourist_hotspot',
      summary: 'Beach clubs, resorts, diving, seafood, and afternoon leisure.',
      liveStatus: 'active_now',
      lat: 10.2983,
      lng: 124.0155,
      crowd: 59,
      localPresence: 18,
      confidence: 72,
      priority: 81,
      reports: 43,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-sirao',
      displayName: 'Sirao Flower Garden Nature Zone',
      behaviorType: 'tourist_area',
      functionType: 'tourist_hotspot',
      summary:
          'Flower garden visits, photo stops, and mountain-drive behavior.',
      liveStatus: 'active_now',
      lat: 10.3940,
      lng: 123.8680,
      crowd: 46,
      localPresence: 22,
      confidence: 67,
      priority: 75,
      reports: 31,
    ),
    _fallbackZoneFromH3(
      h3,
      zoneId: 'dev-south-bus',
      displayName: 'South Bus Terminal Backpacker Transit Zone',
      behaviorType: 'local_area',
      functionType: 'transport_zone',
      summary:
          'Budget traveler and local commute behavior around bus departures.',
      liveStatus: 'busy_now',
      lat: 10.3001,
      lng: 123.8931,
      crowd: 76,
      localPresence: 82,
      confidence: 75,
      priority: 82,
      reports: 47,
    ),
  ];
}

List<ZoneModel> _legacyBlobFallbackZoneList() {
  return [
    _legacyBlobFallbackZone(
      zoneId: 'dev-it-park',
      displayName: 'IT Park Commercial + Food Zone',
      behaviorType: 'tourist_area',
      functionType: 'commercial_zone',
      summary:
          'Mixed food, coworking, study, and nightlife behavior around IT Park.',
      liveStatus: 'busy_now',
      lat: 10.3315,
      lng: 123.9062,
      latRadius: 0.010,
      lngRadius: 0.013,
      crowd: 78,
      localPresence: 38,
      confidence: 82,
      priority: 94,
      reports: 64,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-ayala',
      displayName: 'Ayala Commercial + Cafe Zone',
      behaviorType: 'mixed_area',
      functionType: 'commercial_zone',
      summary:
          'Commercial cafe and mall movement with mixed local and visitor activity.',
      liveStatus: 'active_now',
      lat: 10.3182,
      lng: 123.9058,
      latRadius: 0.011,
      lngRadius: 0.014,
      crowd: 67,
      localPresence: 55,
      confidence: 76,
      priority: 90,
      reports: 58,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-colon',
      displayName: 'Colon Heritage + Local Food Zone',
      behaviorType: 'local_area',
      functionType: 'food_hotspot',
      summary:
          'Local-heavy heritage, street food, market, and shopping behavior.',
      liveStatus: 'busy_now',
      lat: 10.2966,
      lng: 123.8992,
      latRadius: 0.009,
      lngRadius: 0.013,
      crowd: 72,
      localPresence: 74,
      confidence: 79,
      priority: 88,
      reports: 61,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-lahug',
      displayName: 'Lahug Local Neighborhood Zone',
      behaviorType: 'local_area',
      functionType: 'residential_zone',
      summary:
          'Mostly local neighborhood activity with carinderias and quiet side streets.',
      liveStatus: 'quiet_now',
      lat: 10.3388,
      lng: 123.8950,
      latRadius: 0.013,
      lngRadius: 0.014,
      crowd: 42,
      localPresence: 76,
      confidence: 67,
      priority: 74,
      reports: 35,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-university',
      displayName: 'USC Main Student Activity Zone',
      behaviorType: 'local_area',
      functionType: 'student_area',
      summary: 'Student movement around study hubs, cafes, and budget meals.',
      liveStatus: 'active_now',
      lat: 10.3075,
      lng: 123.8940,
      latRadius: 0.010,
      lngRadius: 0.012,
      crowd: 58,
      localPresence: 69,
      confidence: 73,
      priority: 82,
      reports: 49,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-port',
      displayName: 'Pier Transit + Safety Zone',
      behaviorType: 'mixed_area',
      functionType: 'transport_zone',
      summary:
          'Transport pressure, terminal movement, and safety awareness near the port.',
      liveStatus: 'peak_now',
      lat: 10.3044,
      lng: 123.9129,
      latRadius: 0.010,
      lngRadius: 0.012,
      crowd: 81,
      localPresence: 48,
      confidence: 71,
      priority: 86,
      reports: 52,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-carbon',
      displayName: 'Carbon Market Local Food + Shopping Zone',
      behaviorType: 'local_area',
      functionType: 'food_hotspot',
      summary:
          'Wet-market food, budget meals, and practical shopping movement.',
      liveStatus: 'busy_now',
      lat: 10.2944,
      lng: 123.9006,
      latRadius: 0.006,
      lngRadius: 0.008,
      crowd: 74,
      localPresence: 86,
      confidence: 81,
      priority: 87,
      reports: 55,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-fuente',
      displayName: 'Fuente Transit + Food Zone',
      behaviorType: 'local_area',
      functionType: 'transport_zone',
      summary:
          'Evening commute, Larsian food, and shopping overlap near Fuente.',
      liveStatus: 'busy_now',
      lat: 10.3105,
      lng: 123.8921,
      latRadius: 0.007,
      lngRadius: 0.009,
      crowd: 70,
      localPresence: 78,
      confidence: 77,
      priority: 84,
      reports: 50,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-busay',
      displayName: 'Busay Nature + Sunset Zone',
      behaviorType: 'tourist_area',
      functionType: 'tourist_hotspot',
      summary: 'Sunset drives, mountain cafes, and sightseeing near Tops.',
      liveStatus: 'active_now',
      lat: 10.3700,
      lng: 123.8780,
      latRadius: 0.010,
      lngRadius: 0.012,
      crowd: 62,
      localPresence: 24,
      confidence: 74,
      priority: 83,
      reports: 46,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-mactan',
      displayName: 'Mactan Resort + Beach Zone',
      behaviorType: 'tourist_area',
      functionType: 'tourist_hotspot',
      summary: 'Beach clubs, resorts, diving, seafood, and afternoon leisure.',
      liveStatus: 'active_now',
      lat: 10.2983,
      lng: 124.0155,
      latRadius: 0.012,
      lngRadius: 0.014,
      crowd: 59,
      localPresence: 18,
      confidence: 72,
      priority: 81,
      reports: 43,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-sirao',
      displayName: 'Sirao Flower Garden Nature Zone',
      behaviorType: 'tourist_area',
      functionType: 'tourist_hotspot',
      summary:
          'Flower garden visits, photo stops, and mountain-drive behavior.',
      liveStatus: 'active_now',
      lat: 10.3940,
      lng: 123.8680,
      latRadius: 0.010,
      lngRadius: 0.012,
      crowd: 46,
      localPresence: 22,
      confidence: 67,
      priority: 75,
      reports: 31,
    ),
    _legacyBlobFallbackZone(
      zoneId: 'dev-south-bus',
      displayName: 'South Bus Terminal Backpacker Transit Zone',
      behaviorType: 'local_area',
      functionType: 'transport_zone',
      summary:
          'Budget traveler and local commute behavior around bus departures.',
      liveStatus: 'busy_now',
      lat: 10.3001,
      lng: 123.8931,
      latRadius: 0.006,
      lngRadius: 0.008,
      crowd: 76,
      localPresence: 82,
      confidence: 75,
      priority: 82,
      reports: 47,
    ),
  ];
}

Map<String, dynamic> _geoJsonFromH3MultiPolygon(
  List<List<List<GeoCoord>>> multiPolygon,
) {
  if (multiPolygon.isEmpty) {
    return const {'type': 'Polygon', 'coordinates': <List<List<double>>>[]};
  }
  final polygons = <List<List<List<double>>>>[];
  for (final polygon in multiPolygon) {
    final rings = <List<List<double>>>[];
    for (final ring in polygon) {
      final pts = ring
          .map((g) => <double>[g.lon, g.lat])
          .toList(growable: false);
      if (pts.length < 3) continue;
      if (pts.first[0] != pts.last[0] || pts.first[1] != pts.last[1]) {
        rings.add([...pts, pts.first]);
      } else {
        rings.add(pts);
      }
    }
    if (rings.isNotEmpty) {
      polygons.add(rings);
    }
  }
  if (polygons.isEmpty) {
    return const {'type': 'Polygon', 'coordinates': <List<List<double>>>[]};
  }
  if (polygons.length == 1) {
    return {'type': 'Polygon', 'coordinates': polygons.first};
  }
  return {'type': 'MultiPolygon', 'coordinates': polygons};
}

List<List<List<double>>> _ringsForDisplayCells(H3 h3, List<H3Index> cells) {
  final rings = <List<List<double>>>[];
  for (final cell in cells) {
    final boundary = h3.cellToBoundary(cell);
    if (boundary.length < 3) continue;
    final ring = boundary.map((g) => <double>[g.lon, g.lat]).toList();
    if (ring.length >= 3) {
      final first = ring.first;
      final last = ring.last;
      if (first[0] != last[0] || first[1] != last[1]) {
        ring.add([first[0], first[1]]);
      }
    }
    if (ring.length >= 6) {
      rings.add(ring);
    }
  }
  return rings;
}

ZoneModel _fallbackZoneFromH3(
  H3 h3, {
  required String zoneId,
  required String displayName,
  required String behaviorType,
  required String functionType,
  required String summary,
  required String liveStatus,
  required double lat,
  required double lng,
  required double crowd,
  required double localPresence,
  required double confidence,
  required double priority,
  required int reports,
}) {
  final parent = h3.geoToCell(
    GeoCoord(lon: lng, lat: lat),
    _kFallbackH3AggregateRes,
  );
  var displayCells = h3.uncompactCells([
    parent,
  ], resolution: _kFallbackH3DisplayRes);
  if (displayCells.length > _kFallbackH3MaxDisplayCells) {
    displayCells = displayCells.sublist(0, _kFallbackH3MaxDisplayCells);
  }

  var mp = h3.cellsToMultiPolygon([parent]);
  if (mp.isEmpty) {
    final boundary = h3.cellToBoundary(parent);
    mp = [
      [boundary],
    ];
  }
  final polygonGeoJson = _geoJsonFromH3MultiPolygon(mp);
  final sourceH3Rings = _ringsForDisplayCells(h3, displayCells);
  final centroid = h3.cellToGeo(parent);

  return ZoneModel.fromJson({
    'zone_id': zoneId,
    'display_name': displayName,
    'behavior_type': behaviorType,
    'function_type': functionType,
    'summary': summary,
    'live_status': liveStatus,
    'polygon_geojson': polygonGeoJson,
    'centroid': {'lat': centroid.lat, 'lng': centroid.lon},
    'crowd_level': crowd,
    'local_presence_percent': localPresence,
    'peak_time_label': '4PM-9PM',
    'confidence_score': confidence,
    'priority_score': priority,
    'report_count': reports,
    'source_h3_rings': sourceH3Rings,
  });
}

List<ReportModel> _fallbackFeed() {
  final now = DateTime.now();
  return [
    ReportModel(
      id: 1,
      h3Index: '8928308280fffff',
      category: 'food',
      tags: const ['cafe', 'crowd'],
      note: 'Long line at lunch spots near IT Park.',
      createdAt: now.subtract(const Duration(minutes: 22)),
    ),
    ReportModel(
      id: 2,
      h3Index: '89283082813ffff',
      category: 'transport',
      tags: const ['bus', 'traffic'],
      note: 'Heavy outbound traffic toward Ayala around rush hour.',
      createdAt: now.subtract(const Duration(hours: 1, minutes: 15)),
    ),
    ReportModel(
      id: 3,
      h3Index: '89283082877ffff',
      category: 'crowd',
      tags: const ['event', 'busy'],
      note: 'Crowd building up near Fuente due to evening event.',
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    ReportModel(
      id: 4,
      h3Index: '89283082887ffff',
      category: 'safety',
      tags: const ['rain', 'caution'],
      note: 'Slippery sidewalks reported in parts of Colon Street.',
      createdAt: now.subtract(const Duration(hours: 5)),
    ),
    ReportModel(
      id: 5,
      h3Index: '892830828c7ffff',
      category: 'food',
      tags: const ['streetfood', 'local'],
      note: 'Night market stalls are now active near Carbon.',
      createdAt: now.subtract(const Duration(hours: 7)),
    ),
  ];
}

ZoneModel _legacyBlobFallbackZone({
  required String zoneId,
  required String displayName,
  required String behaviorType,
  required String functionType,
  required String summary,
  required String liveStatus,
  required double lat,
  required double lng,
  required double latRadius,
  required double lngRadius,
  required double crowd,
  required double localPresence,
  required double confidence,
  required double priority,
  required int reports,
}) {
  final boundary = _blobBoundary(lat, lng, latRadius, lngRadius);
  return ZoneModel(
    zoneId: zoneId,
    displayName: displayName,
    behaviorType: behaviorType,
    functionType: functionType,
    summary: summary,
    liveStatus: liveStatus,
    polygonGeoJson: {
      'type': 'Polygon',
      'coordinates': [boundary],
    },
    boundary: boundary,
    polygonParts: [
      [boundary],
    ],
    centroidLat: lat,
    centroidLng: lng,
    crowdLevel: crowd,
    localPresencePercent: localPresence,
    peakTimeLabel: '4PM-9PM',
    confidenceScore: confidence,
    priorityScore: priority,
    reportCount: reports,
    topActivities: const ['cafes', 'dining', 'shopping'],
    whyVisit: summary,
    liveUpdate: liveStatus,
  );
}

List<List<double>> _blobBoundary(
  double lat,
  double lng,
  double latRadius,
  double lngRadius,
) {
  const multipliers = [1.0, 0.78, 1.08, 0.86, 1.03, 0.82, 0.95, 0.74];
  return [
    for (var i = 0; i < multipliers.length; i++)
      [
        lng +
            math.cos((math.pi * 2 * i) / multipliers.length) *
                lngRadius *
                multipliers[i],
        lat +
            math.sin((math.pi * 2 * i) / multipliers.length) *
                latRadius *
                multipliers[i],
      ],
  ];
}

class TagSubmissionPayload {
  TagSubmissionPayload({
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.tags,
    this.note,
  });

  final double latitude;
  final double longitude;
  final String category;
  final List<String> tags;
  final String? note;

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'tags': tags,
      'note_text': note,
    };
  }
}

class TagSubmissionFeedback {
  const TagSubmissionFeedback({
    required this.h3Index,
    required this.pendingCount,
    required this.matchingCount,
    required this.threshold,
    required this.remainingToThreshold,
    required this.thresholdMet,
    required this.publicZoneUpdate,
  });

  final String h3Index;
  final int pendingCount;
  final int matchingCount;
  final int threshold;
  final int remainingToThreshold;
  final bool thresholdMet;
  final String publicZoneUpdate;

  factory TagSubmissionFeedback.fromJson(Map<String, dynamic> json) {
    return TagSubmissionFeedback(
      h3Index: (json['h3_index'] ?? '').toString(),
      pendingCount: _asInt(json['pending_count']),
      matchingCount: _asInt(json['matching_count']),
      threshold: _asInt(json['threshold']),
      remainingToThreshold: _asInt(json['remaining_to_threshold']),
      thresholdMet: json['threshold_met'] == true,
      publicZoneUpdate: (json['public_zone_update'] ?? '').toString(),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

final tagSubmissionProvider =
    StateNotifierProvider<
      TagSubmissionController,
      AsyncValue<TagSubmissionFeedback?>
    >((ref) {
      return TagSubmissionController(ref);
    });

class TagSubmissionController
    extends StateNotifier<AsyncValue<TagSubmissionFeedback?>> {
  TagSubmissionController(this.ref) : super(const AsyncData(null));

  final Ref ref;

  Future<TagSubmissionFeedback> submit(TagSubmissionPayload payload) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final token = ref.read(authTokenProvider);
      final isDemoSession = token == null || token == 'demo-token-local';
      if (isDemoSession) {
        // Demo/offline mode has no valid backend JWT, so keep the prototype flow
        // responsive while still refreshing local fallback providers.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        ref.invalidate(visibleZonesProvider);
        ref.invalidate(feedProvider);
        ref.invalidate(zoneFeedProvider);
        ref.invalidate(cityPulseProvider);
        final feedback = _demoFeedback(payload);
        state = AsyncData(feedback);
        return feedback;
      }
      final response = await dio.post(
        '/reports',
        data: payload.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data as Map<String, dynamic>;
      final feedback = TagSubmissionFeedback.fromJson(
        data['aggregation'] as Map<String, dynamic>,
      );
      ref.invalidate(visibleZonesProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(zoneFeedProvider);
      ref.invalidate(cityPulseProvider);
      state = AsyncData(feedback);
      return feedback;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  TagSubmissionFeedback _demoFeedback(TagSubmissionPayload payload) {
    try {
      final h3 = const H3Factory().load();
      final cell = h3.geoToCell(
        GeoCoord(lon: payload.longitude, lat: payload.latitude),
        _kFallbackH3AggregateRes,
      );
      return TagSubmissionFeedback(
        h3Index: cell.toString(),
        pendingCount: 1,
        matchingCount: 1,
        threshold: 3,
        remainingToThreshold: 2,
        thresholdMet: false,
        publicZoneUpdate: 'Zone will update after the threshold is reached.',
      );
    } catch (_) {
      return const TagSubmissionFeedback(
        h3Index: 'demo-h3-cell',
        pendingCount: 1,
        matchingCount: 1,
        threshold: 3,
        remainingToThreshold: 2,
        thresholdMet: false,
        publicZoneUpdate: 'Zone will update after the threshold is reached.',
      );
    }
  }
}

enum AuthMode { login, register }

final authActionProvider =
    StateNotifierProvider<AuthActionController, AsyncValue<void>>((ref) {
      return AuthActionController(ref);
    });

class AuthActionController extends StateNotifier<AsyncValue<void>> {
  AuthActionController(this.ref) : super(const AsyncData(null));

  final Ref ref;

  Future<void> submit({
    required AuthMode mode,
    required String email,
    required String password,
    String? displayName,
    bool acceptedResearchConsent = false,
  }) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        mode == AuthMode.login ? '/auth/login' : '/auth/register',
        data: {
          'email': email,
          'password': password,
          if (mode == AuthMode.register)
            'display_name': (displayName == null || displayName.trim().isEmpty)
                ? null
                : displayName.trim(),
          if (mode == AuthMode.register) 'traveler_type': 'mixed',
          if (mode == AuthMode.register)
            'accepted_research_consent': acceptedResearchConsent,
        },
      );
      final token = (response.data['access_token'] ?? '').toString();
      if (token.isEmpty) {
        throw Exception('Auth token missing from response.');
      }
      ref.read(authTokenProvider.notifier).state = token;
      ref.read(authUserEmailProvider.notifier).state = email.trim();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void loginDemoUser() {
    ref.read(authTokenProvider.notifier).state = 'demo-token-local';
    ref.read(authUserEmailProvider.notifier).state = 'demo@strollwise.local';
    state = const AsyncData(null);
  }
}
