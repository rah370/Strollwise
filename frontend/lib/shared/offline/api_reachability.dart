/// Short probe of the API health route. Used to tell the traveler they are
/// offline before a tag is stored only on the phone.
library;

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';

class ApiReachability {
  static Future<bool> probe() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ),
    );
    try {
      final response = await dio.get('${ApiConstants.baseUrl}/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      dio.close();
    }
  }
}
