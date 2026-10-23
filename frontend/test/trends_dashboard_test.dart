import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strollwise/features/trends/presentation/trends_widgets.dart';
import 'package:strollwise/features/trends/trends_copy.dart';
import 'package:strollwise/shared/models/zone_category_trends.dart';

void main() {
  testWidgets('compact header has tags and peak, not confidence or activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrendsIdentityHeader(
            title: 'Escario',
            subtitle: 'Commercial · Mixed-use area',
            windowLabel: 'Last 30 days',
            tagCount: 14,
            peakLabel: '6–11 AM',
          ),
        ),
      ),
    );

    expect(find.text('Trends'), findsOneWidget);
    expect(find.text('Escario'), findsOneWidget);
    expect(find.text('Commercial · Mixed-use area'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Reported zone tags'), findsOneWidget);
    expect(find.text('6–11 AM'), findsOneWidget);
    expect(find.text('Selected Zone Signal'), findsNothing);
    expect(find.textContaining('confidence'), findsNothing);
    expect(find.textContaining('activity'), findsNothing);
  });

  testWidgets('vibe preview shows four cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VibeCardGrid(
            vibes: kTrendVibes.take(4).toList(),
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Food crawl'), findsOneWidget);
    expect(find.text('Cafes & study'), findsOneWidget);
    expect(find.text('Hidden spots'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Digital nomad'), findsNothing);
  });

  testWidgets('growing category row explains the comparison window', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryTrendRow(
            windowDays: 30,
            row: CategoryTrendModel(
              category: 'food',
              label: 'Food',
              currentCount: 9,
              previousCount: 4,
              delta: 5,
              growing: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Food · 9'), findsOneWidget);
    expect(find.textContaining('previous 30 days'), findsOneWidget);
  });
}
