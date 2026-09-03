import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:openid_client/openid_client_io.dart' as oidc;
import 'package:url_launcher/url_launcher.dart';


Future<void>? _googleSignInInitialization;

Future<void> _ensureGoogleSignInInitialized({String? webClientId, String? iosClientId}) {
  final normalizedWeb = webClientId?.trim();
  final normalizedIos = iosClientId?.trim();
  final applePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  return _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
    clientId: applePlatform && normalizedIos != null && normalizedIos.isNotEmpty ? normalizedIos : null,
    serverClientId: normalizedWeb != null && normalizedWeb.isNotEmpty ? normalizedWeb : null,
  );
}

class BarLyticsGoogleSignInButton extends StatefulWidget {
  const BarLyticsGoogleSignInButton({
    super.key,
    required this.webClientId,
    required this.iosClientId,
    required this.desktopClientId,
    required this.desktopClientSecret,
    required this.onIdToken,
    this.onError,
    this.enabled = true,
    this.loading = false,
  });

  final String? webClientId;
  final String? iosClientId;
  final String? desktopClientId;
  final String? desktopClientSecret;
  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error)? onError;
  final bool enabled;
  final bool loading;

  @override
  State<BarLyticsGoogleSignInButton> createState() => _BarLyticsGoogleSignInButtonState();
}

class _BarLyticsGoogleSignInButtonState extends State<BarLyticsGoogleSignInButton> {
  bool _busy = false;

  Future<void> _initialize() {
    final webClientId = widget.webClientId?.trim();
    if (webClientId == null || webClientId.isEmpty) {
      throw StateError('Falta configurar el Client ID web de Google.');
    }
    final applePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final appleClientId = widget.iosClientId?.trim();
    if (applePlatform && (appleClientId == null || appleClientId.isEmpty)) {
      throw StateError('Falta configurar el Client ID de Google para iOS/macOS.');
    }
    return _ensureGoogleSignInInitialized(
      webClientId: webClientId,
      iosClientId: appleClientId,
    );
  }

  Object _friendlyError(Object error) {
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          return StateError('Ingreso con Google cancelado.');
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return StateError('Google Sign-In no está configurado correctamente para esta aplicación.');
        default:
          return StateError(error.description ?? 'No fue posible ingresar con Google.');
      }
    }
    return error;
  }

  bool get _desktopGoogleFlow =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  Future<void> _openDesktopBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'https' &&
            uri.scheme.toLowerCase() != 'http')) {
      throw StateError('Google devolvió una URL de autorización no válida.');
    }

    // En Windows no usamos el launcher interno de openid_client porque puede
    // terminar interpretando la URL como una ruta del sistema y abrir Explorer.
    // url_launcher con externalApplication delega la URI HTTP(S) al navegador
    // predeterminado del sistema operativo.
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw StateError(
        'No fue posible abrir el navegador para continuar con Google.',
      );
    }
  }

  Future<String> _desktopIdToken() async {
    final clientId = widget.desktopClientId?.trim();
    if (clientId == null || clientId.isEmpty) {
      throw StateError(
        'Falta configurar el Client ID OAuth de tipo Aplicación de escritorio para Google.',
      );
    }

    final clientSecret = widget.desktopClientSecret?.trim();
    if (clientSecret == null || clientSecret.isEmpty) {
      throw StateError(
        'Falta configurar el Client Secret OAuth de la aplicación de escritorio para Google.',
      );
    }

    final issuer = await oidc.Issuer.discover(oidc.Issuer.google);
    final client = oidc.Client(issuer, clientId, clientSecret: clientSecret);
    final flow = oidc.Flow.authorizationCodeWithPKCE(
      client,
      scopes: const ['openid', 'email', 'profile'],
      prompt: 'select_account',
    )..redirectUri = Uri.parse('http://127.0.0.1:42837/');
    final authenticator = oidc.Authenticator.fromFlow(
      flow,
      urlLancher: _openDesktopBrowser,
      redirectMessage:
          'Ingreso completado. Ya puedes cerrar esta ventana y volver a BarLytics.',
    );

    try {
      final credential = await authenticator
          .authorize()
          .timeout(const Duration(minutes: 3));
      final violations = await credential.validateToken().toList();
      if (violations.isNotEmpty) {
        throw StateError('Google devolvió una identidad que no pudo validarse.');
      }
      final response = credential.response;
      final token = response == null ? null : response['id_token']?.toString();
      if (token == null || token.trim().isEmpty) {
        throw StateError('Google no devolvió un token de identidad válido.');
      }
      return token;
    } on TimeoutException {
      await authenticator.cancel();
      throw StateError(
        'El ingreso con Google tardó demasiado. Inténtalo nuevamente.',
      );
    }
  }

  Future<void> _signIn() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    try {
      if (_desktopGoogleFlow) {
        final token = await _desktopIdToken();
        await widget.onIdToken(token);
        return;
      }

      await _initialize();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw StateError('Google Sign-In no está disponible en esta plataforma.');
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.trim().isEmpty) {
        throw StateError('Google no devolvió un token de identidad válido.');
      }
      await widget.onIdToken(token);
    } catch (error) {
      widget.onError?.call(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy || widget.loading;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: widget.enabled && !busy ? _signIn : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          side: const BorderSide(color: Color(0xFFDADCE0), width: 1.1),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const _GoogleMark(),
            const SizedBox(width: 12),
            Text(
              busy ? 'Conectando...' : 'Continuar con Google',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, letterSpacing: .1),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontWeight: FontWeight.w900,
        fontSize: 20,
      ),
    );
  }
}
