import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_widgets.dart';

/// Signature of the function that sends the reset email.
///
/// The app uses Firebase. Tests pass in a fake so they never touch Firebase.
typedef PasswordResetSender = Future<void> Function(String email);

/// Lets a user ask Firebase to email them a password reset link.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.sendPasswordResetEmail,
  });

  /// Pre-fills the email field (the login screen passes what was typed there).
  final String initialEmail;

  /// Leave null in the real app. Tests inject a fake sender.
  final PasswordResetSender? sendPasswordResetEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isLoading = false;
  bool _emailSent = false;
  String _sentTo = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// The real Firebase call. Only used when no fake sender is injected.
  static Future<void> _sendWithFirebase(String email) {
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> _sendResetEmail() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sender = widget.sendPasswordResetEmail ?? _sendWithFirebase;
      await sender(email);
      if (!mounted) return;
      setState(() {
        _emailSent = true;
        _sentTo = email;
      });
    } on FirebaseAuthException catch (error) {
      debugPrint('Password reset failed: ${error.code}');
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
      case 'invalid-email':
        return 'That email address does not look right. '
            'Please check it and try again.';
      case 'user-not-found':
        return 'No account was found with that email address.';
      case 'network-request-failed':
        return 'Connection problem. Check your internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a little and try again.';
      case 'user-disabled':
        return 'This account has been disabled. '
            'Please contact the administrator.';
      case 'operation-not-allowed':
        return 'Password reset is not available right now. '
            'Please contact the administrator.';
      default:
        return 'Could not send the reset email. Please try again.';
    }
  }

  void _goBackToLogin() {
    Navigator.of(context).maybePop();
  }

  void _tryDifferentEmail() {
    setState(() {
      _emailSent = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.cream,
      appBar: AppBar(
        backgroundColor: AuthPalette.cream,
        foregroundColor: AuthPalette.maroon,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _emailSent ? _buildSuccess() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AuthBrandHeader(size: 84, showTagline: false)),
          const SizedBox(height: 28),
          Text('Forgot your password?', style: authHeadingStyle(fontSize: 30)),
          const SizedBox(height: 10),
          const Text(
            'Enter the email you use for MyYatra and we will send you a '
                'link to reset your password.',
            style: TextStyle(
              color: AuthPalette.mutedText,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          const AuthFieldLabel('Email address'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _sendResetEmail();
            },
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
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            AuthErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Send reset link',
            trailingIcon: Icons.arrow_forward,
            isLoading: _isLoading,
            onPressed: _sendResetEmail,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : _goBackToLogin,
            style: TextButton.styleFrom(foregroundColor: AuthPalette.maroon),
            child: const Text(
              'Back to sign in',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AuthPalette.logoBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: AuthPalette.maroon,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: authHeadingStyle(fontSize: 30),
        ),
        const SizedBox(height: 12),
        Text(
          'If an account exists for $_sentTo, a password reset link is on '
              'its way. It can take a few minutes, and it may land in your '
              'spam folder.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AuthPalette.mutedText,
            fontSize: 16,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Back to sign in',
          trailingIcon: Icons.arrow_forward,
          onPressed: _goBackToLogin,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _tryDifferentEmail,
          style: TextButton.styleFrom(foregroundColor: AuthPalette.maroon),
          child: const Text(
            'Use a different email',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
