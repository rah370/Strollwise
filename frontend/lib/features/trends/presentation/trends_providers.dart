import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/place_recommendation.dart';
import '../../../shared/models/zone.dart';
import '../../../shared/models/zone_category_trends.dart';
import '../../../shared/network/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/zone_place_ui.dart';
import '../trends_copy.dart';
import 'places_to_go_sheet.dart';

class TrendsWindow {
  const TrendsWindow({required this.zoneId, required this.days});

  final String zoneId;
  final int days;

  @override
  bool operator ==(Object other) {
    return other is TrendsWindow && other.zoneId == zoneId && other.days == days;
  }

  @override
  int get hashCode => Object.hash(zoneId, days);
}

final trendsWindowDaysProvider = StateProvider<int>((ref) => 30);

final zoneCategoryTrendsProvider = FutureProvider.autoDispose
    .family<ZoneCategoryTrendsModel?, TrendsWindow>((ref, query) async {
  final token = ref.watch(authTokenProvider);
  if (query.zoneId.isEmpty) return null;
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get(
      '/analytics/zone/${query.zoneId}/category-trends',
      queryParameters: {'window_days': query.days},
      options: isLocalDemoSession(token)
          ? null
          : Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) return null;
    return ZoneCategoryTrendsModel.fromJson(data);
  } on DioException {
    return null;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
});

final zoneWalkingRouteProvider =
    FutureProvider.autoDispose.family<WalkingRoute?, ZoneModel>((ref, zone) async {
  final queries = [
    PlaceRecommendationsQuery(
      lat: zone.centroidLat,
      lng: zone.centroidLng,
      vibe: 'food',
      areaLabel: zoneDisplayTitle(zone),
    ),
    PlaceRecommendationsQuery(
      lat: zone.centroidLat,
      lng: zone.centroidLng,
      vibe: 'cafe',
      areaLabel: zoneDisplayTitle(zone),
    ),
    PlaceRecommendationsQuery(
      lat: zone.centroidLat,
      lng: zone.centroidLng,
      vibe: 'tourist',
      areaLabel: zoneDisplayTitle(zone),
    ),
  ];
  final buckets = await Future.wait(
    queries.map((query) => ref.read(placeRecommendationsProvider(query).future)),
  );
  final merged = <PlaceRecommendation>[];
  for (final bucket in buckets) {
    merged.addAll(bucket);
  }
  return buildWalkingRoute(
    areaName: zoneDisplayTitle(zone),
    originLat: zone.centroidLat,
    originLng: zone.centroidLng,
    places: merged,
  );
});
