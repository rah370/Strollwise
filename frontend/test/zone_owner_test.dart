import 'package:flutter_test/flutter_test.dart';
import 'package:strollwise/shared/traveler_gradient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ZoneCatalog.ensureLoaded();
  });

  test('IT Park center keeps the IT Park name, not Ayala', () {
    final owner = ZoneCatalog.ownerOf(10.3295, 123.9067);
    expect(owner, isNotNull);
    expect(owner!.zoneId, 'Z007');
    expect(owner.zoneName, 'IT Park Business Zone');
  });

  test('Ayala mall center keeps the Ayala name', () {
    final owner = ZoneCatalog.ownerOf(10.3174, 123.9058);
    expect(owner, isNotNull);
    expect(owner!.zoneId, 'Z009');
    expect(owner.zoneName, 'Ayala Center Cebu');
  });

  test('Fuente center keeps Fuente, not the wider Ayala disk', () {
    final owner = ZoneCatalog.ownerOf(10.3100, 123.8916);
    expect(owner, isNotNull);
    expect(owner!.zoneId, 'Z010');
    expect(owner.zoneName, 'Fuente Osmeña');
  });
}
