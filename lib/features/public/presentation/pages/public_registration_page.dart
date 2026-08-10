import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/public_site_config.dart';

class PublicRegistrationPage extends StatefulWidget {
  const PublicRegistrationPage({super.key});

  @override
  State<PublicRegistrationPage> createState() => _PublicRegistrationPageState();
}

class _PublicRegistrationPageState extends State<PublicRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String _businessType = 'Bar';

  AppPalette get _palette => appPalettes.first;

  @override
  void dispose() {
    _name.dispose();
    _business.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final number = PublicSiteConfig.whatsappNumber.trim();
    if (number.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura BARLYTICS_WHATSAPP para enviar solicitudes comerciales.')),
      );
      return;
    }

    final message = '''Hola, quiero solicitar información para usar BarLytics.

Nombre: ${_name.text.trim()}
Negocio: ${_business.text.trim()}
Tipo: $_businessType
Ciudad: ${_city.text.trim()}
Teléfono: ${_phone.text.trim()}
Correo: ${_email.text.trim()}

Quiero conocer planes, implementación y proceso de registro.''';

    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Theme(
      data: AppTheme.buildFromPalette(palette),
      child: Scaffold(
        backgroundColor: palette.background,
        body: Stack(
          children: [
            Positioned.fill(child: _RegistrationBackground(palette: palette)),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RegistrationTopBar(
                          palette: palette,
                          onHome: () => context.go('/'),
                          onLogin: () => context.go('/login'),
                        ),
                        const SizedBox(height: 26),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 820;
                            final brand = _RegistrationBrandPanel(palette: palette);
                            final form = _RegistrationFormPanel(
                              palette: palette,
                              formKey: _formKey,
                              name: _name,
                              business: _business,
                              city: _city,
                              phone: _phone,
                              email: _email,
                              businessType: _businessType,
                              onBusinessType: (value) => setState(() => _businessType = value),
                              onSubmit: _submit,
                            );
                            if (compact) {
                              return Column(children: [brand, const SizedBox(height: 16), form]);
                            }
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 10, child: brand),
                                  const SizedBox(width: 18),
                                  Expanded(flex: 11, child: form),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'El formulario prepara una solicitud comercial. La creación de empresas y usuarios continúa protegida dentro de BarLytics.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationBackground extends StatelessWidget {
  const _RegistrationBackground({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.55, -0.85),
          radius: 1.45,
          colors: [
            Color.lerp(const Color(0xFF155B66), palette.primary, 0.22)!,
            Color.lerp(const Color(0xFF082B3A), palette.secondary, 0.10)!,
            palette.background,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -100, right: -80, child: _RegistrationGlow(size: 300, color: palette.primary)),
          Positioned(bottom: -130, left: -90, child: _RegistrationGlow(size: 360, color: palette.secondary)),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.01, sigmaY: 0.01),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationGlow extends StatelessWidget {
  const _RegistrationGlow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withOpacity(0.15), Colors.transparent]),
        ),
      );
}

class _RegistrationTopBar extends StatelessWidget {
  const _RegistrationTopBar({required this.palette, required this.onHome, required this.onLogin});
  final AppPalette palette;
  final VoidCallback onHome;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: palette.panelDecoration(baseRadius: 20, tint: palette.secondary, elevated: false),
      child: Row(
        children: [
          InkWell(
            onTap: onHome,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [palette.primary, palette.secondary])),
                  child: const Icon(Icons.local_bar_rounded, color: Color(0xFF061723), size: 20),
                ),
                const SizedBox(width: 9),
                Text('BarLytics', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
          const Spacer(),
          TextButton.icon(onPressed: onHome, icon: const Icon(Icons.arrow_back_rounded), label: const Text('Volver')), 
          const SizedBox(width: 5),
          OutlinedButton.icon(onPressed: onLogin, icon: const Icon(Icons.login_rounded), label: const Text('Iniciar sesión')),
        ],
      ),
    );
  }
}

class _RegistrationBrandPanel extends StatelessWidget {
  const _RegistrationBrandPanel({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primary.withOpacity(0.14), palette.surface.withOpacity(0.92), palette.secondary.withOpacity(0.12)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.translucentBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.26), blurRadius: 34, offset: const Offset(0, 17))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
              boxShadow: [BoxShadow(color: palette.secondary.withOpacity(0.24), blurRadius: 22, offset: const Offset(0, 9))],
            ),
            child: const Icon(Icons.local_bar_rounded, color: Color(0xFF061723), size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            'Conoce BarLytics en tu negocio.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900, height: 1.08),
          ),
          const SizedBox(height: 12),
          Text(
            'Déjanos los datos básicos del bar o gastrobar y podrás continuar la conversación por WhatsApp con la información ya organizada.',
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.55, fontSize: 13.5),
          ),
          const SizedBox(height: 24),
          const _RegistrationBenefit(icon: Icons.point_of_sale_rounded, title: 'Ventas y caja', text: 'Mesas, venta rápida, cobros y múltiples medios.'),
          const SizedBox(height: 11),
          const _RegistrationBenefit(icon: Icons.inventory_2_rounded, title: 'Inventario', text: 'Stock, movimientos, conteos y pedidos.'),
          const SizedBox(height: 11),
          const _RegistrationBenefit(icon: Icons.insights_rounded, title: 'Información', text: 'Reportes y control por empresa y sucursal.'),
        ],
      ),
    );
  }
}

class _RegistrationBenefit extends StatelessWidget {
  const _RegistrationBenefit({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = appPalettes.first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.11), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: palette.secondary, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5)), const SizedBox(height: 2), Text(text, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.35, fontSize: 11))])),
      ],
    );
  }
}

class _RegistrationFormPanel extends StatelessWidget {
  const _RegistrationFormPanel({
    required this.palette,
    required this.formKey,
    required this.name,
    required this.business,
    required this.city,
    required this.phone,
    required this.email,
    required this.businessType,
    required this.onBusinessType,
    required this.onSubmit,
  });

  final AppPalette palette;
  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController business;
  final TextEditingController city;
  final TextEditingController phone;
  final TextEditingController email;
  final String businessType;
  final ValueChanged<String> onBusinessType;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: palette.panelDecoration(baseRadius: 30, tint: palette.secondary, elevated: true),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Solicitud de registro', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Cuéntanos quién eres y qué tipo de negocio deseas administrar con BarLytics.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.45)),
            const SizedBox(height: 20),
            _RegistrationField(controller: name, label: 'Tu nombre', icon: Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _RegistrationField(controller: business, label: 'Nombre del negocio', icon: Icons.storefront_outlined),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: businessType,
              decoration: const InputDecoration(labelText: 'Tipo de negocio', prefixIcon: Icon(Icons.local_bar_outlined)),
              items: const ['Bar', 'Gastrobar', 'Restaurante / bar', 'Discoteca', 'Otro'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(growable: false),
              onChanged: (value) {
                if (value != null) onBusinessType(value);
              },
            ),
            const SizedBox(height: 12),
            _RegistrationField(controller: city, label: 'Ciudad', icon: Icons.location_city_outlined),
            const SizedBox(height: 12),
            _RegistrationField(controller: phone, label: 'Teléfono / WhatsApp', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _RegistrationField(controller: email, label: 'Correo', icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress, email: true),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: palette.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(15), border: Border.all(color: palette.primary.withOpacity(0.13))),
              child: Row(children: [Icon(Icons.info_outline_rounded, color: palette.primary, size: 19), const SizedBox(width: 9), Expanded(child: Text('No se crea una cuenta administrativa desde esta página. La solicitud inicia el contacto comercial de forma segura.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, height: 1.35, fontSize: 11)))]),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.chat_rounded),
                label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Enviar solicitud por WhatsApp')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationField extends StatelessWidget {
  const _RegistrationField({required this.controller, required this.label, required this.icon, this.keyboardType, this.email = false});
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool email;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        final text = (value ?? '').trim();
        if (text.isEmpty) return 'Completa este campo';
        if (email && (!text.contains('@') || !text.contains('.'))) return 'Ingresa un correo válido';
        return null;
      },
    );
  }
}
