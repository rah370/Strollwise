import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strollwise/app/theme/brand.dart';

void main() {
  testWidgets('brand mark shows the StrollWise wordmark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StrollWiseBrandMark()),
      ),
    );
    expect(find.text('StrollWise'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
