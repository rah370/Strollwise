import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:strollwise/features/reports/presentation/tag_submission_screen.dart';
import 'package:strollwise/shared/notifications/app_notifications.dart';

void main() {
  testWidgets('in-page confirmation shows Tag submitted', (tester) async {
    var openedMap = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TagSubmittedConfirmationView(
          summary: 'Food · IT Park',
          onSeeOnMap: () => openedMap = true,
        ),
      ),
    );

    expect(find.text('Tag submitted'), findsOneWidget);
    expect(find.text('Food · IT Park'), findsOneWidget);
    expect(find.text('See on map'), findsOneWidget);
    expect(find.text('Your Food tag was saved.'), findsNothing);

    await tester.tap(find.text('See on map'));
    await tester.pump();
    expect(openedMap, isTrue);
  });

  testWidgets('persistent banner shows Tag submitted at the top', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const Scaffold(body: Text('home')),
      ),
    );

    AppNotificationToast.showPersistentBanner(
      AppNotification(
        id: 'test',
        title: 'Tag submitted',
        message: 'Food · IT Park',
        createdAt: DateTime.now(),
        kind: AppNotificationKind.success,
      ),
    );
    await tester.pump();

    expect(find.text('Tag submitted'), findsOneWidget);
    expect(find.text('Food · IT Park'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
  });
}
