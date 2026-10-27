import 'dart:math' as math;

class SensitiveSite {
  const SensitiveSite({
    required this.kind,
    required this.lat,
    required this.lng,
    required this.radiusM,
  });

  final String kind;
  final double lat;
  final double lng;
  final double radiusM;

  factory SensitiveSite.fromJson(Map<String, dynamic> json) {
    return SensitiveSite(
      kind: json['kind']?.toString() ?? 'building',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      radiusM: (json['radius_m'] as num?)?.toDouble() ?? 40,
    );
  }

  bool contains(double pointLat, double pointLng) =>
      metersBetween(pointLat, pointLng, lat, lng) <= radiusM;
}

const identityFacilityPhrases = <String>[
  'police station',
  'pnp',
  'camp sergio',
  'city hall',
  'city medical center',
  'cebu city medical',
  'hospital',
  'military camp',
  'jail',
  'precinct',
];

String pinOnBuildingCopy(String kind) {
  switch (kind) {
    case 'hospital':
      return 'Tag the street or a public place next to this, not the hospital itself.';
    case 'government':
      return 'Tag the street or a public place next to this, not city hall itself.';
    default:
      return 'Tag the street or a public place next to this, not the station itself.';
  }
}

SensitiveSite? siteContaining(
  Iterable<SensitiveSite> sites,
  double lat,
  double lng,
) {
  for (final site in sites) {
    if (site.contains(lat, lng)) return site;
  }
  return null;
}

bool textNamesFacility(String? text) {
  if (text == null || text.trim().isEmpty) return false;
  final blob = text.toLowerCase().replaceAll('_', ' ');
  return identityFacilityPhrases.any(blob.contains);
}

bool tagsNameFacility(Iterable<String> tags, String? note) {
  for (final tag in tags) {
    if (textNamesFacility(tag)) return true;
  }
  return textNamesFacility(note);
}

double metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final rLat1 = _toRad(lat1);
  final rLat2 = _toRad(lat2);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rLat1) *
          math.cos(rLat2) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earthKm * math.asin(math.sqrt(h)) * 1000;
}

double _toRad(double deg) => deg * math.pi / 180;

List<List<double>> circleRing(double lat, double lng, double radiusM, {int steps = 32}) {
  const metersPerDegLat = 111000.0;
  final metersPerDegLng =
      metersPerDegLat * math.cos(lat * math.pi / 180).abs().clamp(0.2, 1.0);
  final coords = <List<double>>[];
  for (var i = 0; i <= steps; i++) {
    final t = 2 * math.pi * i / steps;
    final dLat = (radiusM * math.sin(t)) / metersPerDegLat;
    final dLng = (radiusM * math.cos(t)) / metersPerDegLng;
    coords.add([lng + dLng, lat + dLat]);
  }
  return coords;
}

Map<String, dynamic> sensitiveSitesGeoJson(Iterable<SensitiveSite> sites) {
  return {
    'type': 'FeatureCollection',
    'features': [
      for (final site in sites)
        {
          'type': 'Feature',
          'properties': {'kind': site.kind},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [circleRing(site.lat, site.lng, site.radiusM)],
          },
        },
    ],
  };
}
