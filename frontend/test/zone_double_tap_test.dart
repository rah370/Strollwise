import 'package:flutter_test/flutter_test.dart';

import 'package:strollwise/features/explore/presentation/explore_screen.dart';

void main() {
  final now = DateTime(2026, 10, 10, 3, 10);

  test('second tap on the same zone within 650ms is a double tap', () {
    expect(
      isSameZoneDoubleTap(
        previousZoneId: 'lahug',
        zoneId: 'lahug',
        previousTapAt: now.subtract(const Duration(milliseconds: 400)),
        now: now,
      ),
      isTrue,
    );
  });

  test('a slow second tap is not a double tap', () {
    expect(
      isSameZoneDoubleTap(
        previousZoneId: 'lahug',
        zoneId: 'lahug',
        previousTapAt: now.subtract(const Duration(milliseconds: 900)),
        now: now,
      ),
      isFalse,
    );
  });

  test('tapping a different zone is not a double tap', () {
    expect(
      isSameZoneDoubleTap(
        previousZoneId: 'lahug',
        zoneId: 'ayala',
        previousTapAt: now.subtract(const Duration(milliseconds: 200)),
        now: now,
      ),
      isFalse,
    );
  });
}
