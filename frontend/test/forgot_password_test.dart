import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:strollwise/features/auth/presentation/auth_screen.dart';
import 'package:strollwise/features/auth/presentation/forgot_password_screen.dart';
import 'package:strollwise/shared/network/api_client.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _onFetch(options);
  }
}

ResponseBody _json(int status, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  testWidgets('login screen opens forgot password', (tester) async {
    final router = GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
        GoRoute(
          path: '/auth/forgot',
          builder: (_, _) => const ForgotPasswordScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forgot password?'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Send reset code'), findsOneWidget);
  });

  testWidgets('forgot password recovers with emailed code', (tester) async {
    final posts = <String, Map<String, dynamic>>{};
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    dio.httpClientAdapter = _ScriptedAdapter((options) async {
      final raw = options.data;
      if (raw is Map) {
        posts[options.path] = Map<String, dynamic>.from(raw);
      }
      if (options.path.contains('forgot-password')) {
        return _json(200, {
          'message':
              'If that email is registered, we sent a 6-digit reset code. It expires in 15 minutes.',
          'delivery': 'email',
        });
      }
      if (options.path.contains('reset-password')) {
        return _json(200, {'message': 'Password updated. You can sign in now.'});
      }
      return _json(404, {'detail': 'missing'});
    });

    final router = GoRouter(
      initialLocation: '/auth/forgot',
      routes: [
        GoRoute(
          path: '/auth',
          builder: (_, _) => const Scaffold(body: Text('Sign in ready')),
        ),
        GoRoute(
          path: '/auth/forgot',
          builder: (_, _) => const ForgotPasswordScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWith((ref) => dio)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'recover@example.com');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('we sent a 6-digit reset code'),
      findsOneWidget,
    );
    expect(find.textContaining('Mail is not configured'), findsNothing);
    expect(find.text('Update password'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), 'newpass999');
    await tester.enterText(fields.at(3), 'newpass999');
    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in ready'), findsOneWidget);
    expect(posts['/auth/forgot-password']?['email'], 'recover@example.com');
    expect(posts['/auth/reset-password']?['code'], '123456');
    expect(posts['/auth/reset-password']?['new_password'], 'newpass999');
  });
}
