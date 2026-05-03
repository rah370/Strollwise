class ApiConstants {
  /// Base URL of the StrollWise backend. Defaults to the local Docker stack.
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// All HTTP calls are prefixed with this path (matches `api_v1_prefix`
  /// in the backend settings).
  static const apiPrefix = '/api/v1';
}
