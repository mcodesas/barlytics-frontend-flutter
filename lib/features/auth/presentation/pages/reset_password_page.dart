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
  final _activationCode = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _validationStarted = false;
  bool _validated = false;
  bool _invalid = false;
  bool _invalidDialogShown = false;
  String? _message;
  String _activeCode = '';
  bool _manualMode = false;

  @override
  void initState() {
    super.initState();
    final codeFromLink = widget.code.trim();
    _manualMode = codeFromLink.isEmpty;
    if (codeFromLink.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _validateCode(codeFromLink, fromLink: true));
    }
  }

  Future<void> _validateCode(String code, {required bool fromLink}) async {
    final normalized = code.trim();
    if (normalized.isEmpty || _validationStarted) return;

    setState(() {
      _validationStarted = true;
      _invalid = false;
      _message = null;
    });

    final ok = await ref.read(authControllerProvider.notifier).validatePasswordRecoveryCode(normalized);
    if (!mounted) return;
    setState(() {
      _validationStarted = false;
      _validated = ok;
      _invalid = !ok;
      _activeCode = ok ? normalized : '';
      _message = ok
          ? null
          : ref.read(authControllerProvider).failure?.message ??
              (fromLink ? 'El enlace no es válido o expiró.' : 'El código no es válido o expiró.');
    });

    if (!ok && fromLink) await _showInvalidDialogIfNeeded();
  }

  Future<void> _validateManualCode() async {
    final code = _activationCode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _invalid = false;
        _message = 'Ingresa el código de activación de 6 dígitos enviado a tu correo.';
      });
      return;
    }
    await _validateCode(code, fromLink: false);
  }

  void _retryManualCode() {
    setState(() {
      _invalid = false;
      _validated = false;
      _validationStarted = false;
      _invalidDialogShown = false;
      _activeCode = '';
      _manualMode = true;
      _message = null;
    });
    _activationCode.clear();
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
        content: Text(_message ?? 'El enlace expiró. Solicita un nuevo enlace de activación o recuperación de contraseña.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/login');
            },
            child: const Text('Volver al login'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _retryManualCode();
            },
            icon: const Icon(Icons.pin_rounded),
            label: const Text('Ingresar código'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/forgot-password');
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Solicitar recuperación'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _activationCode.dispose();
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
    if (_validationStarted && state.loading && !_validated && !_invalid) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TechBrandMark(icon: Icons.lock_clock_rounded),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text('Validando activación...', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
    }

    if (!_validated && _manualMode) {
      return Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TechSectionTitle(
              icon: Icons.pin_rounded,
              title: 'Activar con código',
              subtitle: 'Ingresa el código de 6 dígitos que recibiste en el correo de activación.',
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _activationCode,
              label: 'Código de activación',
              hintText: 'Ej. 483921',
              prefixIcon: Icons.password_rounded,
              keyboardType: TextInputType.number,
              validator: (value) {
                final required = Validators.required(value);
                if (required != null) return required;
                if (!RegExp(r'^\d{6}$').hasMatch(value!.trim())) {
                  return 'El código debe tener 6 dígitos';
                }
                return null;
              },
              onChanged: (_) {
                if (_message != null) setState(() => _message = null);
              },
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.warning.withOpacity(0.25)),
                ),
                child: Text(
                  _message!,
                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w900),
                ),
              ),
            ],
            const SizedBox(height: 22),
            AppButton(
              label: 'Validar código',
              icon: Icons.verified_rounded,
              loading: state.loading || _validationStarted,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                await _validateManualCode();
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.loading ? null : () => context.go('/login'),
              child: const Text('Volver al login'),
            ),
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
            title: 'Código o enlace no válido',
            subtitle: 'Puedes ingresar otro código o solicitar una nueva activación/recuperación.',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.warning.withOpacity(0.25)),
            ),
            child: Text(_message ?? 'El código o enlace no es válido o expiró.', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Ingresar otro código',
            icon: Icons.pin_rounded,
            onPressed: _retryManualCode,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/forgot-password'),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Solicitar recuperación'),
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
            title: 'Crear contraseña',
            subtitle: 'Código validado. Registra una clave para completar la activación o recuperar el acceso.',
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _newPassword,
            label: 'Contraseña',
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
                    code: _activeCode,
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
        title: const Text('Contraseña registrada'),
        content: const Text('Tu contraseña fue registrada correctamente. Ingresa con tu correo y nueva clave.'),
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
