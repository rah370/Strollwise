import 'package:flutter_test/flutter_test.dart';
import 'package:strollwise/core/constants/api_constants.dart';

void main() {
  test('local API copy tells the developer to start the backend', () {
    expect(ApiConstants.isLocalBaseUrl('http://127.0.0.1:8000'), isTrue);
    expect(
      ApiConstants.unreachableMessage('http://127.0.0.1:8000'),
      contains('--dart-define=API_URL=http://127.0.0.1:8000'),
    );
  });

  test('hosted API copy names the URL and the wake delay', () {
    expect(
      ApiConstants.isLocalBaseUrl('https://strollwise-api.onrender.com'),
      isFalse,
    );
    expect(
      ApiConstants.unreachableMessage('https://strollwise-api.onrender.com'),
      contains('https://strollwise-api.onrender.com'),
    );
    expect(
      ApiConstants.unreachableMessage('https://strollwise-api.onrender.com'),
      contains('waking up'),
    );
  });

  test('client timeouts cover a Render free-tier cold start', () {
    expect(ApiConstants.connectTimeout, const Duration(seconds: 60));
    expect(ApiConstants.receiveTimeout, const Duration(seconds: 60));
  });
}
