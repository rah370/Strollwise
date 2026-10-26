import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/brand.dart';
import '../../../app/theme/colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/network/api_client.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _codeStep = false;
  String? _hint;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return ApiConstants.unreachableMessage();
      }
      final detail = error.response?.data;
      if (detail is Map && detail['detail'] != null) {
        return detail['detail'].toString();
      }
    }
    return 'Could not reset the password. Try again.';
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast('Enter the email for your account.');
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/forgot-password',
        data: {'email': email.toLowerCase()},
      );
      final data = response.data;
      String? code;
      if (data is Map) {
        final raw = data['reset_code'];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          code = raw.toString().trim();
        }
      }
      if (!mounted) return;
      setState(() {
        _codeStep = true;
        if (code != null) {
          _codeController.text = code;
          _hint =
              'Mail is not configured on this server, so your reset code is shown here. It expires in 15 minutes.';
        } else {
          _hint =
              'If that email is registered, we sent a 6-digit code. It expires in 15 minutes.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      _toast(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitNewPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();
    if (code.length < 6) {
      _toast('Enter the 6-digit reset code.');
      return;
    }
    if (password.length < 8) {
      _toast('New password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      _toast('The new passwords do not match.');
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/auth/reset-password',
        data: {
          'email': email.toLowerCase(),
          'code': code,
          'new_password': password,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. Sign in with your new password.'),
        ),
      );
      context.go('/auth');
    } catch (error) {
      if (!mounted) return;
      _toast(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEAF4FA),
                  Color(0xFFF8FAFC),
                  Color(0xFFFFFEF5),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Back to sign in',
                        onPressed: _busy ? null : () => context.go('/auth'),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(height: 8),
                      const StrollWiseBrandMark(size: 36),
                      const SizedBox(height: 18),
                      const Text(
                        'Forgot password',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _codeStep
                            ? 'Enter the 6-digit code and choose a new password.'
                            : 'We will send a 6-digit code to your account email so you can set a new password.',
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _emailController,
                        enabled: !_codeStep,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      if (_codeStep) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: '6-digit code',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: 'New password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _confirmController,
                          obscureText: _obscure,
                          onSubmitted: (_) => _submitNewPassword(),
                          decoration: const InputDecoration(
                            hintText: 'Confirm new password',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                      ],
                      if (_hint != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Text(
                            _hint!,
                            style: const TextStyle(
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : (_codeStep ? _submitNewPassword : _requestCode),
                          child: Text(
                            _busy
                                ? 'Please wait...'
                                : (_codeStep
                                    ? 'Update password'
                                    : 'Send reset code'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_codeStep)
                        Center(
                          child: TextButton(
                            onPressed: _busy ? null : _requestCode,
                            child: const Text('Send a new code'),
                          ),
                        ),
                      Center(
                        child: TextButton(
                          onPressed: _busy ? null : () => context.go('/auth'),
                          child: const Text('Back to sign in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
