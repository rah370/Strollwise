class ApiConstants {
  /// Base URL of the StrollWise backend (local uvicorn on port 8000 by default).
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// All HTTP calls are prefixed with this path (matches `api_v1_prefix`
  /// in the backend settings).
  static const apiPrefix = '/api/v1';

  /// Render free-tier cold starts commonly take 30–60s. A short connect
  /// timeout surfaces as "cannot reach API" even when the host is healthy.
  static const connectTimeout = Duration(seconds: 60);
  static const receiveTimeout = Duration(seconds: 60);

  static bool isLocalBaseUrl([String? url]) {
    final host = (url ?? baseUrl).toLowerCase();
    return host.contains('127.0.0.1') || host.contains('localhost');
  }

  static String unreachableMessage([String? url]) {
    final resolved = url ?? baseUrl;
    if (isLocalBaseUrl(resolved)) {
      return 'Cannot reach the server. Start the backend and run the app with '
          '--dart-define=API_URL=http://127.0.0.1:8000';
    }
    return 'Cannot reach the StrollWise API at $resolved. The hosted server '
        'may be waking up — wait about a minute and try again.';
  }
}
