import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/tech_background.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      body: TechBackground(
        child: Center(
          child: SingleChildScrollView(
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
                      title: 'Recuperar contraseña',
                      subtitle: 'Te enviaremos un enlace seguro a tu correo.',
                      icon: Icons.mark_email_read_rounded,
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      controller: _email,
                      label: 'Correo electrónico',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 100,
                      validator: (value) {
                        final required = Validators.required(value);
                        if (required != null) return required;
                        return Validators.email(value);
                      },
                      onChanged: (_) {
                        if (_errorMessage != null) setState(() => _errorMessage = null);
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _InfoBox(
                        icon: Icons.warning_amber_rounded,
                        message: _errorMessage!,
                        color: AppColors.danger,
                        background: AppColors.dangerSoft,
                      ),
                    ],
                    const SizedBox(height: 22),
                    AppButton(
                      label: 'Enviar enlace de recuperación',
                      icon: Icons.send_rounded,
                      loading: state.loading,
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _errorMessage = null);
                        final ok = await ref.read(authControllerProvider.notifier).requestPasswordRecovery(_email.text.trim());
                        if (!mounted) return;
                        if (ok) {
                          await _showConfirmationDialog();
                        } else {
                          setState(() {
                            _errorMessage = ref.read(authControllerProvider).failure?.message ?? 'No fue posible enviar el correo de recuperación.';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: state.loading ? null : () => context.go('/login'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Volver al login'),
                    ),
                    const SizedBox(height: 10),
                    const _InfoBox(
                      icon: Icons.security_rounded,
                      message: 'Por seguridad, el enlace enviado solo estará disponible durante 1 hora.',
                      color: AppColors.secondaryDark,
                      background: AppColors.surfaceAlt,
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

  Future<void> _showConfirmationDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        icon: const TechBrandMark(icon: Icons.mark_email_read_rounded),
        title: const Text('Correo enviado'),
        content: Text(
          'Se envió un enlace de recuperación a ${_email.text.trim()}. Revisa tu bandeja de entrada o spam para crear una nueva contraseña.',
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/login');
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('Volver al login'),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.message, required this.color, required this.background});

  final IconData icon;
  final String message;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w800))),
          ],
        ),
      );
}
