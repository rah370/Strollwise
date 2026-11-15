import 'package:h3_flutter/h3_flutter.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'models/report.dart';

/// Decode an H3 index to a centroid for map markers. Not a GPS trail.
LatLng? latLngFromH3Index(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  try {
    final h3 = const H3Factory().load();
    final hexish = value.toLowerCase().replaceFirst('0x', '');
    final cell = hexish.contains(RegExp(r'[a-f]'))
        ? BigInt.tryParse(hexish, radix: 16)
        : (BigInt.tryParse(hexish) ?? BigInt.tryParse(hexish, radix: 16));
    if (cell == null) return null;
    final geo = h3.cellToGeo(cell);
    if (geo.lat.abs() > 90 || geo.lon.abs() > 180) return null;
    return LatLng(geo.lat, geo.lon);
  } catch (_) {
    return null;
  }
}

/// Owner-only map focus for a submitted tag: cell centroid, never public GPS.
LatLng? latLngForReport(ReportModel report) {
  final lat = report.cellLat;
  final lng = report.cellLng;
  if (lat != null && lng != null && (lat != 0 || lng != 0)) {
    return LatLng(lat, lng);
  }
  return latLngFromH3Index(report.h3Index);
}
