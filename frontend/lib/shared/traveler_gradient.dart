import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/colors.dart';
import 'models/cell.dart';
import 'models/zone.dart';

/// Green (#22C55E) ↔ blue (#3B82F6) behavioral gradient for map zones.
class TravelerGradient {
  static const Color local = Color(0xFF22C55E);
  static const Color international = Color(0xFF3B82F6);
  static const Color midpoint = Color(0xFF2FB7C8);

  static const int _localR = 34;
  static const int _localG = 197;
  static const int _localB = 94;
  static const int _intlR = 59;
  static const int _intlG = 130;
  static const int _intlB = 246;

  static double clampRatio(double ratio) => ratio.clamp(0.0, 1.0);

  static double localRatioFromPresence(double localPresencePercent) {
    if (localPresencePercent <= 0) return 0.5;
    return clampRatio(localPresencePercent / 100.0);
  }

  static double localRatioFromMix(
    String travelerMix, {
    double? localPresencePercent,
    double? localRatio,
  }) {
    if (localRatio != null && localRatio > 0) {
      return clampRatio(localRatio);
    }
    if (localPresencePercent != null && localPresencePercent > 0) {
      return localRatioFromPresence(localPresencePercent);
    }
    return switch (travelerMix.toLowerCase()) {
      'local' => 1.0,
      'international' => 0.0,
      _ => 0.5,
    };
  }

  static double localRatioForZone(ZoneModel zone) {
    final fromApi = zone.localRatio;
    if (fromApi != null) return clampRatio(fromApi);
    final catalog = ZoneCatalog.lookup(zone.displayName);
    if (catalog != null) return catalog.defaultLocalRatio;
    return localRatioFromMix(
      zone.travelerMix,
      localPresencePercent: zone.localPresencePercent,
    );
  }

  static double localRatioForCell(CellModel cell) {
    final fromApi = cell.localRatio;
    if (fromApi != null) return clampRatio(fromApi);
    return localRatioFromMix(cell.travelerMix);
  }

  static Color colorForRatio(double localRatio) {
    final t = clampRatio(localRatio);
    final r = (_localR * t + _intlR * (1 - t)).round();
    final g = (_localG * t + _intlG * (1 - t)).round();
    final b = (_localB * t + _intlB * (1 - t)).round();
    return Color.fromARGB(255, r, g, b);
  }

  static Color fillForRatio(double localRatio, {double blend = 0.72}) {
    final base = colorForRatio(localRatio);
    final b = blend.clamp(0.0, 1.0);
    return Color.lerp(Colors.white, base, b) ?? base.withValues(alpha: 0.35);
  }

  static String hexForRatio(double localRatio) {
    final c = colorForRatio(localRatio);
    final value = c.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static String fillHexForRatio(double localRatio, {double blend = 0.72}) {
    final c = fillForRatio(localRatio, blend: blend);
    final value = c.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color colorForZone(ZoneModel zone) {
    final hex = zone.mapColor;
    if (hex != null && hex.length >= 7) {
      return _colorFromHex(hex);
    }
    return colorForRatio(localRatioForZone(zone));
  }

  static Color fillForZone(ZoneModel zone) =>
      fillForRatio(localRatioForZone(zone));

  static Color colorForCell(CellModel cell) {
    final hex = cell.mapColor;
    if (hex != null && hex.length >= 7) {
      return _colorFromHex(hex);
    }
    return colorForRatio(localRatioForCell(cell));
  }

  static Color _colorFromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return midpoint;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return midpoint;
    return Color(0xFF000000 | value);
  }

  static String dominanceLabel(double localRatio) {
    final t = clampRatio(localRatio);
    if (t >= 0.85) return 'Mostly local';
    if (t <= 0.15) return 'Mostly international';
    if (t >= 0.6) return 'Local-leaning mix';
    if (t <= 0.4) return 'Visitor-leaning mix';
    return 'Balanced mix';
  }
}

class ZoneCatalogEntry {
  const ZoneCatalogEntry({
    required this.zoneId,
    required this.zoneName,
    required this.city,
    required this.zoneType,
    required this.defaultLocalRatio,
    required this.centerLat,
    required this.centerLng,
  });

  final String zoneId;
  final String zoneName;
  final String city;
  final String zoneType;
  final double defaultLocalRatio;
  final double centerLat;
  final double centerLng;

  factory ZoneCatalogEntry.fromJson(Map<String, dynamic> json) {
    final center = json['center'] as Map<String, dynamic>? ?? const {};
    return ZoneCatalogEntry(
      zoneId: (json['zone_id'] ?? '').toString(),
      zoneName: (json['zone_name'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      zoneType: (json['zone_type'] ?? 'MIXED').toString(),
      defaultLocalRatio:
          (json['default_local_ratio'] as num?)?.toDouble() ??
          _ratioFromType((json['zone_type'] ?? 'MIXED').toString()),
      centerLat: (center['lat'] as num?)?.toDouble() ?? 0,
      centerLng: (center['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  static double _ratioFromType(String zoneType) {
    switch (zoneType.toUpperCase()) {
      case 'LOCAL':
        return 1.0;
      case 'INTERNATIONAL':
        return 0.0;
      default:
        return 0.5;
    }
  }
}

class ZoneCatalog {
  ZoneCatalog._();

  static List<ZoneCatalogEntry>? _entries;

  static Future<void> ensureLoaded() async {
    if (_entries != null) return;
    final raw = await rootBundle.loadString(
      'assets/data/cebu_zone_catalog.json',
    );
    final list = jsonDecode(raw) as List<dynamic>;
    _entries = list
        .whereType<Map>()
        .map((e) => ZoneCatalogEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  static List<ZoneCatalogEntry> get entries {
    return _entries ?? const [];
  }

  static ZoneCatalogEntry? lookup(String displayName) {
    final key = displayName.toLowerCase().trim();
    for (final entry in entries) {
      final name = entry.zoneName.toLowerCase();
      if (name == key || key.contains(name) || name.contains(key)) {
        return entry;
      }
    }
    return null;
  }

  /// Nearest catalog zone centroid to a map point (offline / API fallback).
  static ZoneCatalogEntry? nearestEntry(double lat, double lng) {
    final list = entries;
    if (list.isEmpty) return null;
    ZoneCatalogEntry? best;
    var bestKm = double.infinity;
    for (final entry in list) {
      final km = _haversineKm(lat, lng, entry.centerLat, entry.centerLng);
      if (km < bestKm) {
        bestKm = km;
        best = entry;
      }
    }
    return best;
  }
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.asin(math.sqrt(a));
  return earthRadiusKm * c;
}

double _toRad(double deg) => deg * (3.141592653589793 / 180.0);

/// Gradient strip legend: green (local) → cyan → blue (international).
class TravelerBehaviorGradientLegend extends StatelessWidget {
  const TravelerBehaviorGradientLegend({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Behavior hue',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          const Text(
            'Green = local life · Blue = visitor flow · Teal = overlap',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          height: compact ? 10 : 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [
                TravelerGradient.local,
                Color(0xFF38BFA0),
                TravelerGradient.midpoint,
                Color(0xFF3696E8),
                TravelerGradient.international,
              ],
            ),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Local',
              style: TextStyle(
                color: AppColors.localAccent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Mixed',
              style: TextStyle(
                color: AppColors.mixedAccent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'International',
              style: TextStyle(
                color: AppColors.touristAccent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
