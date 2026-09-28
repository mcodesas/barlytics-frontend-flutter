import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInResult {
  const AppleSignInResult({
    required this.idToken,
    this.email,
    this.givenName,
    this.familyName,
  });

  final String idToken;
  final String? email;
  final String? givenName;
  final String? familyName;
}

class BarLyticsAppleSignInButton extends StatelessWidget {
  const BarLyticsAppleSignInButton({
    super.key,
    required this.onCredential,
    required this.onError,
    this.loading = false,
  });

  final Future<void> Function(AppleSignInResult result) onCredential;
  final ValueChanged<Object> onError;
  final bool loading;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!supported) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: SignInWithAppleButton(
        text: 'Continuar con Apple',
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        onPressed: () async {
                if (loading) return;
                try {
                  final credential = await SignInWithApple.getAppleIDCredential(
                    scopes: const [
                      AppleIDAuthorizationScopes.email,
                      AppleIDAuthorizationScopes.fullName,
                    ],
                  );
                  final token = credential.identityToken;
                  if (token == null || token.trim().isEmpty) {
                    throw StateError('Apple no devolvió un token de identidad válido.');
                  }
                  await onCredential(
                    AppleSignInResult(
                      idToken: token,
                      email: credential.email,
                      givenName: credential.givenName,
                      familyName: credential.familyName,
                    ),
                  );
                } catch (error) {
                  onError(error);
                }
              },
      ),
    );
  }
}
