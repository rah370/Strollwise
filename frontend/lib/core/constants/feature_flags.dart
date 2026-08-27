class FeatureFlags {
  /// Offline demo login. On in debug/profile; off in release unless
  /// `--dart-define=ENABLE_DEMO_LOGIN=true`.
  static const enableDemoLogin = bool.fromEnvironment(
    'ENABLE_DEMO_LOGIN',
    defaultValue: !bool.fromEnvironment('dart.vm.product'),
  );
}
