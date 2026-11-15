class FeatureFlags {
  /// Offline demo login for local UI work without the API.
  ///
  /// On in debug/profile; off in release unless
  /// `--dart-define=ENABLE_DEMO_LOGIN=true`. Keep both branches — this is
  /// compile-time, not a runtime remote flag.
  static const enableDemoLogin = bool.fromEnvironment(
    'ENABLE_DEMO_LOGIN',
    defaultValue: !bool.fromEnvironment('dart.vm.product'),
  );
}
