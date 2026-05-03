import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class StrollWiseApp extends StatelessWidget {
  const StrollWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StrollWise',
      theme: buildAppTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
