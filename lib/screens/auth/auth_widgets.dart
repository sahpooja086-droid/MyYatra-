import 'package:flutter/material.dart';

/// Colours shared by the sign-in and password-recovery screens.
///
/// The first three (maroon, cream, purple) are the same colours the app
/// already uses. The rest are soft supporting shades for text, borders and
/// error messages.
class AuthPalette {
  static const Color maroon = Color(0xFF8E2442);
  static const Color cream = Color(0xFFFFF9E9);
  static const Color purple = Color(0xFFA482B7);

  static const Color ink = Color(0xFF2B2024);
  static const Color mutedText = Color(0xFF6F6468);
  static const Color fieldBorder = Color(0xFFE6D9D2);
  static const Color logoBackground = Color(0xFFFFEFCF);

  static const Color errorText = Color(0xFFB3261E);
  static const Color errorFill = Color(0xFFFDECEA);
  static const Color errorBorder = Color(0xFFF4C7C3);

  static const Color disabledButton = Color(0xFFB36A80);
}

/// Returns true when [value] looks like `name@domain.tld`.
///
/// This only checks the shape of the text. Firebase decides whether the
/// address really belongs to an account.
bool isValidEmail(String value) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
}

/// Big serif heading style used at the top of the auth screens.
TextStyle authHeadingStyle({double fontSize = 34}) {
  return TextStyle(
    fontFamily: 'serif',
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: AuthPalette.ink,
    height: 1.15,
  );
}

/// The rounded text-field look from the MyYatra design.
InputDecoration authInputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AuthPalette.mutedText),
    prefixIcon: Icon(icon, color: AuthPalette.purple),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    border: border(AuthPalette.fieldBorder),
    enabledBorder: border(AuthPalette.fieldBorder),
    focusedBorder: border(AuthPalette.maroon, 1.6),
    errorBorder: border(AuthPalette.errorText),
    focusedErrorBorder: border(AuthPalette.errorText, 1.6),
  );
}

/// Small bold label shown above a text field.
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AuthPalette.ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// MyYatra logo badge, with the optional tagline underneath.
///
/// It tries to load `assets/images/logo.png`. If that file has not been added
/// to the project yet, it shows the existing Explore icon instead, so the
/// screen works either way.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, this.size = 96, this.showTagline = true});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'MyYatra logo',
          image: true,
          child: Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AuthPalette.logoBackground,
              borderRadius: BorderRadius.circular(size * 0.27),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.explore,
                color: AuthPalette.maroon,
                size: size * 0.5,
              ),
            ),
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 14),
          const Text(
            'YOUR NEXT CHAPTER STARTS HERE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AuthPalette.maroon,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Soft red box used to show an error message above a button.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AuthPalette.errorFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AuthPalette.errorBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              color: AuthPalette.errorText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AuthPalette.errorText,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft purple box used for friendly, non-error notices.
class AuthInfoBanner extends StatelessWidget {
  const AuthInfoBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4EDF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCCBE6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AuthPalette.purple, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AuthPalette.ink,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width maroon button with an optional arrow and a loading spinner.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthPalette.maroon,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AuthPalette.disabledButton,
          disabledForegroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0x668E2442),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 10),
                    Icon(trailingIcon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}
