import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strollwise/features/feed/presentation/feed_cards.dart';
import 'package:strollwise/features/feed/presentation/feed_stream.dart';
import 'package:strollwise/shared/models/report.dart';
import 'package:strollwise/shared/models/zone.dart';

ZoneModel _zone({
  required String id,
  required String name,
  required double lat,
  required double lng,
  double localRatio = 0.22,
  int reports = 46,
  String live = 'quiet_now',
}) {
  return ZoneModel(
    zoneId: id,
    displayName: name,
    behaviorType: 'mixed_area',
    travelerMix: 'mixed',
    summary: 'Live area',
    liveStatus: live,
    polygonGeoJson: const {'type': 'Polygon', 'coordinates': <dynamic>[]},
    boundary: const [],
    polygonParts: const [],
    centroidLat: lat,
    centroidLng: lng,
    crowdLevel: 0.2,
    localPresencePercent: localRatio * 100,
    localRatio: localRatio,
    peakTimeLabel: null,
    confidenceScore: 80,
    priorityScore: 80,
    reportCount: reports,
    placeName: name,
  );
}

ReportModel _report({
  required String id,
  required String h3,
  required String note,
  required DateTime at,
  double lat = 10.3315,
  double lng = 123.9062,
  String category = 'food',
  String handle = '@local',
}) {
  return ReportModel(
    id: id,
    h3Index: h3,
    category: category,
    tags: const ['public'],
    note: note,
    createdAt: at,
    cellLat: lat,
    cellLng: lng,
    authorKind: 'local',
    authorHandle: handle,
  );
}

void main() {
  final now = DateTime(2026, 11, 16, 3);
  final itPark = _zone(
    id: 'it',
    name: 'IT Park Business Zone',
    lat: 10.3315,
    lng: 123.9062,
  );
  final ayala = _zone(
    id: 'ayala',
    name: 'Ayala Center Cebu',
    lat: 10.3182,
    lng: 123.9058,
    localRatio: 0.55,
    live: 'busy_now',
  );

  test('mixes a pulse after the first micro-post', () {
    final entries = buildMixedFeed(
      reports: [
        _report(
          id: 'a',
          h3: 'h1',
          note: 'Quiet vibe near the central lawn right now',
          at: now.subtract(const Duration(minutes: 4)),
        ),
        _report(
          id: 'b',
          h3: 'h1',
          note: 'Any power outlets open?',
          at: now.subtract(const Duration(minutes: 2)),
        ),
        _report(
          id: 'c',
          h3: 'h2',
          note: 'Parking filling up',
          at: now.subtract(const Duration(minutes: 18)),
          lat: 10.3182,
          lng: 123.9058,
        ),
      ],
      zones: [itPark, ayala],
    );

    expect(entries.first, isA<FeedMicroPost>());
    final first = entries.first as FeedMicroPost;
    expect(first.report.note, contains('Quiet vibe'));
    expect(first.replies, isNotEmpty);
    expect(first.replies.first.text, contains('power outlets'));
    expect(entries[1], isA<FeedPulse>());
    expect((entries[1] as FeedPulse).zone.placeName, 'IT Park Business Zone');
    expect(entries.whereType<FeedPulse>(), isNotEmpty);
  });

  test('food chip hides safety notes', () {
    final entries = buildMixedFeed(
      reports: [
        _report(
          id: 'food',
          h3: 'h1',
          note: 'Great coffee',
          at: now,
          category: 'food',
        ),
        _report(
          id: 'safe',
          h3: 'h3',
          note: 'Dark stretch of sidewalk',
          at: now,
          category: 'safety',
        ),
      ],
      zones: [itPark],
      chip: 'Food',
    );
    final posts = entries.whereType<FeedMicroPost>().toList();
    expect(posts, hasLength(1));
    expect(posts.first.report.note, 'Great coffee');
  });

  testWidgets('micro-post shows zone pill, mix badge, and actions', (
    tester,
  ) async {
    final post = FeedMicroPost(
      report: _report(
        id: 'a',
        h3: 'h1',
        note: 'Quiet vibe near the central lawn right now',
        at: now,
        handle: '@marco_cebu',
      ),
      zone: itPark,
      replies: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedMicroPostCard(
            post: post,
            liked: false,
            onOpenMap: () {},
            onAddTag: () {},
            onToggleLike: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('@marco_cebu'), findsOneWidget);
    expect(find.textContaining('IT Park Business Zone'), findsOneWidget);
    expect(find.textContaining('Quiet vibe'), findsOneWidget);
    expect(find.textContaining('Locals'), findsOneWidget);
    expect(find.textContaining('Visitors'), findsOneWidget);
  });

  testWidgets('pulse card shows mix bar, view on map, and replies', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedPulseCard(
            pulse: FeedPulse(
              zone: ayala,
              replies: [
                FeedReply(
                  authorHandle: '@visitor',
                  text: 'Is parking full at Ayala right now?',
                  createdAt: now,
                ),
              ],
            ),
            onOpenMap: () {},
            onAddTag: () {},
          ),
        ),
      ),
    );
    expect(find.text('Live Zone Pulse'), findsOneWidget);
    expect(find.text('Ayala Center Cebu'), findsOneWidget);
    expect(find.text('View on map'), findsOneWidget);
    expect(find.text('Community replies'), findsOneWidget);
    expect(find.textContaining('parking full'), findsOneWidget);
    expect(find.textContaining('Locals'), findsOneWidget);
  });

  testWidgets('composer offers Calm Busy Great Coffee', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedComposerBar(onAddTag: tapped.add),
        ),
      ),
    );
    expect(find.text('Drop a 5-second tag'), findsOneWidget);
    await tester.tap(find.text('Calm'));
    await tester.pump();
    expect(tapped, ['Calm']);
  });
}
