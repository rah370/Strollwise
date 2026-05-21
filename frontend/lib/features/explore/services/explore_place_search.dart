import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../shared/models/zone.dart';
import '../../../shared/traveler_gradient.dart';

enum ExploreSearchHitKind { zone, landmark, address }

class ExploreSearchHit {
  const ExploreSearchHit({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.kind,
    this.zone,
    this.localRatio,
  });

  final String id;
  final String title;
  final String subtitle;
  final LatLng location;
  final ExploreSearchHitKind kind;
  final ZoneModel? zone;
  final double? localRatio;
}

/// Cebu metro bounding box for Nominatim (west,south,east,north).
const _cebuViewbox = '123.70,10.15,124.15,10.50';

class ExplorePlaceSearchService {
  ExplorePlaceSearchService(this._dio);

  final Dio _dio;

  static const _cebuCenter = LatLng(10.3157, 123.8854);
  static const _cebuRadiusM = 120000.0;

  static final Map<String, LatLng> _landmarks = {
    'ayala': const LatLng(10.3176, 123.9053),
    'ayala center': const LatLng(10.3176, 123.9053),
    'ayala center cebu': const LatLng(10.3176, 123.9053),
    'it park': const LatLng(10.3305, 123.9066),
    'cebu it park': const LatLng(10.3305, 123.9066),
    'it park business zone': const LatLng(10.3305, 123.9066),
    'colon': const LatLng(10.2943, 123.9018),
    'colon street': const LatLng(10.2943, 123.9018),
    'colon basilica': const LatLng(10.2943, 123.9018),
    'carbon': const LatLng(10.2932, 123.8997),
    'carbon market': const LatLng(10.2932, 123.8997),
    'magellan cross': const LatLng(10.2930, 123.9029),
    'basilica': const LatLng(10.2942, 123.9022),
    'santo nino': const LatLng(10.2942, 123.9022),
    'fort san pedro': const LatLng(10.2922, 123.9058),
    'fuente': const LatLng(10.3099, 123.8915),
    'fuente osmena': const LatLng(10.3099, 123.8915),
    'fuente osmeña': const LatLng(10.3099, 123.8915),
    'mango avenue': const LatLng(10.3109, 123.8953),
    'mango': const LatLng(10.3109, 123.8953),
    'sm city': const LatLng(10.3113, 123.9180),
    'sm city cebu': const LatLng(10.3113, 123.9180),
    'sm seaside': const LatLng(10.2816, 123.8810),
    'srp': const LatLng(10.2867, 123.8805),
    'south road properties': const LatLng(10.2867, 123.8805),
    'pier': const LatLng(10.3003, 123.9122),
    'cebu port': const LatLng(10.3003, 123.9122),
    'usc': const LatLng(10.3006, 123.8989),
    'university of san carlos': const LatLng(10.3006, 123.8989),
    'uspf': const LatLng(10.3382, 123.9014),
    'university of southern philippines foundation':
        const LatLng(10.3382, 123.9014),
    'salinas drive': const LatLng(10.3370, 123.9025),
    'lahug': const LatLng(10.3359, 123.9023),
    'jy square': const LatLng(10.3359, 123.9023),
    'talamban': const LatLng(10.3550, 123.9180),
    'pardo': const LatLng(10.2815, 123.8450),
    'minglanilla': const LatLng(10.2441, 123.7964),
    'talisay': const LatLng(10.2447, 123.8494),
    'mactan': const LatLng(10.2995, 124.0118),
    'lapu-lapu': const LatLng(10.2995, 124.0118),
    'robinsons galleria cebu': const LatLng(10.3170, 123.9170),
    'robinsons cybergate': const LatLng(10.3300, 123.9080),
    'cebu business park': const LatLng(10.3305, 123.9066),
    'queen city memorial garden': const LatLng(10.3180, 123.8900),
    'cebu doctors hospital': const LatLng(10.3099, 123.8916),
    'chong hua': const LatLng(10.3050, 123.8950),
    'landmark': const LatLng(10.3170, 123.9050),
    'robinsons mall': const LatLng(10.3170, 123.9170),
  };

  Future<List<ExploreSearchHit>> search(
    String rawQuery, {
    required List<ZoneModel> zones,
    int maxResults = 8,
  }) async {
    final query = rawQuery.trim();
    if (query.length < 2) return const [];

    final q = query.toLowerCase();
    final seen = <String>{};
    final hits = <ExploreSearchHit>[];

    void add(ExploreSearchHit hit) {
      if (hits.length >= maxResults) return;
      if (!seen.add(hit.id)) return;
      hits.add(hit);
    }

    for (final zone in zones) {
      if (!_matchesTerms(_haystack(zone), q)) continue;
      add(
        ExploreSearchHit(
          id: 'zone-${zone.zoneId}',
          title: zone.displayName,
          subtitle: _zoneSubtitle(zone),
          location: LatLng(zone.centroidLat, zone.centroidLng),
          kind: ExploreSearchHitKind.zone,
          zone: zone,
          localRatio: TravelerGradient.localRatioForZone(zone),
        ),
      );
    }

    await ZoneCatalog.ensureLoaded();
    for (final entry in ZoneCatalog.entries) {
      final hay =
          '${entry.zoneName} ${entry.city} ${entry.zoneType}'.toLowerCase();
      if (!_matchesTerms(hay, q)) continue;
      add(
        ExploreSearchHit(
          id: 'catalog-${entry.zoneId}',
          title: entry.zoneName,
          subtitle: '${entry.city} · ${_mixLabel(entry.defaultLocalRatio)}',
          location: LatLng(entry.centerLat, entry.centerLng),
          kind: ExploreSearchHitKind.landmark,
          localRatio: entry.defaultLocalRatio,
        ),
      );
    }

    for (final place in _landmarks.entries) {
      if (!_matchesTerms(place.key, q)) continue;
      add(
        ExploreSearchHit(
          id: 'landmark-${place.key}',
          title: _titleCase(place.key),
          subtitle: 'Cebu landmark',
          location: place.value,
          kind: ExploreSearchHitKind.landmark,
        ),
      );
    }

    final remote = await _nominatimSearch(query, limit: maxResults - hits.length);
    for (final hit in remote) {
      add(hit);
    }

    return hits;
  }

  Future<List<ExploreSearchHit>> _nominatimSearch(
    String query, {
    required int limit,
  }) async {
    if (limit <= 0) return const [];
    try {
      final response = await _dio.getUri(
        Uri.https('nominatim.openstreetmap.org', '/search', {
          'format': 'json',
          'limit': limit.clamp(1, 8).toString(),
          'addressdetails': '1',
          'countrycodes': 'ph',
          'viewbox': _cebuViewbox,
          'bounded': '0',
          'q': '$query, Cebu, Philippines',
        }),
        options: Options(
          headers: const {
            'User-Agent':
                'StrollWise/1.0 (Cebu place search; demo@strollwise.local)',
          },
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final results = response.data;
      if (results is! List) return const [];

      final hits = <ExploreSearchHit>[];
      for (final raw in results) {
        if (raw is! Map) continue;
        final lat = double.tryParse(raw['lat']?.toString() ?? '');
        final lng = double.tryParse(raw['lon']?.toString() ?? '');
        if (lat == null || lng == null) continue;
        final loc = LatLng(lat, lng);
        if (!_isWithinCebuRegion(loc)) continue;

        final display = (raw['display_name'] ?? query).toString();
        final parts = display.split(',');
        final title = parts.isNotEmpty ? parts.first.trim() : query;
        final subtitle = _nominatimSubtitle(raw, parts);

        hits.add(
          ExploreSearchHit(
            id: 'osm-${lat.toStringAsFixed(5)}-${lng.toStringAsFixed(5)}',
            title: title,
            subtitle: subtitle,
            location: loc,
            kind: ExploreSearchHitKind.address,
          ),
        );
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }

  static String _nominatimSubtitle(Map raw, List<String> parts) {
    final type = (raw['type'] ?? raw['class'] ?? '').toString();
    final category = (raw['category'] ?? '').toString();
    if (type.isNotEmpty && category.isNotEmpty) {
      return '${_titleCase(category)} · ${_titleCase(type)}';
    }
    if (parts.length >= 2) {
      return parts.sublist(1, parts.length.clamp(1, 3)).join(', ').trim();
    }
    return 'Street or place in Cebu';
  }

  static bool _isWithinCebuRegion(LatLng location) {
    final d = Geolocator.distanceBetween(
      _cebuCenter.latitude,
      _cebuCenter.longitude,
      location.latitude,
      location.longitude,
    );
    return d <= _cebuRadiusM;
  }

  static String _haystack(ZoneModel zone) {
    return [
      zone.displayName,
      zone.placeName ?? '',
      zone.behaviorType,
      zone.travelerMix,
      zone.zoneType,
      zone.summary ?? '',
      ...zone.topActivities,
    ].join(' ').toLowerCase();
  }

  static String _zoneSubtitle(ZoneModel zone) {
    final mix = TravelerGradient.dominanceLabel(
      TravelerGradient.localRatioForZone(zone),
    );
    if (zone.reportCount > 0) {
      return '$mix · ${zone.reportCount} tags';
    }
    return mix;
  }

  static bool _matchesTerms(String haystack, String query) {
    final terms = query.split(RegExp(r'\s+')).where((t) => t.length >= 2);
    return terms.every(haystack.contains);
  }

  static String _mixLabel(double ratio) {
    return TravelerGradient.dominanceLabel(ratio);
  }

  static String _titleCase(String value) {
    return value
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
