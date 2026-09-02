import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Future<void>? _googleSignInInitialization;

Future<void> _ensureGoogleSignInInitialized(String clientId) {
  return _googleSignInInitialization ??=
      GoogleSignIn.instance.initialize(clientId: clientId);
}

class BarLyticsGoogleSignInButton extends StatefulWidget {
  const BarLyticsGoogleSignInButton({
    super.key,
    required this.webClientId,
    required this.iosClientId,
    required this.onIdToken,
    this.onError,
    this.enabled = true,
    this.loading = false,
  });

  final String? webClientId;
  final String? iosClientId;
  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error)? onError;
  final bool enabled;
  final bool loading;

  @override
  State<BarLyticsGoogleSignInButton> createState() =>
      _BarLyticsGoogleSignInButtonState();
}

class _BarLyticsGoogleSignInButtonState
    extends State<BarLyticsGoogleSignInButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  Object? _initializationError;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final clientId = widget.webClientId?.trim();
      if (clientId == null || clientId.isEmpty) {
        throw StateError('Falta configurar BARLYTICS_GOOGLE_WEB_CLIENT_ID.');
      }
      await _ensureGoogleSignInInitialized(clientId);
      _subscription = GoogleSignIn.instance.authenticationEvents.listen(
        (event) async {
          if (event is! GoogleSignInAuthenticationEventSignIn) return;
          final token = event.user.authentication.idToken;
          if (token == null || token.trim().isEmpty) {
            widget.onError?.call(
              StateError('Google no devolvió un token de identidad válido.'),
            );
            return;
          }
          await widget.onIdToken(token);
        },
        onError: (Object error) => widget.onError?.call(error),
      );
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      _initializationError = error;
      widget.onError?.call(error);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return const SizedBox.shrink();
    }

    if (!_ready) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 400.0;
        final buttonWidth = availableWidth.clamp(220.0, 400.0).toDouble();

        return IgnorePointer(
          ignoring: !widget.enabled || widget.loading,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: widget.enabled && !widget.loading ? 1 : .58,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Center(
                child: web.renderButton(
                  configuration: web.GSIButtonConfiguration(
                    type: web.GSIButtonType.standard,
                    theme: web.GSIButtonTheme.outline,
                    size: web.GSIButtonSize.large,
                    text: web.GSIButtonText.continueWith,
                    shape: web.GSIButtonShape.pill,
                    logoAlignment: web.GSIButtonLogoAlignment.left,
                    minimumWidth: buttonWidth,
                    locale: 'es',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
