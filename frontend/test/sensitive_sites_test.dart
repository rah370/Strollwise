import 'package:flutter_test/flutter_test.dart';
import 'package:strollwise/shared/models/sensitive_site.dart';

void main() {
  test('hospital centroid is on the building and 60m north is not', () {
    const hospital = SensitiveSite(
      kind: 'hospital',
      lat: 10.2970,
      lng: 123.8915,
      radiusM: 40,
    );
    expect(hospital.contains(10.2970, 123.8915), isTrue);
    expect(hospital.contains(10.29755, 123.8915), isFalse);
  });

  test('police nearby is not a facility name', () {
    expect(tagsNameFacility(['police nearby'], null), isFalse);
    expect(tagsNameFacility(['police station'], null), isTrue);
  });

  test('pin-on-building copy matches the API wording', () {
    expect(
      pinOnBuildingCopy('hospital'),
      contains('not the hospital itself'),
    );
  });
}
