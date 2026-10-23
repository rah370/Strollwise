import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../shared/models/place_recommendation.dart';
import '../../shared/models/zone.dart';
import '../../shared/models/zone_category_trends.dart';
import '../../shared/zone_place_ui.dart';

enum TrendsSection { forYou, vibes, routes }

class TrendVibe {
  const TrendVibe({
    required this.title,
    required this.subtitle,
    required this.vibeKey,
    required this.icon,
    required this.fill,
    required this.accent,
    required this.placeTypes,
  });

  final String title;
  final String subtitle;
  final String vibeKey;
  final IconData icon;
  final Color fill;
  final Color accent;
  final Set<String> placeTypes;
}

class WalkingStop {
  const WalkingStop({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
}

class WalkingRoute {
  const WalkingRoute({
    required this.title,
    required this.stops,
    required this.distanceKm,
    required this.walkMinutes,
  });

  final String title;
  final List<WalkingStop> stops;
  final double distanceKm;
  final int walkMinutes;

  String get metaLabel {
    final km = distanceKm < 0.1
        ? '${(distanceKm * 1000).round()} m'
        : '${distanceKm.toStringAsFixed(1)} km';
    return '$km · ~$walkMinutes min walk';
  }
}

const List<TrendVibe> kTrendVibes = [
  TrendVibe(
    title: 'Food crawl',
    subtitle: 'Street eats and local food',
    vibeKey: 'food',
    icon: Icons.restaurant_outlined,
    fill: AppColors.foodFill,
    accent: AppColors.foodAccent,
    placeTypes: {'food', 'commercial', 'busy'},
  ),
  TrendVibe(
    title: 'Cafes & study',
    subtitle: 'Work and study spots',
    vibeKey: 'cafe',
    icon: Icons.local_cafe_outlined,
    fill: AppColors.studentFill,
    accent: AppColors.studentAccent,
    placeTypes: {'school', 'commercial', 'food'},
  ),
  TrendVibe(
    title: 'Hidden spots',
    subtitle: 'Local recommendations',
    vibeKey: 'food',
    icon: Icons.explore_outlined,
    fill: AppColors.mixedFill,
    accent: AppColors.mixedAccent,
    placeTypes: {'residential', 'food', 'mixed'},
  ),
  TrendVibe(
    title: 'Shopping',
    subtitle: 'Markets and malls',
    vibeKey: 'tourist',
    icon: Icons.shopping_bag_outlined,
    fill: AppColors.commercialFill,
    accent: AppColors.commercialAccent,
    placeTypes: {'commercial', 'tourist'},
  ),
  TrendVibe(
    title: 'Nightlife',
    subtitle: 'After-dark social zones',
    vibeKey: 'nightlife',
    icon: Icons.nightlife_outlined,
    fill: AppColors.hotelFill,
    accent: AppColors.hotelAccent,
    placeTypes: {'commercial', 'tourist', 'busy'},
  ),
  TrendVibe(
    title: 'Nature escape',
    subtitle: 'Parks, views, and shade',
    vibeKey: 'nature',
    icon: Icons.landscape_outlined,
    fill: AppColors.touristFill,
    accent: AppColors.touristAccent,
    placeTypes: {'tourist', 'residential'},
  ),
  TrendVibe(
    title: 'Student life',
    subtitle: 'Campus and budget hubs',
    vibeKey: 'cafe',
    icon: Icons.school_outlined,
    fill: AppColors.studentFill,
    accent: AppColors.studentAccent,
    placeTypes: {'school'},
  ),
  TrendVibe(
    title: 'Heritage walk',
    subtitle: 'History and culture',
    vibeKey: 'tourist',
    icon: Icons.museum_outlined,
    fill: AppColors.localFill,
    accent: AppColors.localAccent,
    placeTypes: {'tourist'},
  ),
  TrendVibe(
    title: 'Transit',
    subtitle: 'Commute corridors',
    vibeKey: 'budget',
    icon: Icons.directions_bus_outlined,
    fill: AppColors.transportFill,
    accent: AppColors.transportAccent,
    placeTypes: {'transport'},
  ),
  TrendVibe(
    title: 'Budget travel',
    subtitle: 'Cheap stays and eats',
    vibeKey: 'budget',
    icon: Icons.savings_outlined,
    fill: AppColors.transportFill,
    accent: AppColors.transportAccent,
    placeTypes: {'food', 'residential', 'transport'},
  ),
];

const int kMinRouteStops = 2;
const int kDefaultVibesPreview = 4;
const int kVibesTabPreview = 6;

String trendsZoneTitle(ZoneModel? zone) {
  if (zone == null) return 'Cebu City';
  return zoneDisplayTitle(zone);
}

String trendsZoneSubtitle(ZoneModel? zone) {
  if (zone == null) return 'Pick a zone on Explore to see local trends.';
  final type = placeTypeLabel(zone.placeType ?? zone.zoneType);
  final mix = switch (zone.travelerMix) {
    'local' => 'Mostly local area',
    'international' => 'Visitor-heavy area',
    _ => 'Mixed-use area',
  };
  return '$type · $mix';
}

String formatPeakPeriod(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return 'Peak hours vary';
  return value
      .replaceAll('–', '–')
      .replaceAll('-', '–')
      .replaceAll('AM', ' AM')
      .replaceAll('PM', ' PM')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

String notEnoughTrendCopy(int minSample) {
  return 'Not enough recent activity to identify a trend. '
      'StrollWise needs at least $minSample approved tags in this window.';
}

String categoryTrendDetail(CategoryTrendModel row, int windowDays) {
  final prev = 'previous $windowDays days';
  if (row.growing) {
    final more = row.delta == 1 ? '1 more approved tag' : '${row.delta} more approved tags';
    return '$more than the $prev (${row.previousCount} → ${row.currentCount}).';
  }
  if (row.currentCount > 0 && row.delta == 0) {
    return '${row.currentCount} approved tags — same as the $prev. Busy, not growing.';
  }
  if (row.delta < 0) {
    return '${row.currentCount} approved tags, ${row.delta.abs()} fewer than the $prev.';
  }
  return '${row.currentCount} approved tags in the last $windowDays days.';
}

List<TrendVibe> relevantVibes(ZoneModel? zone, {int limit = kVibesTabPreview}) {
  final type = (zone?.placeType ?? zone?.zoneType ?? '').toLowerCase();
  final ranked = [...kTrendVibes]
    ..sort((a, b) {
      final aHit = a.placeTypes.contains(type) ? 1 : 0;
      final bHit = b.placeTypes.contains(type) ? 1 : 0;
      if (aHit != bHit) return bHit.compareTo(aHit);
      return kTrendVibes.indexOf(a).compareTo(kTrendVibes.indexOf(b));
    });
  return ranked.take(limit).toList();
}

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRad(double deg) => deg * math.pi / 180;

WalkingStop? stopFromRecommendation(PlaceRecommendation place) {
  final name = place.name.trim();
  if (name.isEmpty) return null;
  return WalkingStop(
    name: name,
    address: place.address.trim(),
    lat: place.latitude,
    lng: place.longitude,
  );
}

WalkingRoute? buildWalkingRoute({
  required String areaName,
  required double originLat,
  required double originLng,
  required List<PlaceRecommendation> places,
}) {
  final unique = <String, WalkingStop>{};
  for (final place in places) {
    final stop = stopFromRecommendation(place);
    if (stop == null) continue;
    unique.putIfAbsent(stop.name.toLowerCase(), () => stop);
  }
  if (unique.length < kMinRouteStops) return null;

  final remaining = unique.values.toList();
  final ordered = <WalkingStop>[];
  var lat = originLat;
  var lng = originLng;
  while (remaining.isNotEmpty && ordered.length < 4) {
    remaining.sort(
      (a, b) => haversineKm(lat, lng, a.lat, a.lng).compareTo(
        haversineKm(lat, lng, b.lat, b.lng),
      ),
    );
    final next = remaining.removeAt(0);
    ordered.add(next);
    lat = next.lat;
    lng = next.lng;
  }
  if (ordered.length < kMinRouteStops) return null;

  var pathKm = 0.0;
  for (var i = 1; i < ordered.length; i++) {
    pathKm += haversineKm(
          ordered[i - 1].lat,
          ordered[i - 1].lng,
          ordered[i].lat,
          ordered[i].lng,
        ) *
        1.25;
  }
  final minutes = math.max(8, (pathKm / 4.5 * 60).round());
  return WalkingRoute(
    title: 'Walk around $areaName',
    stops: ordered,
    distanceKm: pathKm,
    walkMinutes: minutes,
  );
}

List<CategoryTrendModel> growingCategories(ZoneCategoryTrendsModel trends) {
  return trends.categories.where((row) => row.growing && row.currentCount > 0).toList();
}
