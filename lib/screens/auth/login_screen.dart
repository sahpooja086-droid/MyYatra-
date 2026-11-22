import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_widgets.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.notice});

  /// Optional message shown above the form, for example
  /// "You were signed out because you were inactive."
  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      // Shows the exact Firebase error code in the Run/Debug console.
      // Handy while you are setting things up.
      debugPrint('Sign-in failed: ${error.code}');
      if (!mounted) return;
      setState(() => _errorMessage = _messageForError(error.code));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _messageForError(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'Connection problem. Check your internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a little and try again.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-email':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled. '
            'Please contact the administrator.';
      case 'operation-not-allowed':
        return 'Email and password sign-in is not available right now.';
      default:
        return 'Could not sign in. Please try again.';
    }
  }

  void _openForgotPassword() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ForgotPasswordScreen(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AuthBrandHeader()),
                    const SizedBox(height: 28),
                    Text('Welcome back.', style: authHeadingStyle()),
                    const SizedBox(height: 10),
                    const Text(
                      'Sign in to continue your Nepal story.',
                      style: TextStyle(
                        color: AuthPalette.mutedText,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.notice != null) ...[
                      const SizedBox(height: 20),
                      AuthInfoBanner(message: widget.notice!),
                    ],
                    const SizedBox(height: 28),
                    const AuthFieldLabel('Email address'),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: authInputDecoration(
                        hint: 'you@example.com',
                        icon: Icons.mail_outline,
                      ),
                      validator: (value) {
                        if (!isValidEmail(value ?? '')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const AuthFieldLabel('Password'),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _signIn();
                      },
                      decoration: authInputDecoration(
                        hint: 'Enter your password',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(() {
                            _obscurePassword = !_obscurePassword;
                          }),
                          // Eye = "tap to show". Crossed-out eye = "tap to hide".
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AuthPalette.mutedText,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your password'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _openForgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: AuthPalette.maroon,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 4),
                      AuthErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 16),
                    AuthPrimaryButton(
                      label: 'Sign in',
                      trailingIcon: Icons.arrow_forward,
                      isLoading: _isLoading,
                      onPressed: _signIn,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Use an existing account. New account registration '
                          'is not available here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AuthPalette.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}