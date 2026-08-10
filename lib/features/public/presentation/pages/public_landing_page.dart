import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/public_site_config.dart';
import '../widgets/public_product_demo.dart';

class PublicLandingPage extends StatefulWidget {
  const PublicLandingPage({super.key});

  @override
  State<PublicLandingPage> createState() => _PublicLandingPageState();
}

class _PublicLandingPageState extends State<PublicLandingPage> {
  final _inicioKey = GlobalKey();
  final _demoKey = GlobalKey();
  final _funcionesKey = GlobalKey();
  final _responsiveKey = GlobalKey();
  final _comoKey = GlobalKey();
  final _nosotrosKey = GlobalKey();
  final _planesKey = GlobalKey();
  final _descargasKey = GlobalKey();
  final _contactoKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  String _activeSection = 'inicio';
  bool _scrollSpyScheduled = false;

  AppPalette get _palette => appPalettes.first;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scheduleScrollSpy);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateActiveSection());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_scheduleScrollSpy)
      ..dispose();
    super.dispose();
  }

  void _scheduleScrollSpy() {
    if (_scrollSpyScheduled) return;
    _scrollSpyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollSpyScheduled = false;
      _updateActiveSection();
    });
  }

  void _updateActiveSection() {
    if (!mounted) return;
    const activationLine = 118.0;
    final sections = <(String, GlobalKey)>[
      ('inicio', _inicioKey),
      ('demo', _demoKey),
      ('funciones', _funcionesKey),
      ('nosotros', _nosotrosKey),
      ('planes', _planesKey),
      ('descargas', _descargasKey),
    ];

    var nextActive = 'inicio';
    for (final section in sections) {
      final context = section.$2.currentContext;
      if (context == null) continue;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      if (top <= activationLine) {
        nextActive = section.$1;
      } else {
        break;
      }
    }

    if (nextActive != _activeSection) {
      setState(() => _activeSection = nextActive);
    }
  }

  String _sectionForKey(GlobalKey key) {
    if (identical(key, _demoKey)) return 'demo';
    if (identical(key, _funcionesKey)) return 'funciones';
    if (identical(key, _nosotrosKey)) return 'nosotros';
    if (identical(key, _planesKey)) return 'planes';
    if (identical(key, _descargasKey)) return 'descargas';
    return 'inicio';
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) return;
    final section = _sectionForKey(key);
    if (_activeSection != section) {
      setState(() => _activeSection = section);
    }
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
    _scheduleScrollSpy();
  }

  Future<void> _openWhatsApp({String? message}) async {
    final number = PublicSiteConfig.whatsappNumber.trim();
    if (number.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Configura BARLYTICS_WHATSAPP para activar el contacto comercial.'),
          ),
        );
      return;
    }
    final text = message ?? 'Hola, quiero conocer más sobre BarLytics para mi negocio.';
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _download(String platform) async {
    final url = PublicSiteConfig.downloadUrlFor(platform).trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('La descarga para $platform estará disponible próximamente.')));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Theme(
      data: AppTheme.buildFromPalette(palette),
      child: Scaffold(
        backgroundColor: palette.background,
        floatingActionButton: _WhatsAppFloatingButton(
          palette: palette,
          onTap: () => _openWhatsApp(),
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _PublicBackground(palette: palette)),
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  toolbarHeight: 76,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  titleSpacing: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          palette.background.withOpacity(0.97),
                          Color.lerp(palette.background, palette.surface, 0.34)!.withOpacity(0.95),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(color: palette.secondary.withOpacity(0.16)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: _PublicNavigation(
                              palette: palette,
                              activeSection: _activeSection,
                              onInicio: () => _scrollTo(_inicioKey),
                              onDemo: () => _scrollTo(_demoKey),
                              onFunciones: () => _scrollTo(_funcionesKey),
                              onPlanes: () => _scrollTo(_planesKey),
                              onNosotros: () => _scrollTo(_nosotrosKey),
                              onDescargas: () => _scrollTo(_descargasKey),
                              onLogin: () => context.go('/login'),
                              onRegister: () => context.go('/registro'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _HeroSection(
                        key: _inicioKey,
                        palette: palette,
                        onDemo: () => _scrollTo(_demoKey),
                        onRegister: () => context.go('/registro'),
                        onLogin: () => context.go('/login'),
                      ),
                      _ProofStrip(palette: palette),
                      _PublicSection(
                        key: _demoKey,
                        palette: palette,
                        eyebrow: 'MIRA EL PRODUCTO REAL',
                        title: 'BarLytics dentro de la página, sin imitaciones',
                        subtitle:
                            'Selecciona un módulo y cambia entre escritorio, tablet y celular. Cada espacio está preparado para reproducir un GIF capturado directamente desde BarLytics, por eso lo que vea el cliente será exactamente lo que existe en el aplicativo.',
                        maxWidth: 1220,
                        child: const PublicProductDemo(),
                      ),
                      _PublicSection(
                        key: _responsiveKey,
                        palette: palette,
                        eyebrow: 'EL MISMO PRODUCTO EN CADA EQUIPO',
                        title: 'Escritorio, tablet y celular con la interfaz real',
                        subtitle:
                            'La galería usa grabaciones separadas por dispositivo para enseñar la experiencia verdadera de BarLytics, sin redibujar las pantallas ni alterar sus colores, transparencias o proporciones.',
                        maxWidth: 1180,
                        child: const PublicResponsivePreviewGallery(),
                      ),
                      _PublicSection(
                        key: _funcionesKey,
                        palette: palette,
                        eyebrow: 'OPERACIÓN COMPLETA',
                        title: 'Todo lo que necesitas para controlar el bar',
                        subtitle:
                            'Las funciones principales comparten la misma identidad visual, reglas de seguridad y contexto por empresa y sucursal.',
                        maxWidth: 1180,
                        child: _FeatureGrid(palette: palette),
                      ),
                      _WorkflowBand(key: _comoKey, palette: palette),
                      _SecuritySection(palette: palette),
                      _PublicSection(
                        key: _nosotrosKey,
                        palette: palette,
                        eyebrow: 'ACERCA DE NOSOTROS',
                        title: 'Tecnología pensada para operar con confianza',
                        subtitle:
                            'BarLytics busca que administrar un bar sea más claro, trazable y seguro, sin obligar al equipo a aprender procesos complicados.',
                        maxWidth: 1120,
                        child: _AboutSection(palette: palette),
                      ),
                      _PublicSection(
                        key: _planesKey,
                        palette: palette,
                        eyebrow: 'PLANES CLAROS PARA CADA ETAPA',
                        title: 'Elige el nivel de BarLytics que necesita tu negocio',
                        subtitle:
                            'Empieza con lo esencial, crece con más control y administra varias sedes cuando tu operación lo requiera.',
                        maxWidth: 1180,
                        child: _PlansSection(
                          palette: palette,
                          onRegister: () => context.go('/registro'),
                          onWhatsApp: () => _openWhatsApp(message: 'Hola, quiero información sobre los planes de BarLytics.'),
                        ),
                      ),
                      _PublicSection(
                        key: _descargasKey,
                        palette: palette,
                        eyebrow: 'BARLYTICS DONDE LO NECESITES',
                        title: 'Descarga la aplicación',
                        subtitle:
                            'Los instaladores se publican por plataforma. Cuando un paquete todavía no esté disponible, la web lo indicará sin abrir enlaces rotos.',
                        maxWidth: 1120,
                        child: _DownloadsSection(palette: palette, onDownload: _download),
                      ),
                      _ContactSection(
                        key: _contactoKey,
                        palette: palette,
                        onWhatsApp: () => _openWhatsApp(),
                        onRegister: () => context.go('/registro'),
                        onLogin: () => context.go('/login'),
                      ),
                      _Footer(palette: palette),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicBackground extends StatelessWidget {
  const _PublicBackground({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.48, -0.86),
          radius: 1.5,
          colors: [
            Color.lerp(const Color(0xFF155B66), palette.primary, 0.20)!,
            Color.lerp(const Color(0xFF082B3A), palette.secondary, 0.08)!,
            palette.background,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -120,
            child: _Glow(size: 430, color: palette.primary, opacity: 0.18),
          ),
          Positioned(
            top: 560,
            left: -180,
            child: _Glow(size: 520, color: palette.secondary, opacity: 0.13),
          ),
          Positioned(
            bottom: 300,
            right: -180,
            child: _Glow(size: 480, color: palette.primary, opacity: 0.10),
          ),
          Positioned.fill(child: CustomPaint(painter: _PublicPatternPainter(palette))),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.opacity});
  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withOpacity(opacity), Colors.transparent]),
        ),
      );
}

class _PublicPatternPainter extends CustomPainter {
  const _PublicPatternPainter(this.palette);
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final dots = Paint()..color = Colors.white.withOpacity(0.034);
    for (double x = 30; x < size.width; x += 42) {
      for (double y = 34; y < size.height; y += 42) {
        canvas.drawCircle(Offset(x, y), 1, dots);
      }
    }

    final line = Paint()
      ..color = palette.secondary.withOpacity(0.055)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    for (double y = 230; y < size.height; y += 620) {
      final path = Path()
        ..moveTo(size.width * 0.06, y)
        ..lineTo(size.width * 0.23, y)
        ..lineTo(size.width * 0.31, y + 44)
        ..lineTo(size.width * 0.47, y + 44);
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(covariant _PublicPatternPainter oldDelegate) => oldDelegate.palette != palette;
}

class _PublicNavigation extends StatelessWidget {
  const _PublicNavigation({
    required this.palette,
    required this.activeSection,
    required this.onInicio,
    required this.onDemo,
    required this.onFunciones,
    required this.onPlanes,
    required this.onNosotros,
    required this.onDescargas,
    required this.onLogin,
    required this.onRegister,
  });

  final AppPalette palette;
  final String activeSection;
  final VoidCallback onInicio;
  final VoidCallback onDemo;
  final VoidCallback onFunciones;
  final VoidCallback onPlanes;
  final VoidCallback onNosotros;
  final VoidCallback onDescargas;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1100;
        return SizedBox(
          height: 76,
          child: Row(
            children: [
              _BrandNavButton(palette: palette, active: activeSection == 'inicio', onTap: onInicio),
              const Spacer(),
              if (!compact) ...[
                _TopNavButton(palette: palette, label: 'Demo', active: activeSection == 'demo', onTap: onDemo),
                _TopNavButton(palette: palette, label: 'Funciones', active: activeSection == 'funciones', onTap: onFunciones),
                _TopNavButton(palette: palette, label: 'Planes', active: activeSection == 'planes', onTap: onPlanes),
                _TopNavButton(palette: palette, label: 'Nosotros', active: activeSection == 'nosotros', onTap: onNosotros),
                _TopNavButton(palette: palette, label: 'Descargas', active: activeSection == 'descargas', onTap: onDescargas),
                const SizedBox(width: 18),
                Container(width: 1, height: 26, color: palette.translucentBorder.withOpacity(0.70)),
                const SizedBox(width: 18),
                _NavLoginButton(palette: palette, onTap: onLogin),
                const SizedBox(width: 10),
                _NavRegisterButton(palette: palette, onTap: onRegister),
              ] else
                _CompactNavMenu(
                  palette: palette,
                  activeSection: activeSection,
                  onDemo: onDemo,
                  onFunciones: onFunciones,
                  onPlanes: onPlanes,
                  onNosotros: onNosotros,
                  onDescargas: onDescargas,
                  onLogin: onLogin,
                  onRegister: onRegister,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandNavButton extends StatefulWidget {
  const _BrandNavButton({required this.palette, required this.active, required this.onTap});
  final AppPalette palette;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_BrandNavButton> createState() => _BrandNavButtonState();
}

class _BrandNavButtonState extends State<_BrandNavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [palette.primary, palette.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.secondary.withOpacity(_hovered || widget.active ? 0.30 : 0.17),
                      blurRadius: _hovered || widget.active ? 20 : 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_bar_rounded, color: Color(0xFF061723), size: 22),
              ),
              const SizedBox(width: 11),
              Text(
                'BarLytics',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: -0.65,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(left: 7, top: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hovered || widget.active ? palette.primary : palette.secondary.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopNavButton extends StatefulWidget {
  const _TopNavButton({
    required this.palette,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final AppPalette palette;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_TopNavButton> createState() => _TopNavButtonState();
}

class _TopNavButtonState extends State<_TopNavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final highlighted = _hovered || widget.active;
    final foreground = highlighted ? palette.textPrimary : palette.textSecondary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 9),
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 7),
          decoration: BoxDecoration(
            color: widget.active
                ? palette.secondary.withOpacity(0.075)
                : (_hovered ? palette.surface.withOpacity(0.24) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: widget.active ? FontWeight.w900 : FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.05,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: highlighted ? (widget.active ? 30 : 24) : 0,
                height: widget.active ? 2.5 : 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                  boxShadow: widget.active
                      ? [BoxShadow(color: palette.secondary.withOpacity(0.25), blurRadius: 8)]
                      : const [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLoginButton extends StatefulWidget {
  const _NavLoginButton({required this.palette, required this.onTap});
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  State<_NavLoginButton> createState() => _NavLoginButtonState();
}

class _NavLoginButtonState extends State<_NavLoginButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: OutlinedButton(
        onPressed: widget.onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          backgroundColor: _hovered ? palette.surface.withOpacity(0.55) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          side: BorderSide(
            color: _hovered ? palette.secondary.withOpacity(0.38) : palette.translucentBorder.withOpacity(0.78),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        child: const Text('Ingresar'),
      ),
    );
  }
}

class _NavRegisterButton extends StatelessWidget {
  const _NavRegisterButton({required this.palette, required this.onTap});
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
        boxShadow: [
          BoxShadow(color: palette.secondary.withOpacity(0.22), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF061723),
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Registrarse'),
            SizedBox(width: 7),
            Icon(Icons.arrow_forward_rounded, size: 17),
          ],
        ),
      ),
    );
  }
}

class _CompactNavMenu extends StatelessWidget {
  const _CompactNavMenu({
    required this.palette,
    required this.activeSection,
    required this.onDemo,
    required this.onFunciones,
    required this.onPlanes,
    required this.onNosotros,
    required this.onDescargas,
    required this.onLogin,
    required this.onRegister,
  });

  final AppPalette palette;
  final String activeSection;
  final VoidCallback onDemo;
  final VoidCallback onFunciones;
  final VoidCallback onPlanes;
  final VoidCallback onNosotros;
  final VoidCallback onDescargas;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.translucentBorder.withOpacity(0.82)),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Menú',
        color: palette.surface,
        elevation: 18,
        position: PopupMenuPosition.under,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.menu_rounded, color: palette.textPrimary, size: 22),
            if (activeSection != 'inicio')
              Positioned(
                right: -4,
                top: -3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: palette.primary),
                ),
              ),
          ],
        ),
        onSelected: (value) {
          switch (value) {
            case 'demo': onDemo(); break;
            case 'funciones': onFunciones(); break;
            case 'planes': onPlanes(); break;
            case 'nosotros': onNosotros(); break;
            case 'descargas': onDescargas(); break;
            case 'login': onLogin(); break;
            case 'registro': onRegister(); break;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'demo', child: _PopupNavItem(icon: Icons.play_circle_outline_rounded, label: 'Demo interactiva', active: activeSection == 'demo', accent: palette.primary)),
          PopupMenuItem(value: 'funciones', child: _PopupNavItem(icon: Icons.grid_view_rounded, label: 'Funciones', active: activeSection == 'funciones', accent: palette.primary)),
          PopupMenuItem(value: 'planes', child: _PopupNavItem(icon: Icons.workspace_premium_rounded, label: 'Planes y precios', active: activeSection == 'planes', accent: palette.primary)),
          PopupMenuItem(value: 'nosotros', child: _PopupNavItem(icon: Icons.apartment_rounded, label: 'Nosotros', active: activeSection == 'nosotros', accent: palette.primary)),
          PopupMenuItem(value: 'descargas', child: _PopupNavItem(icon: Icons.download_rounded, label: 'Descargas', active: activeSection == 'descargas', accent: palette.primary)),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'login', child: _PopupNavItem(icon: Icons.login_rounded, label: 'Iniciar sesión')),
          PopupMenuItem(
            value: 'registro',
            child: _PopupNavItem(icon: Icons.arrow_forward_rounded, label: 'Registrarse', accent: palette.primary),
          ),
        ],
      ),
    );
  }
}

class _PopupNavItem extends StatelessWidget {
  const _PopupNavItem({required this.icon, required this.label, this.accent, this.active = false});
  final IconData icon;
  final String label;
  final Color? accent;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    final color = active ? (accent ?? base) : base;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: active ? FontWeight.w900 : FontWeight.w700),
          ),
        ),
        if (active) ...[
          const SizedBox(width: 8),
          Icon(Icons.check_circle_rounded, size: 16, color: accent ?? color),
        ],
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    super.key,
    required this.palette,
    required this.onDemo,
    required this.onRegister,
    required this.onLogin,
  });

  final AppPalette palette;
  final VoidCallback onDemo;
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 76, 20, 58),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 900;
              final copy = Column(
                crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  _Eyebrow(palette: palette, icon: Icons.auto_awesome_rounded, text: 'SOFTWARE PARA BARES Y GASTROBARES'),
                  const SizedBox(height: 20),
                  Text(
                    'Controla tu bar con una experiencia que el equipo sí quiere usar.',
                    textAlign: compact ? TextAlign.center : TextAlign.left,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.02,
                          letterSpacing: -1.7,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Ventas, mesas, cobros, productos, inventario, reportes, usuarios y sucursales conectados en una plataforma responsive con identidad visual consistente.',
                    textAlign: compact ? TextAlign.center : TextAlign.left,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: palette.textSecondary,
                          height: 1.52,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    alignment: compact ? WrapAlignment.center : WrapAlignment.start,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: onDemo,
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: const Padding(padding: EdgeInsets.symmetric(vertical: 11), child: Text('Probar BarLytics aquí')),
                      ),
                      OutlinedButton.icon(
                        onPressed: onRegister,
                        icon: const Icon(Icons.rocket_launch_rounded),
                        label: const Padding(padding: EdgeInsets.symmetric(vertical: 11), child: Text('Quiero registrarme')),
                      ),
                      TextButton.icon(onPressed: onLogin, icon: const Icon(Icons.login_rounded), label: const Text('Ya tengo cuenta')),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    alignment: compact ? WrapAlignment.center : WrapAlignment.start,
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      _HeroTrustChip(palette: palette, icon: Icons.security_rounded, label: 'Roles y permisos'),
                      _HeroTrustChip(palette: palette, icon: Icons.store_mall_directory_rounded, label: 'Multi-sucursal'),
                      _HeroTrustChip(palette: palette, icon: Icons.devices_rounded, label: 'Web · móvil · escritorio'),
                    ],
                  ),
                ],
              );
              const preview = PublicHeroDemoPreview();
              if (compact) {
                return Column(children: [copy, const SizedBox(height: 40), preview]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 10, child: copy),
                  const SizedBox(width: 42),
                  Expanded(flex: 11, child: preview),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.palette, required this.icon, required this.text});
  final AppPalette palette;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.secondary.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: palette.secondary, size: 15),
          const SizedBox(width: 7),
          Text(text, style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.55)),
        ],
      ),
    );
  }
}

class _HeroTrustChip extends StatelessWidget {
  const _HeroTrustChip({required this.palette, required this.icon, required this.label});
  final AppPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: palette.glassSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.cardBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: palette.primary, size: 15), const SizedBox(width: 6), Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 10.5))]),
    );
  }
}

class _HeroProductPreview extends StatelessWidget {
  const _HeroProductPreview({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.15,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: palette.panelGradient(tint: palette.secondary),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: palette.translucentBorder),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 38, offset: const Offset(0, 20))],
              ),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: palette.surface.withOpacity(0.92), borderRadius: BorderRadius.circular(23), border: Border.all(color: palette.cardBorder)),
                child: Column(
                  children: [
                    Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(gradient: LinearGradient(colors: [palette.primary, palette.secondary]), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.local_bar_rounded, color: Color(0xFF061723), size: 18)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Mesas y caja', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 11)), Text('Sucursal Centro', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 8))])), _StatusDot(palette: palette)]),
                    const SizedBox(height: 10),
                    Container(height: 42, decoration: BoxDecoration(color: palette.background.withOpacity(0.48), borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.cardBorder)), child: Row(children: [for (final item in const [('6', 'Mesas'), ('3', 'Ocupadas'), ('3', 'Libres'), (r'$152k', 'Pendiente')]) Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(item.$1, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 9)), Text(item.$2, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 6.5))]))])),
                    const SizedBox(height: 9),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 7, mainAxisSpacing: 7, childAspectRatio: 1.18),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          final occupied = index == 1 || index == 3 || index == 4;
                          final accent = occupied ? palette.secondary : palette.primary;
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Color.lerp(palette.surface, accent, occupied ? 0.10 : 0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withOpacity(occupied ? 0.30 : 0.16))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('${index + 1}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 8))), const Spacer(), Container(width: 6, height: 6, decoration: BoxDecoration(color: accent, shape: BoxShape.circle))]), const Spacer(), Text('Mesa ${index + 1}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 7.5)), Text(occupied ? (index == 3 ? r'$72.500' : r'$48.500') : 'Libre', style: TextStyle(color: occupied ? palette.secondary : palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 6.5))]),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -16,
            bottom: -22,
            child: Container(
              width: 142,
              height: 250,
              padding: const EdgeInsets.fromLTRB(8, 15, 8, 8),
              decoration: BoxDecoration(color: palette.background, borderRadius: BorderRadius.circular(28), border: Border.all(color: palette.translucentBorder, width: 1.2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.34), blurRadius: 28, offset: const Offset(0, 14))]),
              child: Column(children: [Container(width: 48, height: 10, decoration: BoxDecoration(color: Colors.black.withOpacity(0.40), borderRadius: BorderRadius.circular(99))), const SizedBox(height: 11), Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: palette.cardBorder)), child: Row(children: [Icon(Icons.bolt_rounded, color: palette.secondary, size: 13), const SizedBox(width: 5), Text('Venta rápida', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 7.5))])), const SizedBox(height: 7), Container(height: 42, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: palette.cardBorder)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tu venta', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 7)), Text('3 productos', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 5.5))])), Text(r'$25.500', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 7.5))])), const SizedBox(height: 7), Expanded(child: Column(children: [for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.only(bottom: 5), child: Container(height: 34, decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(9), border: Border.all(color: palette.cardBorder)), child: Row(children: [const SizedBox(width: 6), Container(width: 22, height: 22, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(7)), child: Icon(Icons.local_bar_rounded, size: 11, color: palette.secondary)), const SizedBox(width: 5), Expanded(child: Text(i == 0 ? 'Club Colombia' : i == 1 ? 'Corona' : 'Agua', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 5.8))), Icon(Icons.add_circle_rounded, color: palette.secondary, size: 12), const SizedBox(width: 5)])))])), Container(height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: palette.actionColor, borderRadius: BorderRadius.circular(10)), child: Text('Cobrar', style: TextStyle(color: palette.onAction, fontWeight: FontWeight.w900, fontSize: 7.5)))]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), decoration: BoxDecoration(color: palette.success.withOpacity(0.09), borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.success.withOpacity(0.16))), child: Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: palette.success, shape: BoxShape.circle)), const SizedBox(width: 4), Text('EN LÍNEA', style: TextStyle(color: palette.success, fontWeight: FontWeight.w900, fontSize: 6.5))]));
}

class _ProofStrip extends StatelessWidget {
  const _ProofStrip({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.point_of_sale_rounded, 'Venta directa y mesas'),
      (Icons.inventory_2_rounded, 'Inventario trazable'),
      (Icons.payments_rounded, 'Cobros y múltiples medios'),
      (Icons.insights_rounded, 'Reportes operativos'),
      (Icons.admin_panel_settings_rounded, 'Roles personalizados'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: palette.panelDecoration(baseRadius: 20, tint: palette.secondary, elevated: false),
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 14,
              runSpacing: 12,
              children: [
                for (final item in items)
                  Row(mainAxisSize: MainAxisSize.min, children: [Icon(item.$1, size: 17, color: palette.secondary), const SizedBox(width: 7), Text(item.$2, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 10.5))]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicSection extends StatelessWidget {
  const _PublicSection({
    super.key,
    required this.palette,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxWidth = 1160,
  });

  final AppPalette palette;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              Text(eyebrow, textAlign: TextAlign.center, style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.85)),
              const SizedBox(height: 10),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900, height: 1.08, letterSpacing: -0.7)),
              const SizedBox(height: 12),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: palette.textSecondary, height: 1.55, fontWeight: FontWeight.w600))),
              const SizedBox(height: 32),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    const features = <(IconData, String, String)>[
      (Icons.table_bar_rounded, 'Mesas y venta rápida', 'Opera con mesas o cobra directamente en mostrador sin crear una mesa.'),
      (Icons.point_of_sale_rounded, 'Cobro POS', 'Efectivo, tarjeta, transferencias, múltiples pagos, propina y cálculo de vuelta.'),
      (Icons.inventory_2_rounded, 'Inventario', 'Conteos, stock mínimo/máximo, movimientos, pedidos y alertas por sucursal.'),
      (Icons.sell_rounded, 'Productos y precios', 'Compra, venta, historial de precios y administración centralizada del catálogo.'),
      (Icons.insights_rounded, 'Reportes', 'Ventas, ganancias, productos, medios de pago y operación por periodos.'),
      (Icons.admin_panel_settings_rounded, 'Roles personalizados', 'Define exactamente qué opciones puede usar cada perfil y en qué orden.'),
      (Icons.store_mall_directory_rounded, 'Multiempresa y sucursales', 'Contexto separado por negocio y sede para crecer sin mezclar información.'),
      (Icons.security_rounded, 'Control y trazabilidad', 'Sesiones, permisos, historial y reglas para proteger la operación.'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620 ? 1 : constraints.maxWidth < 960 ? 2 : 4;
        const gap = 14.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in features)
              SizedBox(width: width, child: _FeatureCard(palette: palette, icon: item.$1, title: item.$2, description: item.$3)),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.palette, required this.icon, required this.title, required this.description});
  final AppPalette palette;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.secondary, elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(15), border: Border.all(color: palette.secondary.withOpacity(0.15))), child: Icon(icon, color: palette.secondary, size: 23)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 7),
          Text(description, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.45, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _WorkflowBand extends StatelessWidget {
  const _WorkflowBand({super.key, required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    const steps = <(String, IconData, String)>[
      ('01', Icons.login_rounded, 'El equipo ingresa con su rol y sucursal autorizada.'),
      ('02', Icons.point_of_sale_rounded, 'Registra ventas, pagos, inventario y operación diaria.'),
      ('03', Icons.sync_alt_rounded, 'BarLytics mantiene cuentas, stock y trazabilidad conectados.'),
      ('04', Icons.insights_rounded, 'Gerencia consulta resultados y toma decisiones con información actualizada.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 82, 20, 34),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette.primary.withOpacity(0.10), palette.surface.withOpacity(0.92), palette.secondary.withOpacity(0.10)]),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: palette.translucentBorder),
            ),
            child: Column(
              children: [
                Text('UN FLUJO CONECTADO', style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8)),
                const SizedBox(height: 9),
                Text('Desde el turno hasta la decisión', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final vertical = constraints.maxWidth < 760;
                    final cards = [for (final step in steps) _WorkflowStep(palette: palette, number: step.$1, icon: step.$2, text: step.$3)];
                    if (vertical) {
                      return Column(children: [for (var index = 0; index < cards.length; index++) ...[cards[index], if (index != cards.length - 1) const SizedBox(height: 10)]]);
                    }
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var index = 0; index < cards.length; index++) ...[Expanded(child: cards[index]), if (index != cards.length - 1) Padding(padding: const EdgeInsets.only(top: 34), child: Icon(Icons.arrow_forward_rounded, color: palette.secondary.withOpacity(0.45), size: 20))]]);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({required this.palette, required this.number, required this.icon, required this.text});
  final AppPalette palette;
  final String number;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.11), borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.secondary.withOpacity(0.18))), child: Stack(children: [Center(child: Icon(icon, color: palette.secondary, size: 25)), Positioned(top: 5, right: 6, child: Text(number, style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900, fontSize: 7.5)))])),
          const SizedBox(height: 11),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, height: 1.4, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Eyebrow(palette: palette, icon: Icons.verified_user_rounded, text: 'CONTROL E INTEGRIDAD'),
                  const SizedBox(height: 15),
                  Text('La confianza también se diseña.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text('BarLytics separa contextos por empresa y sucursal, maneja roles y permisos, conserva trazabilidad de precios, pagos y movimientos, y protege operaciones históricas.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.55, fontSize: 13.5)),
                ],
              );
              final grid = _SecurityGrid(palette: palette);
              if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 24), grid]);
              return Row(children: [Expanded(child: copy), const SizedBox(width: 42), Expanded(child: grid)]);
            },
          ),
        ),
      ),
    );
  }
}

class _SecurityGrid extends StatelessWidget {
  const _SecurityGrid({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.admin_panel_settings_rounded, 'Permisos por rol'),
      (Icons.store_rounded, 'Contexto por sucursal'),
      (Icons.history_rounded, 'Historial y trazabilidad'),
      (Icons.lock_clock_rounded, 'Sesiones protegidas'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          SizedBox(
            width: 190,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: palette.panelDecoration(baseRadius: 18, tint: palette.primary, elevated: false),
              child: Row(children: [Icon(item.$1, color: palette.primary, size: 21), const SizedBox(width: 9), Expanded(child: Text(item.$2, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 11.5)))]),
            ),
          ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final values = const [
      (Icons.shield_outlined, 'Integridad', 'La información debe conservar sentido y trazabilidad en cada operación.'),
      (Icons.speed_rounded, 'Simplicidad', 'La tecnología debe acelerar el trabajo del equipo, no agregar pasos innecesarios.'),
      (Icons.visibility_rounded, 'Control', 'Cada rol ve lo que necesita y la gerencia mantiene visibilidad de la operación.'),
      (Icons.devices_rounded, 'Accesibilidad', 'La misma experiencia se adapta a web, escritorio, tablet y móvil.'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700 ? 1 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final value in values) SizedBox(width: width, child: Container(padding: const EdgeInsets.all(18), decoration: palette.panelDecoration(baseRadius: 22, tint: palette.primary, elevated: false), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: palette.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(14)), child: Icon(value.$1, color: palette.primary, size: 21)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value.$2, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(height: 5), Text(value.$3, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.4, fontSize: 12))]))])))]);
      },
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.palette,
    required this.onRegister,
    required this.onWhatsApp,
  });

  final AppPalette palette;
  final VoidCallback onRegister;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final plans = <_PlanData>[
      const _PlanData(
        name: 'Inicial',
        price: r'$40.000',
        period: 'COP / mes',
        description: 'Para bares que quieren empezar a controlar la operación sin complicarse.',
        features: [
          '1 sucursal',
          'Hasta 3 usuarios',
          'Ventas, mesas y venta directa',
          'Productos y precios',
          'Inventario y movimientos',
          'Reportes esenciales',
        ],
      ),
      const _PlanData(
        name: 'BarLytics Pro',
        price: r'$70.000',
        period: 'COP / mes',
        description: 'El plan recomendado para un bar en operación que necesita más control y trazabilidad.',
        recommended: true,
        features: [
          '1 sucursal',
          'Hasta 5 usuarios',
          'Todo lo del plan Inicial',
          'Cobro POS y múltiples medios',
          'Roles personalizados',
          'Reportes operativos y ganancias',
          'Historial de precios y movimientos',
        ],
      ),
      const _PlanData(
        name: 'Multi-sucursal',
        price: 'Cotizar',
        period: 'según operación',
        description: 'Para empresas con varias sedes que necesitan administración central y separación por sucursal.',
        enterprise: true,
        features: [
          'Varias sucursales',
          'Administración centralizada',
          'Gerentes y permisos por sede',
          'Sincronización de productos entre sucursales',
          'Control por empresa y sucursal',
          'Acompañamiento para configuración',
        ],
      ),
    ];

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 760 ? 1 : 3;
            const gap = 16.0;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (final plan in plans)
                  SizedBox(
                    width: width,
                    child: _PlanCard(
                      palette: palette,
                      plan: plan,
                      onTap: plan.enterprise ? onWhatsApp : onRegister,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(0.50),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.translucentBorder.withOpacity(0.72)),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 22,
            runSpacing: 10,
            children: [
              _PlanIncludedItem(palette: palette, icon: Icons.security_rounded, label: 'Acceso seguro'),
              _PlanIncludedItem(palette: palette, icon: Icons.devices_rounded, label: 'Web, escritorio y móvil'),
              _PlanIncludedItem(palette: palette, icon: Icons.store_rounded, label: 'Datos separados por negocio'),
              _PlanIncludedItem(palette: palette, icon: Icons.system_update_alt_rounded, label: 'Evolución continua del producto'),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanData {
  const _PlanData({
    required this.name,
    required this.price,
    required this.period,
    required this.description,
    required this.features,
    this.recommended = false,
    this.enterprise = false,
  });

  final String name;
  final String price;
  final String period;
  final String description;
  final List<String> features;
  final bool recommended;
  final bool enterprise;
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.palette,
    required this.plan,
    required this.onTap,
  });

  final AppPalette palette;
  final _PlanData plan;
  final VoidCallback onTap;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final plan = widget.plan;
    final tint = plan.recommended ? palette.primary : plan.enterprise ? palette.secondary : palette.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withOpacity(plan.recommended ? 0.13 : 0.07),
              palette.surface.withOpacity(0.95),
              palette.background.withOpacity(0.90),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: tint.withOpacity(plan.recommended ? 0.42 : _hovered ? 0.30 : 0.17),
            width: plan.recommended ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_hovered ? 0.30 : 0.20),
              blurRadius: _hovered ? 34 : 24,
              offset: Offset(0, _hovered ? 16 : 10),
            ),
            if (plan.recommended)
              BoxShadow(color: palette.primary.withOpacity(0.08), blurRadius: 28, spreadRadius: 1),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: tint.withOpacity(0.18)),
                  ),
                  child: Icon(
                    plan.recommended
                        ? Icons.auto_awesome_rounded
                        : plan.enterprise
                            ? Icons.apartment_rounded
                            : Icons.rocket_launch_rounded,
                    color: tint,
                    size: 21,
                  ),
                ),
                const Spacer(),
                if (plan.recommended)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'RECOMENDADO',
                      style: TextStyle(color: Color(0xFF061723), fontWeight: FontWeight.w900, fontSize: 8.5, letterSpacing: 0.55),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(plan.name, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    plan.price,
                    style: TextStyle(
                      color: plan.recommended ? palette.primary : palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: plan.enterprise ? 30 : 34,
                      letterSpacing: -1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(plan.period, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.5)),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(plan.description, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.45, fontSize: 12.2)),
            const SizedBox(height: 19),
            Container(height: 1, color: palette.translucentBorder.withOpacity(0.60)),
            const SizedBox(height: 17),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 1),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: tint.withOpacity(0.10)),
                      child: Icon(Icons.check_rounded, size: 13, color: tint),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(feature, style: TextStyle(color: palette.textPrimary.withOpacity(0.90), fontWeight: FontWeight.w700, fontSize: 11.5, height: 1.35))),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: plan.recommended
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: FilledButton(
                        onPressed: widget.onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: const Color(0xFF061723),
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Elegir BarLytics Pro'),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: widget.onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(color: tint.withOpacity(0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      child: Text(plan.enterprise ? 'Hablar con nosotros' : 'Empezar con este plan'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanIncludedItem extends StatelessWidget {
  const _PlanIncludedItem({required this.palette, required this.icon, required this.label});
  final AppPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: palette.secondary),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 10.5)),
      ],
    );
  }
}

class _DownloadsSection extends StatelessWidget {
  const _DownloadsSection({required this.palette, required this.onDownload});
  final AppPalette palette;
  final ValueChanged<String> onDownload;

  @override
  Widget build(BuildContext context) {
    final items = <(String, IconData, String)>[
      ('Windows', Icons.window_rounded, 'Aplicación de escritorio'),
      ('macOS', Icons.laptop_mac_rounded, 'Aplicación para Mac'),
      ('iOS', Icons.phone_iphone_rounded, 'iPhone y iPad'),
      ('Android', Icons.android_rounded, 'Celulares y tablets'),
      ('Linux', Icons.computer_rounded, 'Distribución de escritorio'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560
            ? 1
            : constraints.maxWidth < 820
                ? 2
                : constraints.maxWidth < 1080
                    ? 3
                    : 5;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _DownloadCard(
                  palette: palette,
                  platform: item.$1,
                  icon: item.$2,
                  description: item.$3,
                  available: PublicSiteConfig.downloadUrlFor(item.$1).trim().isNotEmpty,
                  onTap: () => onDownload(item.$1),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.palette, required this.platform, required this.icon, required this.description, required this.available, required this.onTap});
  final AppPalette palette;
  final String platform;
  final IconData icon;
  final String description;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 210,
          padding: const EdgeInsets.all(19),
          decoration: palette.panelDecoration(baseRadius: 24, tint: available ? palette.secondary : palette.textSecondary, elevated: true),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: palette.secondary, size: 27)), const SizedBox(height: 17), Text(platform, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 4), Text(description, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)), const Spacer(), Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: (available ? palette.success : palette.warning).withOpacity(0.09), borderRadius: BorderRadius.circular(999), border: Border.all(color: (available ? palette.success : palette.warning).withOpacity(0.16))), child: Text(available ? 'DISPONIBLE' : 'PRÓXIMAMENTE', style: TextStyle(color: available ? palette.success : palette.warning, fontWeight: FontWeight.w900, fontSize: 8))), const Spacer(), Icon(available ? Icons.download_rounded : Icons.schedule_rounded, color: palette.secondary, size: 20)])]),
        ),
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({super.key, required this.palette, required this.onWhatsApp, required this.onRegister, required this.onLogin});
  final AppPalette palette;
  final VoidCallback onWhatsApp;
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 84, 20, 76),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette.primary.withOpacity(0.15), palette.surface.withOpacity(0.94), palette.secondary.withOpacity(0.14)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: palette.translucentBorder),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 38, offset: const Offset(0, 18))],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final copy = Column(crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [Text('¿Quieres ver BarLytics en tu negocio?', textAlign: compact ? TextAlign.center : TextAlign.left, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('Solicita información, registra tu interés o escríbenos directamente por WhatsApp.', textAlign: compact ? TextAlign.center : TextAlign.left, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.45, fontSize: 13))]);
                final actions = Wrap(alignment: compact ? WrapAlignment.center : WrapAlignment.end, spacing: 9, runSpacing: 9, children: [FilledButton.icon(onPressed: onWhatsApp, icon: const Icon(Icons.chat_rounded), label: const Text('Hablar por WhatsApp')), OutlinedButton.icon(onPressed: onRegister, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Registrarme')), TextButton.icon(onPressed: onLogin, icon: const Icon(Icons.login_rounded), label: const Text('Ingresar'))]);
                if (compact) return Column(children: [copy, const SizedBox(height: 22), actions]);
                return Row(children: [Expanded(child: copy), const SizedBox(width: 24), actions]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WhatsAppFloatingButton extends StatelessWidget {
  const _WhatsAppFloatingButton({required this.palette, required this.onTap});
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'public-whatsapp',
      onPressed: onTap,
      backgroundColor: const Color(0xFF25D366),
      foregroundColor: Colors.white,
      elevation: 8,
      icon: const Icon(Icons.chat_rounded),
      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.16),
        border: Border(top: BorderSide(color: palette.translucentBorder)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final brand = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
                    ),
                    child: const Icon(Icons.local_bar_rounded, color: Color(0xFF061723), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BarLytics',
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              );
              final text = Text(
                'Gestión para bares · Ventas · Inventario · Caja · Reportes',
                textAlign: compact ? TextAlign.center : TextAlign.left,
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.5),
              );
              final signature = Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.surface.withOpacity(0.76),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.translucentBorder.withOpacity(0.85)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/branding/mcode_m_icon.png',
                      height: 46,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Desarrollado por MCode SAS',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Innovación en cada línea',
                          style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              if (compact) {
                return Column(
                  children: [
                    brand,
                    const SizedBox(height: 10),
                    text,
                    const SizedBox(height: 18),
                    signature,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [brand, const SizedBox(height: 8), text],
                    ),
                  ),
                  const SizedBox(width: 18),
                  signature,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
