import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/tech_background.dart';
import '../providers/auth_provider.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _validationStarted = false;
  bool _validated = false;
  bool _invalid = false;
  bool _invalidDialogShown = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateCodeOnce());
  }

  Future<void> _validateCodeOnce() async {
    if (_validationStarted) return;
    _validationStarted = true;

    if (widget.code.trim().isEmpty) {
      setState(() {
        _invalid = true;
        _message = 'El enlace de recuperación no contiene código.';
      });
      await _showInvalidDialogIfNeeded();
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).validatePasswordRecoveryCode(widget.code.trim());
    if (!mounted) return;
    setState(() {
      _validated = ok;
      _invalid = !ok;
      _message = ok ? null : ref.read(authControllerProvider).failure?.message ?? 'El enlace de recuperación no es válido o expiró.';
    });

    if (!ok) await _showInvalidDialogIfNeeded();
  }

  Future<void> _showInvalidDialogIfNeeded() async {
    if (!mounted || _invalidDialogShown) return;
    _invalidDialogShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const TechBrandMark(icon: Icons.link_off_rounded),
        title: const Text('Enlace vencido o no válido'),
        content: Text(_message ?? 'El código de recuperación expiró. Realice nuevamente el proceso de recuperación de contraseña.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/login');
            },
            child: const Text('Volver al login'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/forgot-password');
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Solicitar nuevo enlace'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
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
              child: _buildContent(context, state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AuthState state) {
    if (state.loading && !_validated && !_invalid) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TechBrandMark(icon: Icons.lock_clock_rounded),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text('Validando enlace de recuperación...', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
    }

    if (_invalid) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TechSectionTitle(
            icon: Icons.link_off_rounded,
            title: 'Enlace no válido',
            subtitle: 'Debes solicitar nuevamente la recuperación de contraseña.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.warning.withOpacity(0.25)),
            ),
            child: Text(_message ?? 'El enlace no es válido o expiró.', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Solicitar nuevo enlace',
            icon: Icons.refresh_rounded,
            onPressed: () => context.go('/forgot-password'),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: () => context.go('/login'), child: const Text('Volver al login')),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TechSectionTitle(
            icon: Icons.lock_reset_rounded,
            title: 'Nueva contraseña',
            subtitle: 'Crea una nueva clave para volver a ingresar.',
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _newPassword,
            label: 'Nueva contraseña',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: (value) {
              final required = Validators.required(value);
              if (required != null) return required;
              if (value!.length < 8) return 'La contraseña debe tener mínimo 8 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _confirmPassword,
            label: 'Confirmar contraseña',
            prefixIcon: Icons.lock_person_outlined,
            obscureText: true,
            validator: (value) {
              final required = Validators.required(value);
              if (required != null) return required;
              if (value != _newPassword.text) return 'Las contraseñas no coinciden';
              return null;
            },
          ),
          const SizedBox(height: 22),
          AppButton(
            label: 'Guardar contraseña',
            icon: Icons.save_rounded,
            loading: state.loading,
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final ok = await ref.read(authControllerProvider.notifier).resetPassword(
                    code: widget.code.trim(),
                    newPassword: _newPassword.text,
                    confirmPassword: _confirmPassword.text,
                  );
              if (!mounted) return;
              if (ok) {
                await _showSuccessDialog();
              } else {
                final failure = ref.read(authControllerProvider).failure;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(failure?.message ?? 'No fue posible actualizar la contraseña.')),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: state.loading ? null : () => context.go('/login'), child: const Text('Volver al login')),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const TechBrandMark(icon: Icons.verified_user_rounded),
        title: const Text('Contraseña actualizada'),
        content: const Text('Tu contraseña fue actualizada correctamente. Ingresa nuevamente con tu nueva clave.'),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/login');
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('Ir al login'),
          ),
        ],
      ),
    );
  }
}
