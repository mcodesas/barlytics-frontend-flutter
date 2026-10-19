import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/auth/google_sign_in_button.dart';
import '../../../../core/auth/apple_sign_in_button.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/barlytics_brand.dart';
import '../../../../core/widgets/tech_background.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  String? _loginErrorMessage;
  bool _hidePassword = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.authenticated) {
        context.go(next.subscriptionActive ? '/home' : '/activar-suscripcion');
        return;
      }


      if (next.failure != null) {
        setState(() => _loginErrorMessage = _messageForLogin(next.failure!));
      }
    });

    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width >= 920;
    final compactHeight = wide && screen.height <= 760;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TechBackground(
              padding: EdgeInsets.all(compactHeight ? 10 : 18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: kIsWeb
                          ? (screen.width < 620 ? 62 : 12)
                          : (compactHeight ? 4 : 10),
                      bottom: kIsWeb ? 14 : (compactHeight ? 4 : 10),
                    ),
                    child: kIsWeb
                        // Login web sin sección comercial, vídeo ni animaciones:
                        // solo el formulario, centrado y legible en cualquier ancho.
                        ? Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 530),
                              child: _GlassLoginCard(
                                state: this,
                                loading: state.loading,
                                dense: compactHeight,
                              ),
                            ),
                          )
                        : wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: _BarHero(dense: compactHeight)),
                                  SizedBox(width: compactHeight ? 22 : 34),
                                  Expanded(
                                    child: _GlassLoginCard(
                                      state: this,
                                      loading: state.loading,
                                      dense: compactHeight,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  const _BarHero(compact: true),
                                  const SizedBox(height: 20),
                                  _GlassLoginCard(
                                    state: this,
                                    loading: state.loading,
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
            ),
          ),
          if (kIsWeb)
            const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _BackToPublicSiteButton(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _googleLogin(String idToken) async {
    setState(() => _loginErrorMessage = null);
    final ok = await ref.read(authControllerProvider.notifier).googleLogin(idToken);
    if (!ok && mounted) {
      final failure = ref.read(authControllerProvider).failure;
      // Si la sesión fue invalidada de forma preventiva (por ejemplo, usuario
      // sin roles), el controlador vuelve al login sin failure. No mostramos un
      // error falso encima de la pantalla.
      if (failure == null) return;
      setState(() {
        final raw = failure.message;
        _loginErrorMessage = raw.toLowerCase().contains('no encontrado')
            ? 'Esta cuenta de Google aún no está registrada. Crea tu cuenta para continuar.'
            : (raw.isEmpty ? 'No fue posible iniciar sesión con Google.' : raw);
      });
    }
  }

  Future<void> _appleLogin(AppleSignInResult result) async {
    setState(() => _loginErrorMessage = null);
    final ok = await ref.read(authControllerProvider.notifier).appleLogin(result.idToken);
    if (!mounted) return;
    if (!ok) {
      final failure = ref.read(authControllerProvider).failure;
      final raw = failure?.message ?? '';
      setState(() {
        _loginErrorMessage = raw.toLowerCase().contains('no encontrado')
            ? 'Esta cuenta de Apple aún no está registrada. Crea tu cuenta para continuar.'
            : (raw.isEmpty ? 'No fue posible iniciar sesión con Apple.' : raw);
      });
      return;
    }
    final auth = ref.read(authControllerProvider);
    context.go(auth.subscriptionActive ? '/home' : '/activar-suscripcion');
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loginErrorMessage = null);
    await ref.read(authControllerProvider.notifier).login(
          _identifier.text.trim(),
          _password.text,
        );
  }

  String _messageForLogin(Failure failure) {
    final raw = failure.message.trim();
    final lower = raw.toLowerCase();

    if (lower.contains('bloque') ||
        lower.contains('intentos de ingreso') ||
        lower.contains('intentos fallidos')) {
      return raw.isEmpty
          ? 'Por intentos de ingreso fallidos se bloqueó la cuenta. Use la opción Olvidé mi contraseña para desbloquearla.'
          : raw;
    }

    if (lower.contains('solicitó cambio de contraseña') ||
        lower.contains('recuperación') ||
        lower.contains('recuperacion')) {
      return raw;
    }

    if (failure.statusCode == 401 ||
        failure.statusCode == 404 ||
        lower.contains('credencial') ||
        lower.contains('usuario no encontrado') ||
        lower.contains('contraseña')) {
      return 'Usuario o contraseña incorrectos.';
    }

    return raw.isEmpty ? 'Usuario o contraseña incorrectos.' : raw;
  }
}

class _BackToPublicSiteButton extends ConsumerWidget {
  const _BackToPublicSiteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Semantics(
      button: true,
      label: 'Volver a la página principal de BarLytics',
      child: OutlinedButton.icon(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
        icon: const Icon(Icons.arrow_back_rounded, size: 19),
        label: const Text('Volver'),
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          backgroundColor: palette.surface.withOpacity(0.82),
          side: BorderSide(color: palette.primary.withOpacity(0.36)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _GlassLoginCard extends ConsumerWidget {
  const _GlassLoginCard({
    required this.state,
    required this.loading,
    this.dense = false,
  });

  final _LoginPageState state;
  final bool loading;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    const darkInk = Color(0xFF06111F);
    final outerRadius = dense ? 24.0 : 28.0;
    final innerRadius = dense ? 22.0 : 26.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(outerRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(2.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outerRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.primary.withOpacity(0.60),
                palette.secondary.withOpacity(0.54),
                Colors.white.withOpacity(0.27),
                palette.accent.withOpacity(0.60),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withOpacity(0.22),
                blurRadius: dense ? 28 : 42,
                offset: Offset(0, dense ? 10 : 18),
              ),
              BoxShadow(
                color: palette.secondary.withOpacity(0.22),
                blurRadius: dense ? 38 : 58,
                offset: Offset(dense ? -8 : -12, dense ? 12 : 20),
              ),
            ],
          ),
          child: Container(
            padding: dense
                ? const EdgeInsets.fromLTRB(22, 15, 22, 14)
                : const EdgeInsets.fromLTRB(28, 26, 28, 26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(innerRadius),
              color: palette.surface.withOpacity(0.86),
              border: Border.all(color: palette.textPrimary.withOpacity(0.16)),
            ),
            child: AutofillGroup(
              child: Form(
              key: state._formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WelcomeHeader(dense: dense),
                  SizedBox(height: dense ? 10 : 22),
                  _AccessModeStrip(dense: dense),
                  SizedBox(height: dense ? 10 : 18),
                  _GoogleLoginSection(state: state, loading: loading),
                  if (BarLyticsAppleSignInButton.supported) ...[
                    SizedBox(height: dense ? 7 : 8),
                    BarLyticsAppleSignInButton(
                      loading: loading,
                      onCredential: state._appleLogin,
                      onError: (error) {
                        state.setState(() {
                          state._loginErrorMessage = error.toString()
                              .replaceFirst('Bad state: ', '')
                              .replaceFirst('Exception: ', '');
                        });
                      },
                    ),
                  ],
                  SizedBox(height: dense ? 10 : 14),
                  Row(
                    children: [
                      Expanded(child: Divider(color: palette.translucentBorder.withOpacity(.75))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 12),
                        child: Text(
                          'o ingresa con tu correo',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: dense ? 10.5 : 11,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: palette.translucentBorder.withOpacity(.75))),
                    ],
                  ),
                  SizedBox(height: dense ? 8 : 16),
                  _GlassTextField(
                    controller: state._identifier,
                    label: 'Usuario o correo',
                    hint: 'correo@barlytics.com',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    maxLength: 255,
                    validator: Validators.required,
                    dense: dense,
                    onChanged: (_) {
                      if (state._loginErrorMessage != null) {
                        state.setState(() => state._loginErrorMessage = null);
                      }
                    },
                  ),
                  SizedBox(height: dense ? 8 : 14),
                  _GlassTextField(
                    controller: state._password,
                    label: 'Contraseña',
                    hint: 'Clave segura',
                    icon: Icons.lock_outline_rounded,
                    obscureText: state._hidePassword,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => loading ? null : state._login(),
                    maxLength: 72,
                    validator: Validators.required,
                    dense: dense,
                    onChanged: (_) {
                      if (state._loginErrorMessage != null) {
                        state.setState(() => state._loginErrorMessage = null);
                      }
                    },
                    suffixIcon: IconButton(
                      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
                      onPressed: () => state.setState(
                        () => state._hidePassword = !state._hidePassword,
                      ),
                      icon: Icon(
                        state._hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: palette.textPrimary.withOpacity(0.78),
                      ),
                    ),
                  ),
                  if (state._loginErrorMessage != null) ...[
                    SizedBox(height: dense ? 8 : 14),
                    _LoginAlert(message: state._loginErrorMessage!),
                  ],
                  SizedBox(height: dense ? 10 : 22),
                  SizedBox(
                    height: dense ? 48 : 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(dense ? 16 : 18),
                        gradient: LinearGradient(
                          colors: [palette.primary, palette.secondary, palette.accent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withOpacity(0.28),
                            blurRadius: dense ? 18 : 26,
                            offset: Offset(0, dense ? 7 : 12),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: darkInk,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(dense ? 16 : 18),
                          ),
                        ),
                        onPressed: loading ? null : state._login,
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: darkInk,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(
                          loading ? 'Validando acceso...' : 'Entrar a BarLytics',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: dense ? 8 : 12),
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => context.go('/registro'),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Registrarse'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.primary.withOpacity(0.42)),
                      backgroundColor: palette.primary.withOpacity(0.07),
                      padding: EdgeInsets.symmetric(vertical: dense ? 10 : 15),
                      minimumSize: Size.fromHeight(dense ? 40 : 48),
                      tapTargetSize: dense
                          ? MaterialTapTargetSize.shrinkWrap
                          : MaterialTapTargetSize.padded,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(dense ? 14 : 16),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (dense) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: loading
                                ? null
                                : () => context.go('/forgot-password'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12.5),
                            ),
                            child: const Text('Olvidé mi contraseña'),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: loading
                                ? null
                                : () => context.go('/reset-password'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(fontSize: 12.5),
                            ),
                            icon: const Icon(Icons.pin_rounded, size: 16),
                            label: const Text('Activar con código'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => context.go('/forgot-password'),
                      child: const Text('Olvidé mi contraseña'),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: loading
                          ? null
                          : () => context.go('/reset-password'),
                      icon: const Icon(Icons.pin_rounded),
                      label: const Text('Activar con código'),
                    ),
                  ],
                  SizedBox(height: dense ? 2 : 4),
                  OutlinedButton.icon(
                    onPressed: () => showPaletteSettingsDialog(context),
                    icon: Icon(Icons.palette_outlined, size: dense ? 17 : 20),
                    label: const Text('Personalizar colores'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.primary.withOpacity(0.30)),
                      backgroundColor: palette.textPrimary.withOpacity(0.055),
                      padding: EdgeInsets.symmetric(vertical: dense ? 9 : 15),
                      minimumSize: Size.fromHeight(dense ? 38 : 48),
                      tapTargetSize: dense
                          ? MaterialTapTargetSize.shrinkWrap
                          : MaterialTapTargetSize.padded,
                    ),
                  ),
                  SizedBox(height: dense ? 8 : 16),
                  _SecurityNote(dense: dense),
                  SizedBox(height: dense ? 5 : 14),
                  _LoginLegalFooter(dense: dense),
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

class _GoogleLoginSection extends ConsumerWidget {
  const _GoogleLoginSection({required this.state, required this.loading});
  final _LoginPageState state;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(googleAuthConfigProvider);
    return config.when(
      loading: () => const SizedBox(height: 46, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () => ref.invalidate(googleAuthConfigProvider),
          icon: const Icon(Icons.refresh_rounded, size: 19),
          label: const Text('Reintentar ingreso con Google'),
        ),
      ),
      data: (google) {
        if (!google.enabled) return const SizedBox.shrink();
        return BarLyticsGoogleSignInButton(
          webClientId: google.webClientId,
          iosClientId: google.iosClientId,
          desktopClientId: google.desktopClientId,
          desktopClientSecret: google.desktopClientSecret,
          loading: loading,
          onIdToken: state._googleLogin,
          onError: (error) {
            state.setState(() {
              state._loginErrorMessage = error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
            });
          },
        );
      },
    );
  }
}

class _WelcomeHeader extends ConsumerWidget {
  const _WelcomeHeader({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BarLyticsBrandLockup(
          width: dense ? 225 : 270,
          height: dense ? 58 : 78,
          darkBackground: true,
          showTagline: false,
          alignment: Alignment.centerLeft,
        ),
        SizedBox(height: dense ? 4 : 10),
        Text(
          'Tecnología para administrar tu bar en tiempo real',
          maxLines: dense ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textPrimary.withOpacity(0.78),
            height: dense ? 1.20 : 1.35,
            fontWeight: FontWeight.w600,
            fontSize: dense ? 12.3 : null,
          ),
        ),
      ],
    );
  }
}

class _AccessModeStrip extends ConsumerWidget {
  const _AccessModeStrip({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Container(
      padding: EdgeInsets.all(dense ? 8 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dense ? 15 : 18),
        color: palette.textPrimary.withOpacity(0.055),
        border: Border.all(color: palette.primary.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          _MiniTechChip(
            icon: Icons.point_of_sale_rounded,
            label: 'Caja',
            dense: dense,
          ),
          SizedBox(width: dense ? 6 : 8),
          _MiniTechChip(
            icon: Icons.table_bar_rounded,
            label: 'Mesas',
            dense: dense,
          ),
          SizedBox(width: dense ? 6 : 8),
          Expanded(
            child: Text(
              'Acceso inteligente',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.textPrimary.withOpacity(0.60),
                fontWeight: FontWeight.w700,
                fontSize: dense ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTechChip extends ConsumerWidget {
  const _MiniTechChip({
    required this.icon,
    required this.label,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: palette.primary.withOpacity(0.10),
        border: Border.all(color: palette.primary.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 14 : 15, color: palette.primary),
          SizedBox(width: dense ? 5 : 6),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: dense ? 11.3 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassTextField extends ConsumerWidget {
  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.maxLength,
    this.dense = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final radius = dense ? 16.0 : 20.0;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      enableSuggestions: !obscureText,
      autocorrect: false,
      validator: validator,
      onChanged: onChanged,
      maxLength: maxLength,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: dense ? 14.0 : null,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: dense ? 20 : 24),
        prefixIconConstraints: dense
            ? const BoxConstraints(minWidth: 42, minHeight: 42)
            : null,
        suffixIcon: suffixIcon,
        suffixIconConstraints: dense
            ? const BoxConstraints(minWidth: 42, minHeight: 42)
            : null,
        counterText: maxLength == null ? null : '',
        isDense: dense,
        contentPadding: EdgeInsets.symmetric(
          horizontal: dense ? 13 : 16,
          vertical: dense ? 12 : 16,
        ),
        filled: true,
        fillColor: palette.textPrimary.withOpacity(0.095),
        labelStyle: TextStyle(
          color: palette.textPrimary.withOpacity(0.82),
          fontSize: dense ? 13.5 : null,
        ),
        hintStyle: TextStyle(
          color: palette.textPrimary.withOpacity(0.38),
          fontSize: dense ? 13.0 : null,
        ),
        prefixIconColor: palette.primary,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: palette.primary.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
        errorStyle: TextStyle(
          fontSize: dense ? 10.5 : null,
          height: dense ? 1.05 : null,
        ),
      ),
    );
  }
}

class _BarHero extends ConsumerWidget {
  const _BarHero({this.compact = false, this.dense = false});

  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final padding = compact ? 18.0 : (dense ? 22.0 : 32.0);
    final radius = compact ? 30.0 : (dense ? 34.0 : 44.0);
    final avatarSize = compact ? 54.0 : (dense ? 62.0 : 76.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: palette.textPrimary.withOpacity(0.070),
        border: Border.all(color: palette.primary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withOpacity(0.11),
            blurRadius: dense ? 28 : 42,
            offset: Offset(0, dense ? 12 : 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.blur_on_rounded,
              size: compact ? 88 : (dense ? 108 : 140),
              color: palette.primary.withOpacity(0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BarAvatar(
                    icon: Icons.sports_bar_rounded,
                    color: palette.primary,
                    size: avatarSize,
                  ),
                  SizedBox(width: compact ? 10 : (dense ? 11 : 14)),
                  _BarAvatar(
                    icon: Icons.local_bar_rounded,
                    color: palette.secondary,
                    size: avatarSize,
                  ),
                  SizedBox(width: compact ? 10 : (dense ? 11 : 14)),
                  _BarAvatar(
                    icon: Icons.wine_bar_rounded,
                    color: palette.accent,
                    size: avatarSize,
                  ),
                ],
              ),
              if (!compact) ...[
                SizedBox(height: dense ? 20 : 30),
                Text(
                  'BarLytics para tu negocio',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: dense ? 30 : 36,
                    fontWeight: FontWeight.w900,
                    height: 1.04,
                    letterSpacing: dense ? -0.5 : -0.8,
                  ),
                ),
                SizedBox(height: dense ? 8 : 12),
                Text(
                  'Una plataforma para administrar mesas, ventas, caja e inventario con una experiencia moderna y cercana.',
                  style: TextStyle(
                    color: palette.textPrimary.withOpacity(0.79),
                    height: dense ? 1.34 : 1.45,
                    fontSize: dense ? 14 : 16,
                  ),
                ),
                SizedBox(height: dense ? 14 : 24),
                Wrap(
                  spacing: dense ? 8 : 10,
                  runSpacing: dense ? 8 : 10,
                  children: [
                    _HeroChip(
                      icon: Icons.point_of_sale_rounded,
                      label: 'Ventas rápidas',
                      dense: dense,
                    ),
                    _HeroChip(
                      icon: Icons.memory_outlined,
                      label: 'Bar Tech',
                      dense: dense,
                    ),
                    _HeroChip(
                      icon: Icons.inventory_2_outlined,
                      label: 'Inventario inteligente',
                      dense: dense,
                    ),
                    _HeroChip(
                      icon: Icons.auto_graph_outlined,
                      label: 'Gestión operativa',
                      dense: dense,
                    ),
                  ],
                ),
                SizedBox(height: dense ? 14 : 24),
                _TelemetryPanel(dense: dense),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BarAvatar extends StatelessWidget {
  const _BarAvatar({required this.icon, required this.color, required this.size});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.36), Colors.white.withOpacity(0.07)],
        ),
        border: Border.all(color: color.withOpacity(0.70), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.44),
    );
  }
}

class _HeroChip extends ConsumerWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 11 : 14,
        vertical: dense ? 8 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: palette.textPrimary.withOpacity(0.055),
        border: Border.all(color: palette.primary.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 15 : 17, color: palette.primary),
          SizedBox(width: dense ? 6 : 7),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: dense ? 11.5 : 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryPanel extends ConsumerWidget {
  const _TelemetryPanel({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Container(
      padding: EdgeInsets.all(dense ? 12 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dense ? 18 : 24),
        color: palette.surface.withOpacity(0.48),
        border: Border.all(color: palette.primary.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TelemetryItem(
              label: 'Ventas',
              value: 'Live',
              dense: dense,
            ),
          ),
          SizedBox(width: dense ? 8 : 12),
          Expanded(
            child: _TelemetryItem(
              label: 'Mesas',
              value: 'Smart',
              dense: dense,
            ),
          ),
          SizedBox(width: dense ? 8 : 12),
          Expanded(
            child: _TelemetryItem(
              label: 'Inventario',
              value: 'Track',
              dense: dense,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryItem extends ConsumerWidget {
  const _TelemetryItem({
    required this.label,
    required this.value,
    this.dense = false,
  });

  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: palette.primary,
            fontSize: dense ? 15 : 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: dense ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            color: palette.textPrimary.withOpacity(0.64),
            fontSize: dense ? 11 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LoginAlert extends ConsumerWidget {
  const _LoginAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    const danger = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: danger.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: danger.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNote extends ConsumerWidget {
  const _SecurityNote({this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Container(
      padding: EdgeInsets.all(dense ? 8 : 12),
      decoration: BoxDecoration(
        color: palette.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(dense ? 14 : 18),
        border: Border.all(color: palette.primary.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: dense ? 17 : 20,
            color: palette.primary.withOpacity(0.95),
          ),
          SizedBox(width: dense ? 7 : 10),
          Expanded(
            child: Text(
              dense
                  ? 'Acceso seguro con JWT, roles y API protegida.'
                  : 'Acceso seguro para meseros, cajeros y administración. JWT + roles + API protegida.',
              maxLines: dense ? 1 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary.withOpacity(0.76),
                fontSize: dense ? 11.2 : 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginLegalFooter extends ConsumerWidget {
  const _LoginLegalFooter({this.dense = false});

  final bool dense;

  Future<void> _openLegalPage(BuildContext context, String path) async {
    final uri = Uri.parse('https://www.barlytics.com.co$path');
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No fue posible abrir www.barlytics.com.co$path'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final linkStyle = TextButton.styleFrom(
      foregroundColor: palette.primary,
      minimumSize: Size.zero,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 3 : 4,
        vertical: dense ? 1 : 3,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: TextStyle(
        fontSize: dense ? 10.5 : 11.5,
        fontWeight: FontWeight.w700,
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        Text(
          '© BarLytics',
          style: TextStyle(
            color: palette.textSecondary.withOpacity(.82),
            fontSize: dense ? 10.5 : 11.5,
          ),
        ),
        Text(
          '·',
          style: TextStyle(color: palette.textSecondary.withOpacity(.60)),
        ),
        TextButton(
          onPressed: () => _openLegalPage(context, '/terminos/'),
          style: linkStyle,
          child: const Text('Términos y condiciones'),
        ),
        Text(
          '·',
          style: TextStyle(color: palette.textSecondary.withOpacity(.60)),
        ),
        TextButton(
          onPressed: () => _openLegalPage(context, '/privacidad/'),
          style: linkStyle,
          child: const Text('Política de privacidad'),
        ),
      ],
    );
  }
}

