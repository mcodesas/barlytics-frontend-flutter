import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
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
        context.go('/home');
        return;
      }
      if (next.failure != null) {
        setState(() => _loginErrorMessage = _messageForLogin(next.failure!));
      }
    });

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: TechBackground(
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

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) => Padding(
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
              child: const Text(
                'Plataforma inteligente para bares',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 24),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 52, height: 1.02, fontWeight: FontWeight.w900, color: Colors.white),
                children: [
                  TextSpan(text: 'Controla ventas,\n'),
                  TextSpan(text: 'inventario y mesas\n'),
                  TextSpan(text: 'en tiempo real.', style: TextStyle(color: AppColors.accent)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Una experiencia moderna, segura y disponible para todos los dispositivos soportados.',
              style: TextStyle(color: Colors.white.withOpacity(0.74), fontSize: 17, height: 1.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _HeroMetric(icon: Icons.point_of_sale_rounded, label: 'POS'),
                _HeroMetric(icon: Icons.inventory_2_rounded, label: 'Inventario'),
                _HeroMetric(icon: Icons.insights_rounded, label: 'Analítica'),
              ],
            ),
          ],
        ),
      );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _LoginAlert extends StatelessWidget {
  const _LoginAlert({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.danger.withOpacity(0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800))),
          ],
        ),
      );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.secondaryDark),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tus credenciales viajan de forma segura y se protegen con token de sesión.',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
