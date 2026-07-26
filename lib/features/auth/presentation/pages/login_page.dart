import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/validators.dart';
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
        context.go('/home');
        return;
      }


      if (next.failure != null) {
        setState(() => _loginErrorMessage = _messageForLogin(next.failure!));
      }
    });

    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width >= 920;

    return Scaffold(
      body: TechBackground(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: SingleChildScrollView(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(child: _BarHero()),
                        const SizedBox(width: 34),
                        Expanded(child: _GlassLoginCard(state: this, loading: state.loading)),
                      ],
                    )
                  : Column(
                      children: [
                        const _BarHero(compact: true),
                        const SizedBox(height: 20),
                        _GlassLoginCard(state: this, loading: state.loading),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
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

class _GlassLoginCard extends ConsumerWidget {
  const _GlassLoginCard({required this.state, required this.loading});

  final _LoginPageState state;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    const darkInk = Color(0xFF06111F);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(2.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
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
                blurRadius: 42,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: palette.secondary.withOpacity(0.22),
                blurRadius: 58,
                offset: const Offset(-12, 20),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: palette.surface.withOpacity(0.86),
              border: Border.all(color: palette.textPrimary.withOpacity(0.16)),
            ),
            child: Form(
              key: state._formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _WelcomeHeader(),
                  const SizedBox(height: 22),
                  const _AccessModeStrip(),
                  const SizedBox(height: 18),
                  _GlassTextField(
                    controller: state._identifier,
                    label: 'Usuario o correo',
                    hint: 'correo@barlytics.com',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.required,
                    onChanged: (_) {
                      if (state._loginErrorMessage != null) {
                        state.setState(() => state._loginErrorMessage = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  _GlassTextField(
                    controller: state._password,
                    label: 'Contraseña',
                    hint: 'Clave segura',
                    icon: Icons.lock_outline_rounded,
                    obscureText: state._hidePassword,
                    validator: Validators.required,
                    onChanged: (_) {
                      if (state._loginErrorMessage != null) {
                        state.setState(() => state._loginErrorMessage = null);
                      }
                    },
                    suffixIcon: IconButton(
                      onPressed: () => state.setState(() => state._hidePassword = !state._hidePassword),
                      icon: Icon(
                        state._hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: palette.textPrimary.withOpacity(0.78),
                      ),
                    ),
                  ),
                  if (state._loginErrorMessage != null) ...[
                    const SizedBox(height: 14),
                    _LoginAlert(message: state._loginErrorMessage!),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [palette.primary, palette.secondary, palette.accent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withOpacity(0.28),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
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
                            borderRadius: BorderRadius.circular(18),
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
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading ? null : () => context.go('/forgot-password'),
                    child: const Text('Olvidé mi contraseña'),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => showPaletteSettingsDialog(context),
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Personalizar colores'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.primary.withOpacity(0.30)),
                      backgroundColor: palette.textPrimary.withOpacity(0.055),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SecurityNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends ConsumerWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    const darkInk = Color(0xFF06111F);

    return Row(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [palette.primary, palette.secondary, palette.accent],
            ),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withOpacity(0.32),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.bar_chart_rounded, color: darkInk, size: 31),
              Positioned(
                right: 8,
                bottom: 7,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: darkInk,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_bar_rounded, size: 13, color: palette.accent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BarLytics',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tecnología para administrar tu bar en tiempo real',
                style: TextStyle(
                  color: palette.textPrimary.withOpacity(0.78),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccessModeStrip extends ConsumerWidget {
  const _AccessModeStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: palette.textPrimary.withOpacity(0.055),
        border: Border.all(color: palette.primary.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          const _MiniTechChip(icon: Icons.point_of_sale_rounded, label: 'Caja'),
          const SizedBox(width: 8),
          const _MiniTechChip(icon: Icons.table_bar_rounded, label: 'Mesas'),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Acceso inteligente',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.textPrimary.withOpacity(0.60),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTechChip extends ConsumerWidget {
  const _MiniTechChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: palette.primary.withOpacity(0.10),
        border: Border.all(color: palette.primary.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
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
    this.suffixIcon,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: palette.textPrimary.withOpacity(0.095),
        labelStyle: TextStyle(color: palette.textPrimary.withOpacity(0.82)),
        hintStyle: TextStyle(color: palette.textPrimary.withOpacity(0.38)),
        prefixIconColor: palette.primary,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.primary.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
      ),
    );
  }
}

class _BarHero extends ConsumerWidget {
  const _BarHero({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 30 : 44),
        color: palette.textPrimary.withOpacity(0.070),
        border: Border.all(color: palette.primary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withOpacity(0.11),
            blurRadius: 42,
            offset: const Offset(0, 20),
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
              size: compact ? 88 : 140,
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
                    size: compact ? 54 : 76,
                  ),
                  SizedBox(width: compact ? 10 : 14),
                  _BarAvatar(
                    icon: Icons.local_bar_rounded,
                    color: palette.secondary,
                    size: compact ? 54 : 76,
                  ),
                  SizedBox(width: compact ? 10 : 14),
                  _BarAvatar(
                    icon: Icons.wine_bar_rounded,
                    color: palette.accent,
                    size: compact ? 54 : 76,
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 30),
                Text(
                  'BarLytics para tu negocio',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1.04,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Una plataforma para administrar mesas, ventas, caja e inventario con una experiencia moderna y cercana.',
                  style: TextStyle(
                    color: palette.textPrimary.withOpacity(0.79),
                    height: 1.45,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeroChip(icon: Icons.point_of_sale_rounded, label: 'Ventas rápidas'),
                    _HeroChip(icon: Icons.memory_outlined, label: 'Bar Tech'),
                    _HeroChip(icon: Icons.inventory_2_outlined, label: 'Inventario inteligente'),
                    _HeroChip(icon: Icons.auto_graph_outlined, label: 'Gestión operativa'),
                  ],
                ),
                const SizedBox(height: 24),
                const _TelemetryPanel(),
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
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: palette.textPrimary.withOpacity(0.055),
        border: Border.all(color: palette.primary.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: palette.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryPanel extends ConsumerWidget {
  const _TelemetryPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: palette.surface.withOpacity(0.48),
        border: Border.all(color: palette.primary.withOpacity(0.16)),
      ),
      child: const Row(
        children: [
          Expanded(child: _TelemetryItem(label: 'Ventas', value: 'Live')),
          SizedBox(width: 12),
          Expanded(child: _TelemetryItem(label: 'Mesas', value: 'Smart')),
          SizedBox(width: 12),
          Expanded(child: _TelemetryItem(label: 'Inventario', value: 'Track')),
        ],
      ),
    );
  }
}

class _TelemetryItem extends ConsumerWidget {
  const _TelemetryItem({required this.label, required this.value});

  final String label;
  final String value;

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
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: palette.textPrimary.withOpacity(0.64),
            fontSize: 12,
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
  const _SecurityNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.primary.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: palette.primary.withOpacity(0.95),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Acceso seguro para meseros, cajeros y administración. JWT + roles + API protegida.',
              style: TextStyle(
                color: palette.textPrimary.withOpacity(0.76),
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
