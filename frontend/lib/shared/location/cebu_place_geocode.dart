import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const double cebuServiceAreaRadiusM = 120000;
const LatLng cebuServiceAreaCenter = LatLng(10.3157, 123.8854);

const Map<String, LatLng> cebuKnownPlaces = {
  'ayala': LatLng(10.3173, 123.9058),
  'ayala center': LatLng(10.3173, 123.9058),
  'it park': LatLng(10.3304, 123.9072),
  'cebu it park': LatLng(10.3304, 123.9072),
  'colon': LatLng(10.2966, 123.8986),
  'colon street': LatLng(10.2966, 123.8986),
  'carbon market': LatLng(10.2954, 123.8994),
  'magellan': LatLng(10.2930, 123.9029),
  'magellan cross': LatLng(10.2930, 123.9029),
  'basilica': LatLng(10.2942, 123.9022),
  'santo nino': LatLng(10.2942, 123.9022),
  'fort san pedro': LatLng(10.2922, 123.9058),
  'fuente': LatLng(10.3094, 123.8931),
  'fuente osmena': LatLng(10.3094, 123.8931),
  'mango': LatLng(10.3109, 123.8953),
  'mango avenue': LatLng(10.3109, 123.8953),
  'ramon duterte': LatLng(10.3145, 123.8868),
  'vicente rama': LatLng(10.3162, 123.8885),
  'south bus': LatLng(10.3002, 123.8931),
  'south bus terminal': LatLng(10.3002, 123.8931),
  'sm city': LatLng(10.3112, 123.9187),
  'sm seaside': LatLng(10.2816, 123.8810),
  'pier': LatLng(10.3003, 123.9122),
  'port area': LatLng(10.3003, 123.9122),
  'j solon': LatLng(10.3181, 123.9021),
  'usc': LatLng(10.3006, 123.8989),
  'university of san carlos': LatLng(10.3006, 123.8989),
  'uspf': LatLng(10.3382, 123.9014),
  'university of southern philippines foundation': LatLng(10.3382, 123.9014),
  'salinas drive': LatLng(10.3370, 123.9025),
  'salinas': LatLng(10.3370, 123.9025),
  'jy square': LatLng(10.3359, 123.9023),
  'jy square lahug': LatLng(10.3359, 123.9023),
  'jy': LatLng(10.3359, 123.9023),
  'cebu doctors': LatLng(10.3099, 123.8916),
};

bool cebuPlaceWithinServiceArea(LatLng location) {
  return Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        cebuServiceAreaCenter.latitude,
        cebuServiceAreaCenter.longitude,
      ) <=
      cebuServiceAreaRadiusM;
}

LatLng? lookupCebuPlaceLocal(String query) {
  final normalized = query.toLowerCase().trim();
  if (normalized.isEmpty) return null;
  for (final place in cebuKnownPlaces.entries) {
    final key = place.key;
    if (normalized.contains(key) || key.contains(normalized)) {
      return place.value;
    }
  }
  return null;
}

/// Resolves a free-text place (street, mall, landmark) inside greater Cebu.
Future<LatLng?> geocodeCebuPlace(Dio dio, String query) async {
  final local = lookupCebuPlaceLocal(query);
  if (local != null) return local;
  try {
    final response = await dio.getUri(
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'limit': '8',
        'addressdetails': '0',
        'countrycodes': 'ph',
        'q': '$query, Cebu, Philippines',
      }),
      options: Options(
        headers: const {
          'User-Agent':
              'StrollWise location search (contact: strollwise)',
        },
      ),
    );
    final results = response.data;
    if (results is! List || results.isEmpty) return null;
    for (final raw in results) {
      if (raw is! Map) continue;
      final lat = double.tryParse(raw['lat']?.toString() ?? '');
      final lng = double.tryParse(raw['lon']?.toString() ?? '');
      if (lat == null || lng == null) continue;
      final candidate = LatLng(lat, lng);
      if (cebuPlaceWithinServiceArea(candidate)) return candidate;
    }
    return null;
  } catch (_) {
    return null;
  }
}
