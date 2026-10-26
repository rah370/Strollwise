import 'package:flutter/material.dart';

import '../app/theme/colors.dart';
import 'models/zone.dart';
import 'traveler_gradient.dart';

/// Human label for API `place_type` values.
String placeTypeLabel(String placeType) {
  switch (placeType.toLowerCase()) {
    case 'school':
      return 'School';
    case 'food':
      return 'Food';
    case 'transport':
      return 'Transport';
    case 'commercial':
      return 'Commercial';
    case 'residential':
      return 'Residential';
    case 'safety':
      return 'Safety';
    case 'tourist':
      return 'Tourist';
    case 'busy':
      return 'Busy';
    case 'emerging':
      return 'Emerging';
    default:
      return 'Area';
  }
}

IconData placeTypeIcon(String placeType) {
  switch (placeType.toLowerCase()) {
    case 'school':
      return Icons.school_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'transport':
      return Icons.directions_bus_outlined;
    case 'commercial':
      return Icons.shopping_bag_outlined;
    case 'residential':
      return Icons.home_outlined;
    case 'safety':
      return Icons.warning_amber_outlined;
    case 'tourist':
      return Icons.camera_alt_outlined;
    default:
      return Icons.place_outlined;
  }
}

Color placeTypeAccentColor(String placeType) {
  switch (placeType.toLowerCase()) {
    case 'school':
      return AppColors.zoneSchool;
    case 'food':
      return AppColors.zoneFood;
    case 'transport':
      return AppColors.zoneTransport;
    case 'commercial':
      return AppColors.zoneCommercial;
    case 'residential':
      return AppColors.zoneResidential;
    case 'safety':
      return AppColors.safetyBorder;
    case 'tourist':
      return AppColors.zoneTourist;
    default:
      return AppColors.mutedText;
  }
}

Color travelerMixFillColor(
  String travelerMix, {
  double? localPresencePercent,
  double? localRatio,
}) {
  final ratio = TravelerGradient.localRatioFromMix(
    travelerMix,
    localPresencePercent: localPresencePercent,
    localRatio: localRatio,
  );
  return TravelerGradient.fillForRatio(ratio);
}

Color travelerMixBorderColor(
  String travelerMix, {
  double? localPresencePercent,
  double? localRatio,
}) {
  final ratio = TravelerGradient.localRatioFromMix(
    travelerMix,
    localPresencePercent: localPresencePercent,
    localRatio: localRatio,
  );
  return TravelerGradient.colorForRatio(ratio);
}

Color travelerMixColorForZone(ZoneModel zone) =>
    TravelerGradient.colorForZone(zone);

Color travelerMixFillForZone(ZoneModel zone) =>
    TravelerGradient.fillForZone(zone);

String travelerMixLabel(String travelerMix) {
  switch (travelerMix) {
    case 'local':
      return 'Mostly local';
    case 'international':
      return 'Mostly international';
    default:
      return 'Mixed crowd';
  }
}

/// API `behavior_type`: local_area, tourist_area, mixed_area.
String zoneBehaviorLabel(String behaviorType) {
  switch (behaviorType.toLowerCase()) {
    case 'local_area':
      return 'Local area';
    case 'tourist_area':
      return 'Tourist area';
    case 'mixed_area':
      return 'Mixed area';
    default:
      return 'Area';
  }
}

/// Trend/analytics copy (e.g. "Local-heavy").
String travelerMixTrendLabel(String travelerMix) {
  switch (travelerMix) {
    case 'local':
      return 'Local-heavy';
    case 'international':
      return 'Tourist-heavy';
    default:
      return 'Mixed';
  }
}

/// Primary map/list title: catalog place name when linked.
String zoneDisplayTitle(ZoneModel zone) {
  final place = zone.placeName?.trim();
  if (place != null && place.isNotEmpty) {
    return place;
  }
  final name = zone.displayName.trim();
  if (name.isNotEmpty) {
    final nearIdx = name.toLowerCase().lastIndexOf(' near ');
    if (nearIdx >= 0 && nearIdx + 6 < name.length) {
      return name.substring(nearIdx + 6).trim();
    }
    return name;
  }
  return 'Area';
}

/// Map label subtitle: who uses the area · what it is.
String zoneMapSubtitle(ZoneModel zone) {
  final who = travelerMixLabel(zone.travelerMix);
  final what = zone.placeType ?? zone.zoneType;
  if (what.isNotEmpty) {
    return '$who · ${placeTypeLabel(what)}';
  }
  return who;
}

String zoneSignalCountLabel(int count) {
  if (count <= 0) return 'No signals yet';
  if (count == 1) return '1 signal';
  return '$count signals';
}

/// Place names shown on a tapped hexagon.
String zoneHexagonPlaceLine(ZoneModel zone) {
  final named = <String>[];
  void addName(String? raw) {
    final name = raw?.trim() ?? '';
    if (name.isEmpty || name.toLowerCase() == 'area') return;
    if (named.any((existing) => existing.toLowerCase() == name.toLowerCase())) {
      return;
    }
    named.add(name);
  }

  addName(zoneDisplayTitle(zone));
  for (final place in zone.places) {
    addName(place.displayName);
  }
  if (named.isEmpty) return 'This area';
  if (named.length == 1) return named.first;
  if (named.length == 2) return '${named[0]} · ${named[1]}';
  return '${named.first} + ${named.length - 1} places';
}

/// Single-line map label: place(s) and how many tags validated the hex.
String zoneHexagonTapLabel(ZoneModel zone) {
  return '${zoneHexagonPlaceLine(zone)} · ${zoneSignalCountLabel(zone.reportCount)}';
}
