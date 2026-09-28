import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:openid_client/openid_client_io.dart' as oidc;
import 'package:url_launcher/url_launcher.dart';


Future<void>? _googleSignInInitialization;


const String _desktopOAuthSuccessHtml = r'''<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <title>BarLytics - Inicio de sesión completado</title>
  <style>
    * { box-sizing: border-box; }
    html, body { margin: 0; min-height: 100%; }
    body {
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 24px;
      color: #f4fbff;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at 16% 18%, rgba(22, 214, 194, .18), transparent 34%),
        radial-gradient(circle at 84% 82%, rgba(0, 178, 255, .16), transparent 38%),
        #071f2c;
    }
    .card {
      width: min(520px, 100%);
      padding: 34px 32px 30px;
      text-align: center;
      border: 1px solid rgba(62, 229, 214, .36);
      border-radius: 26px;
      background: rgba(9, 51, 66, .94);
      box-shadow: 0 28px 80px rgba(0, 0, 0, .34);
    }
    .brand {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 28px;
      font-size: 30px;
      font-weight: 900;
      letter-spacing: -1.4px;
    }
    .mark {
      width: 44px;
      height: 44px;
      display: grid;
      place-items: center;
      border-radius: 12px;
      color: #062b39;
      font-size: 28px;
      font-weight: 1000;
      background: linear-gradient(145deg, #21e2c6 0%, #00bdf2 56%, #087cff 100%);
      box-shadow: 0 10px 26px rgba(0, 190, 238, .22);
    }
    .brand-word { color: #ffffff; }
    .brand-word span {
      background: linear-gradient(90deg, #16e1c5, #00bdf2);
      -webkit-background-clip: text;
      background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .success {
      width: 68px;
      height: 68px;
      margin: 0 auto 20px;
      display: grid;
      place-items: center;
      border-radius: 50%;
      color: #052d36;
      font-size: 36px;
      font-weight: 1000;
      background: linear-gradient(145deg, #28e2c3, #70efbe);
      box-shadow: 0 12px 34px rgba(40, 226, 195, .22);
    }
    h1 {
      margin: 0 0 10px;
      font-size: 26px;
      line-height: 1.18;
      letter-spacing: -.45px;
    }
    p {
      margin: 0 auto;
      max-width: 390px;
      color: #b9cbd3;
      font-size: 15px;
      line-height: 1.55;
    }
    .hint {
      margin-top: 22px;
      padding-top: 18px;
      border-top: 1px solid rgba(151, 211, 222, .16);
      color: #7f9eaa;
      font-size: 12.5px;
    }
    button {
      margin-top: 22px;
      min-height: 44px;
      padding: 0 22px;
      border: 0;
      border-radius: 999px;
      color: #052d36;
      font: inherit;
      font-weight: 800;
      cursor: pointer;
      background: linear-gradient(90deg, #22dec5, #42c8ed);
      box-shadow: 0 10px 26px rgba(25, 217, 219, .18);
    }
    button:hover { filter: brightness(1.06); }
  </style>
</head>
<body>
  <main class="card">
    <div class="brand">
      <div class="mark">B</div>
      <div class="brand-word">Bar<span>Lytics</span></div>
    </div>
    <div class="success">✓</div>
    <h1>Inicio de sesión completado</h1>
    <p>Tu cuenta de Google fue verificada correctamente. Ya puedes volver a BarLytics y continuar trabajando.</p>
    <button type="button" onclick="window.close()">Volver a BarLytics</button>
    <div class="hint">Esta pestaña intentará cerrarse automáticamente. Si permanece abierta, puedes cerrarla de forma segura.</div>
  </main>
  <script>
    setTimeout(function () {
      try { window.close(); } catch (_) {}
    }, 1800);
  </script>
</body>
</html>''';


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
      htmlPage: _desktopOAuthSuccessHtml,
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
      height: 46,
      child: OutlinedButton(
        onPressed: widget.enabled && !busy ? _signIn : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          side: const BorderSide(color: Color(0xFFE4E7EB), width: 1),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
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
            const SizedBox(width: 10),
            Text(
              busy ? 'Conectando...' : 'Continuar con Google',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.0, letterSpacing: .05),
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
