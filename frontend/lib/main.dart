/// StrollWise traveler app (Flutter).
///
/// Defence map: Riverpod for state, GoRouter for tabs, MapLibre for Explore.
/// On launch we load the bundled Cebu zone catalog JSON, restore the JWT from
/// secure storage, then paint the shell (Explore / Add Tag / Feed / Trends /
/// Profile). The app never draws other people's GPS points — only zone
/// polygons, H3 hexes, and the user's own pending pins.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';
import 'shared/providers/app_providers.dart';
import 'shared/traveler_gradient.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN');
const _sentryEnvironment = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue: 'development',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ZoneCatalog.ensureLoaded();

  if (_sentryDsn.isEmpty) {
    await _runApp();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = _sentryEnvironment;
      options.sendDefaultPii = false;
    },
    appRunner: _runApp,
  );
}

Future<void> _runApp() async {
  final container = ProviderContainer();
  await bootstrapAuthSession(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StrollWiseApp(),
    ),
  );
}
