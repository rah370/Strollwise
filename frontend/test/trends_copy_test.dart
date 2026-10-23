import 'package:flutter_test/flutter_test.dart';
import 'package:strollwise/features/trends/trends_copy.dart';
import 'package:strollwise/shared/models/place_recommendation.dart';
import 'package:strollwise/shared/models/zone_category_trends.dart';

void main() {
  test('small samples are not treated as trends', () {
    expect(
      notEnoughTrendCopy(8),
      contains('Not enough recent activity to identify a trend'),
    );
    expect(notEnoughTrendCopy(8), contains('8 approved tags'));
  });

  test('growth copy distinguishes rising counts from high volume', () {
    final growing = CategoryTrendModel(
      category: 'food',
      label: 'Food',
      currentCount: 9,
      previousCount: 4,
      delta: 5,
      growing: true,
    );
    expect(categoryTrendDetail(growing, 30), contains('more approved tags'));
    expect(categoryTrendDetail(growing, 30), contains('4 → 9'));

    final steady = CategoryTrendModel(
      category: 'transport',
      label: 'Transport',
      currentCount: 8,
      previousCount: 8,
      delta: 0,
      growing: false,
    );
    expect(categoryTrendDetail(steady, 30), contains('Busy, not growing'));
  });

  test('walking routes need named mapped stops', () {
    expect(
      buildWalkingRoute(
        areaName: 'Escario',
        originLat: 10.316,
        originLng: 123.896,
        places: const [],
      ),
      isNull,
    );

    final route = buildWalkingRoute(
      areaName: 'Escario',
      originLat: 10.316,
      originLng: 123.896,
      places: const [
        PlaceRecommendation(
          placeId: 'zubuchon',
          name: 'Zubuchon Escario',
          address: 'Escario St, Cebu City',
          latitude: 10.3158,
          longitude: 123.8962,
        ),
        PlaceRecommendation(
          placeId: 'bos',
          name: "Bo's Coffee Escario",
          address: 'Escario St, Capitol Site',
          latitude: 10.3160,
          longitude: 123.8958,
        ),
        PlaceRecommendation(
          placeId: 'capitol',
          name: 'Cebu Provincial Capitol',
          address: 'Capitol Site, Cebu City',
          latitude: 10.3172,
          longitude: 123.8958,
        ),
      ],
    );
    expect(route, isNotNull);
    expect(route!.stops.length, greaterThanOrEqualTo(2));
    expect(route.stops.any((s) => s.name.contains('area center')), isFalse);
    expect(route.walkMinutes, greaterThan(0));
    expect(route.metaLabel, contains('min walk'));
  });

  test('relevant vibes stay within four to six by default', () {
    expect(kTrendVibes.take(kDefaultVibesPreview).length, 4);
    expect(relevantVibes(null, limit: kVibesTabPreview).length, 6);
  });
}
