import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strollwise/features/profile/presentation/profile_widgets.dart';
import 'package:strollwise/features/profile/profile_copy.dart';
import 'package:strollwise/shared/models/user_contributions.dart';

void main() {
  testWidgets('compact identity has edit profile and no logout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileIdentityHeader(
            displayName: 'Rahma Sheikh',
            locationLine: 'Cebu City, Philippines',
            contributorLabel: 'Active contributor',
            showVerified: true,
            onEdit: () {},
          ),
        ),
      ),
    );

    expect(find.text('Rahma Sheikh'), findsOneWidget);
    expect(find.text('Cebu City, Philippines'), findsOneWidget);
    expect(find.text('Active contributor'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(find.text('Edit name'), findsNothing);
  });

  testWidgets('stats card explains unaccounted rejected tags', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileStatsCard(
            stats: UserContributionStatsModel(
              submitted: 9,
              approved: 4,
              pending: 1,
              rejected: 3,
              flagged: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('9'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(
      find.text(
        '4 tags are rejected, flagged, or hidden. They still count as submitted.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tag row keeps status off the title line', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileTagRow(
            title: 'Neighborhood Favorite With A Long Name',
            subtitle: 'Food · Cebu City',
            status: TagStatusKind.approved,
            category: 'food',
          ),
        ),
      ),
    );

    expect(find.text('Neighborhood Favorite With A Long Name'), findsOneWidget);
    expect(find.text('Food · Cebu City'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Pending validation'), findsNothing);

    final titleBox = tester.getRect(
      find.text('Neighborhood Favorite With A Long Name'),
    );
    final chipBox = tester.getRect(find.text('Approved'));
    expect(chipBox.top, greaterThan(titleBox.bottom - 1));
  });

  testWidgets('filter chips include rejected counts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagFilterBar(
            selected: TagFilter.all,
            stats: UserContributionStatsModel(
              submitted: 9,
              approved: 4,
              pending: 1,
              rejected: 4,
            ),
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('All (9)'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Approved (4)'), findsOneWidget);
    expect(find.text('Rejected (4)'), findsOneWidget);
  });

  testWidgets('map link uses dark blue contrast color', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileTagRow(
            title: 'IT Park',
            subtitle: 'Food · Cebu City',
            status: TagStatusKind.pending,
            category: 'food',
            showMapLink: true,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('View on map'));
    expect(text.style?.color, const Color(0xFF1D4ED8));
    expect(find.text('Pending'), findsOneWidget);
  });
}
