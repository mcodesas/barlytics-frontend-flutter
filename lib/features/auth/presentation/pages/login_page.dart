import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController(text: 'admin@barlytics.com');
  final _password = TextEditingController(text: 'Admin123*');

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
      if (next.authenticated) context.go('/home');
      if (next.failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.failure!.message)));
      }
    });

    final isWide = MediaQuery.sizeOf(context).width >= 860;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF172554), Color(0xFF2563EB), Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Row(
                  children: [
                    if (isWide) const Expanded(child: _LoginHero()),
                    if (isWide) const SizedBox(width: 28),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(color: Colors.white.withOpacity(0.24)),
                        ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(26),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 58,
                                        height: 58,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(colors: [AppColors.accent, AppColors.tertiary]),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.local_bar_rounded, color: Colors.white, size: 30),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('BarLytics', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                                            const Text('Ingresa para continuar', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  AppTextField(
                                    controller: _identifier,
                                    label: 'Correo o identificador',
                                    prefixIcon: Icons.email_outlined,
                                    validator: Validators.required,
                                  ),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    controller: _password,
                                    label: 'Contraseña',
                                    prefixIcon: Icons.lock_outline_rounded,
                                    obscureText: true,
                                    validator: Validators.required,
                                  ),
                                  const SizedBox(height: 22),
                                  AppButton(
                                    label: 'Ingresar',
                                    icon: Icons.login_rounded,
                                    loading: state.loading,
                                    onPressed: () async {
                                      if (!_formKey.currentState!.validate()) return;
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
                      ),
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
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(999)),
              child: const Text('POS · Inventario · Ventas · Reportes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 24),
            const Text('Gestiona tu bar desde móvil, tablet o web.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 44, height: 1.05)),
            const SizedBox(height: 18),
            const Text('Una interfaz clara, colorida y sencilla para operar mesas, productos, inventario, ventas y pagos sin complicaciones.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 17, height: 1.45)),
            const SizedBox(height: 26),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _HeroPill(icon: Icons.table_restaurant_rounded, label: 'Mesas'),
                _HeroPill(icon: Icons.inventory_2_rounded, label: 'Inventario'),
                _HeroPill(icon: Icons.payments_rounded, label: 'Pagos'),
              ],
            ),
          ],
        ),
      );
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))]),
      );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(18)),
        child: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: AppColors.info),
            SizedBox(width: 10),
            Expanded(child: Text('Tu sesión se protege con token seguro y almacenamiento cifrado.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
