import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/tech_background.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController(text: '');
  final _password = TextEditingController(text: '');
  String? _loginErrorMessage;

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
        final isOperativoMesa = next.roles.any((role) {
          final normalized = role.toUpperCase();
          return normalized.contains('MESERO') ||
              normalized.contains('MESER') ||
              normalized.contains('CAJERO') ||
              normalized.contains('CAJER') ||
              normalized.contains('VENDEDOR') ||
              normalized.contains('VENTA') ||
              normalized.contains('SELLER');
        });
        context.go(isOperativoMesa ? '/mesero' : '/home');
        return;
      }
      if (next.failure != null) {
        setState(() => _loginErrorMessage = _messageForLogin(next.failure!));
      }
    });

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TechBackground(
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Row(
                      children: [
                        if (isWide) const Expanded(child: _LoginHero()),
                        if (isWide) const SizedBox(width: 30),
                        Expanded(
                          child: TechGlassPanel(
                            maxWidth: 500,
                            padding: const EdgeInsets.all(28),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const TechSectionTitle(
                                    title: 'BarLytics',
                                    subtitle: 'Acceso seguro a tu operación',
                                    icon: Icons.analytics_rounded,
                                  ),
                                  const SizedBox(height: 26),
                                  AppTextField(
                                    controller: _identifier,
                                    label: 'Correo o identificador',
                                    prefixIcon: Icons.email_outlined,
                                    validator: Validators.required,
                                    onChanged: (_) {
                                      if (_loginErrorMessage != null) setState(() => _loginErrorMessage = null);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    controller: _password,
                                    label: 'Contraseña',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: true,
                                    validator: Validators.required,
                                    onChanged: (_) {
                                      if (_loginErrorMessage != null) setState(() => _loginErrorMessage = null);
                                    },
                                  ),
                                  if (_loginErrorMessage != null) ...[
                                    const SizedBox(height: 14),
                                    _LoginAlert(message: _loginErrorMessage!),
                                  ],
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: state.loading ? null : () => context.go('/forgot-password'),
                                      icon: const Icon(Icons.help_outline_rounded, size: 18),
                                      label: const Text('¿Olvidaste tu contraseña?'),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  AppButton(
                                    label: 'Ingresar',
                                    icon: Icons.login_rounded,
                                    loading: state.loading,
                                    onPressed: () async {
                                      if (!_formKey.currentState!.validate()) return;
                                      setState(() => _loginErrorMessage = null);
                                      await ref.read(authControllerProvider.notifier).login(_identifier.text.trim(), _password.text);
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  const _SecurityNote(),
                                  const SizedBox(height: 10),
                                  TextButton.icon(
                                    onPressed: () => showPaletteSettingsDialog(context),
                                    icon: const Icon(Icons.palette_rounded, size: 18),
                                    label: const Text('Personalizar colores'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _messageForLogin(Failure failure) {
    final raw = failure.message.trim();
    final lower = raw.toLowerCase();

    if (lower.contains('bloque') || lower.contains('intentos de ingreso') || lower.contains('intentos fallidos')) {
      return raw.isEmpty ? 'Por intentos de ingreso fallidos se bloqueó la cuenta. Use la opción Olvidé mi contraseña para desbloquearla.' : raw;
    }

    if (lower.contains('solicitó cambio de contraseña') || lower.contains('recuperación') || lower.contains('recuperacion')) {
      return raw;
    }

    if (failure.statusCode == 401 || failure.statusCode == 404 || lower.contains('credencial') || lower.contains('usuario no encontrado') || lower.contains('contraseña')) {
      return 'Usuario o contraseña incorrectos.';
    }

    return raw.isEmpty ? 'Usuario o contraseña incorrectos.' : raw;
  }
}

class _LoginHero extends ConsumerWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: Text(
                'Plataforma inteligente para bares',
                style: TextStyle(color: palette.onTitle, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 24),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 52, height: 1.02, fontWeight: FontWeight.w900, color: palette.onTitle),
                children: [
                  const TextSpan(text: 'Controla ventas,\n'),
                  const TextSpan(text: 'inventario y mesas\n'),
                  TextSpan(text: 'en tiempo real.', style: TextStyle(color: palette.accent)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Una experiencia moderna, segura y disponible para todos los dispositivos soportados.',
              style: TextStyle(color: palette.onTitle.withOpacity(0.78), fontSize: 17, height: 1.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HeroMetric(icon: Icons.point_of_sale_rounded, label: 'POS'),
                _HeroMetric(icon: Icons.inventory_2_rounded, label: 'Inventario'),
                _HeroMetric(icon: Icons.insights_rounded, label: 'Analítica'),
              ],
            ),
          ],
        ),
      );
  }
}

class _HeroMetric extends ConsumerWidget {
  const _HeroMetric({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: palette.accent, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: palette.onTitle, fontWeight: FontWeight.w800)),
          ],
        ),
      );
  }
}

class _LoginAlert extends ConsumerWidget {
  const _LoginAlert({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final danger = Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger.withOpacity(palette.darkBackground ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: danger.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: danger, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _SecurityNote extends ConsumerWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: palette.glassGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.translucentBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: palette.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tus credenciales viajan de forma segura y se protegen con token de sesión.',
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
