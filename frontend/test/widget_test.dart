import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:strollwise/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('app boots to sign-in when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StrollWiseApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('StrollWise'), findsWidgets);
  });
}
