import 'models/zone.dart';

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
