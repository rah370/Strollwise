import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:strollwise/features/explore/presentation/explore_screen.dart';
import 'package:strollwise/shared/models/zone.dart';
import 'package:strollwise/shared/zone_place_ui.dart';

ZoneModel _zone({
  String placeName = 'IT Park',
  String displayName = 'IT Park',
  int reports = 24,
  List<Map<String, dynamic>> places = const [],
}) {
  return ZoneModel.fromJson({
    'zone_id': 'z1',
    'display_name': displayName,
    'behavior_type': 'mixed_area',
    'traveler_mix': 'mixed',
    'place_name': placeName,
    'report_count': reports,
    'places': places,
    'live_status': 'quiet_now',
    'crowd_level': 0.4,
    'local_presence_percent': 55,
    'confidence_score': 70,
    'priority_score': 50,
    'centroid': {'lat': 10.33, 'lng': 123.91},
  });
}

void main() {
  test('hexagon tap label names the place and signal count', () {
    expect(zoneSignalCountLabel(0), 'No signals yet');
    expect(zoneSignalCountLabel(1), '1 signal');
    expect(zoneSignalCountLabel(24), '24 signals');
    expect(
      zoneHexagonTapLabel(_zone()),
      'IT Park · 24 signals',
    );
  });

  test('hexagon tap label lists extra mapped places', () {
    final zone = _zone(
      places: [
        {
          'place_id': 'p1',
          'display_name': 'IT Park',
          'place_type': 'commercial',
        },
        {
          'place_id': 'p2',
          'display_name': 'Ayala Center Cebu',
          'place_type': 'commercial',
        },
        {
          'place_id': 'p3',
          'display_name': 'Colon',
          'place_type': 'food',
        },
      ],
    );
    expect(zoneHexagonPlaceLine(zone), 'IT Park + 2 places');
    expect(zoneHexagonTapLabel(zone), contains('signals'));
  });

  testWidgets('hexagon tap chip shows place and signals on the map', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HexagonTapLabel(
            placeLine: 'IT Park',
            signalLine: '24 signals',
            accent: Color(0xFF39C97A),
          ),
        ),
      ),
    );
    expect(find.text('IT Park'), findsOneWidget);
    expect(find.text('24 signals'), findsOneWidget);
  });
}
