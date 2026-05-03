import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

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
    return (response.data as List)
        .map((zone) => ZoneModel.fromJson(zone as Map<String, dynamic>))
        .where((zone) => zone.boundary.length >= 3)
        .toList();
  } on DioException {
    return _fallbackVisibleZones(filter);
  } on FormatException {
    return _fallbackVisibleZones(filter);
  } on TypeError {
    return _fallbackVisibleZones(filter);
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

List<ZoneModel> _fallbackVisibleZones(String? filter) {
  final zones = <ZoneModel>[
    _fallbackZone(
      zoneId: 'dev-it-park',
      displayName: 'IT Park',
      behaviorType: 'tourist_area',
      functionType: 'commercial_zone',
      summary: 'High activity, cafes, offices, nightlife',
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
    _fallbackZone(
      zoneId: 'dev-ayala',
      displayName: 'Ayala Center',
      behaviorType: 'mixed_area',
      functionType: 'commercial_zone',
      summary: 'Balanced mix of locals and visitors',
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
    _fallbackZone(
      zoneId: 'dev-colon',
      displayName: 'Colon Street',
      behaviorType: 'local_area',
      functionType: 'food_hotspot',
      summary: 'Affordable local food and busy streets',
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
    _fallbackZone(
      zoneId: 'dev-lahug',
      displayName: 'Lahug',
      behaviorType: 'local_area',
      functionType: 'residential_zone',
      summary: 'Mostly locals, more relaxed pace',
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
    _fallbackZone(
      zoneId: 'dev-university',
      displayName: 'University Zone',
      behaviorType: 'local_area',
      functionType: 'student_area',
      summary: 'Students, cafes, budget-friendly places',
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
    _fallbackZone(
      zoneId: 'dev-port',
      displayName: 'Port Area',
      behaviorType: 'mixed_area',
      functionType: 'transport_zone',
      summary: 'Traffic pressure and transport activity',
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
  ];

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

ZoneModel _fallbackZone({
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

final tagSubmissionProvider =
    StateNotifierProvider<TagSubmissionController, AsyncValue<void>>((ref) {
      return TagSubmissionController(ref);
    });

class TagSubmissionController extends StateNotifier<AsyncValue<void>> {
  TagSubmissionController(this.ref) : super(const AsyncData(null));

  final Ref ref;

  Future<void> submit(TagSubmissionPayload payload) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final token = ref.read(authTokenProvider);
      await dio.post(
        '/reports',
        data: payload.toJson(),
        options: Options(
          headers: token == null ? null : {'Authorization': 'Bearer $token'},
        ),
      );
      ref.invalidate(visibleZonesProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(cityPulseProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
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
