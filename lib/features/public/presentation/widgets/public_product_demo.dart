import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/config/public_site_config.dart';

enum PublicDemoDevice { desktop, tablet, phone }

enum _DemoModule {
  inicio,
  mesas,
  ventaRapida,
  cuenta,
  cobro,
  inventario,
  productos,
  reportes,
  roles,
}

class _DemoModuleInfo {
  const _DemoModuleInfo({
    required this.slug,
    required this.label,
    required this.title,
    required this.description,
    required this.icon,
    required this.highlights,
  });

  final String slug;
  final String label;
  final String title;
  final String description;
  final IconData icon;
  final List<String> highlights;
}

_DemoModuleInfo _infoFor(_DemoModule module) => switch (module) {
      _DemoModule.inicio => const _DemoModuleInfo(
          slug: 'inicio',
          label: 'Inicio',
          title: 'Panel principal',
          description: 'Resumen operativo con indicadores y accesos rápidos del aplicativo real.',
          icon: Icons.space_dashboard_rounded,
          highlights: ['Indicadores de operación', 'Accesos rápidos', 'Contexto por sucursal'],
        ),
      _DemoModule.mesas => const _DemoModuleInfo(
          slug: 'mesas',
          label: 'Mesas',
          title: 'Ventas y mesas',
          description: 'Abre una mesa, consulta saldos y continúa la atención exactamente como en BarLytics.',
          icon: Icons.table_restaurant_rounded,
          highlights: ['Mesas libres y ocupadas', 'Saldo pendiente', 'Continuar o cobrar'],
        ),
      _DemoModule.ventaRapida => const _DemoModuleInfo(
          slug: 'venta-rapida',
          label: 'Venta rápida',
          title: 'Venta directa',
          description: 'Selección ágil de productos para ventas de mostrador sin necesidad de crear una mesa.',
          icon: Icons.bolt_rounded,
          highlights: ['Tu venta siempre visible', 'Cantidades y total', 'Acceso directo al cobro'],
        ),
      _DemoModule.cuenta => const _DemoModuleInfo(
          slug: 'cuenta',
          label: 'Cuenta',
          title: 'Detalle de cuenta',
          description: 'Productos, cantidades, subtotales, pagos, propina y saldo en una sola vista.',
          icon: Icons.receipt_long_rounded,
          highlights: ['Productos consumidos', 'Propina y pagos', 'Saldo por cobrar'],
        ),
      _DemoModule.cobro => const _DemoModuleInfo(
          slug: 'cobro',
          label: 'Cobro',
          title: 'Cobro POS',
          description: 'Efectivo, pago exacto, billetes y monedas, vueltas y múltiples medios de pago.',
          icon: Icons.payments_rounded,
          highlights: ['Pago exacto', 'Efectivo visual', 'Varios medios de pago'],
        ),
      _DemoModule.inventario => const _DemoModuleInfo(
          slug: 'inventario',
          label: 'Inventario',
          title: 'Control de inventario',
          description: 'Existencias, alertas, movimientos y control de stock por sucursal.',
          icon: Icons.inventory_2_rounded,
          highlights: ['Stock actual', 'Alertas de stock bajo', 'Movimientos trazables'],
        ),
      _DemoModule.productos => const _DemoModuleInfo(
          slug: 'productos',
          label: 'Productos',
          title: 'Productos y precios',
          description: 'Administración de productos, precios de compra/venta e historial de cambios.',
          icon: Icons.sell_rounded,
          highlights: ['Precio de compra', 'Precio de venta', 'Historial de precios'],
        ),
      _DemoModule.reportes => const _DemoModuleInfo(
          slug: 'reportes',
          label: 'Reportes',
          title: 'Reportes operativos',
          description: 'Ventas, ganancias, inventario y métricas para tomar decisiones con información clara.',
          icon: Icons.insights_rounded,
          highlights: ['Ventas y ganancias', 'Gráficos', 'Filtros por periodo'],
        ),
      _DemoModule.roles => const _DemoModuleInfo(
          slug: 'roles',
          label: 'Roles',
          title: 'Roles y permisos',
          description: 'Controla qué puede ver y ejecutar cada perfil dentro de la empresa y sus sucursales.',
          icon: Icons.admin_panel_settings_rounded,
          highlights: ['Permisos personalizados', 'Menús dinámicos', 'Control por rol'],
        ),
    };

extension on PublicDemoDevice {
  String get folder => switch (this) {
        PublicDemoDevice.desktop => 'desktop',
        PublicDemoDevice.tablet => 'tablet',
        PublicDemoDevice.phone => 'phone',
      };

  String get label => switch (this) {
        PublicDemoDevice.desktop => 'Escritorio',
        PublicDemoDevice.tablet => 'Tablet',
        PublicDemoDevice.phone => 'Celular',
      };

  IconData get icon => switch (this) {
        PublicDemoDevice.desktop => Icons.desktop_windows_rounded,
        PublicDemoDevice.tablet => Icons.tablet_mac_rounded,
        PublicDemoDevice.phone => Icons.phone_iphone_rounded,
      };

  double get targetWidth => switch (this) {
        PublicDemoDevice.desktop => 1120,
        PublicDemoDevice.tablet => 736,
        PublicDemoDevice.phone => 512,
      };

  double get heightRatio => switch (this) {
        PublicDemoDevice.desktop => 0.565,
        PublicDemoDevice.tablet => 0.74,
        PublicDemoDevice.phone => 1108 / 512,
      };
}

class PublicProductDemo extends StatefulWidget {
  const PublicProductDemo({super.key});

  @override
  State<PublicProductDemo> createState() => _PublicProductDemoState();
}

class _PublicProductDemoState extends State<PublicProductDemo> {
  final List<VideoPlayerController> _preloadControllers = [];
  bool _preloadStarted = false;
  PublicDemoDevice _device = PublicDemoDevice.desktop;
  _DemoModule _module = _DemoModule.mesas;
  int _replay = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_preloadStarted) {
      _preloadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _preloadDemoVideos());
    }
  }

  Future<void> _preloadDemoVideos() async {
    for (final device in const [PublicDemoDevice.phone, PublicDemoDevice.tablet]) {
      for (final module in _DemoModule.values) {
        if (!mounted) return;
        final url = _demoMediaUrl(device, _infoFor(module).slug);
        if (url.isEmpty) continue;
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        _preloadControllers.add(controller);
        try {
          await controller.initialize();
          await controller.setVolume(0);
        } catch (_) {
          // El placeholder normal maneja medios no disponibles.
        }
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _preloadControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalettes.first;
    final info = _infoFor(_module);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DemoHeader(
          palette: palette,
          device: _device,
          onDevice: (value) => setState(() {
            _device = value;
            _replay++;
          }),
        ),
        const SizedBox(height: 14),
        _ModuleSelector(
          palette: palette,
          selected: _module,
          onSelect: (value) => setState(() {
            _module = value;
            _replay++;
          }),
        ),
        const SizedBox(height: 18),
        _DemoStage(
          palette: palette,
          device: _device,
          info: info,
          replay: _replay,
        ),
        const SizedBox(height: 18),
        _DemoDescription(
          palette: palette,
          device: _device,
          info: info,
          onReplay: () => setState(() => _replay++),
        ),
      ],
    );
  }
}

class _DemoHeader extends StatelessWidget {
  const _DemoHeader({
    required this.palette,
    required this.device,
    required this.onDevice,
  });

  final AppPalette palette;
  final PublicDemoDevice device;
  final ValueChanged<PublicDemoDevice> onDevice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.secondary, elevated: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: palette.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'DEMOSTRACIÓN REAL',
                    style: TextStyle(
                      color: palette.success,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 0.75,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Mira el aplicativo tal como se usa',
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          );

          final selector = _DeviceSelector(
            palette: palette,
            device: device,
            onDevice: onDevice,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 12), selector],
            );
          }

          return Row(children: [Expanded(child: copy), const SizedBox(width: 18), selector]);
        },
      ),
    );
  }
}

class _DeviceSelector extends StatelessWidget {
  const _DeviceSelector({required this.palette, required this.device, required this.onDevice});

  final AppPalette palette;
  final PublicDemoDevice device;
  final ValueChanged<PublicDemoDevice> onDevice;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final value in PublicDemoDevice.values)
          InkWell(
            onTap: () => onDevice(value),
            borderRadius: BorderRadius.circular(13),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: device == value ? palette.secondary.withOpacity(0.16) : palette.background.withOpacity(0.35),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: device == value ? palette.secondary.withOpacity(0.55) : palette.cardBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(value.icon, size: 17, color: device == value ? palette.secondary : palette.textSecondary),
                  const SizedBox(width: 7),
                  Text(
                    value.label,
                    style: TextStyle(
                      color: device == value ? palette.textPrimary : palette.textSecondary,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ModuleSelector extends StatelessWidget {
  const _ModuleSelector({required this.palette, required this.selected, required this.onSelect});

  final AppPalette palette;
  final _DemoModule selected;
  final ValueChanged<_DemoModule> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _DemoModule.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final module = _DemoModule.values[index];
          final info = _infoFor(module);
          final active = module == selected;
          return InkWell(
            onTap: () => onSelect(module),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 126,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                gradient: active ? palette.panelGradient(tint: palette.secondary) : null,
                color: active ? null : palette.surface.withOpacity(0.62),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: active ? palette.secondary.withOpacity(0.42) : palette.cardBorder),
                boxShadow: active
                    ? [BoxShadow(color: palette.secondary.withOpacity(0.09), blurRadius: 18, offset: const Offset(0, 8))]
                    : const [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(info.icon, color: active ? palette.secondary : palette.textSecondary, size: 22),
                  const SizedBox(height: 8),
                  Text(
                    info.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? palette.textPrimary : palette.textSecondary,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DemoStage extends StatelessWidget {
  const _DemoStage({
    required this.palette,
    required this.device,
    required this.info,
    required this.replay,
  });

  final AppPalette palette;
  final PublicDemoDevice device;
  final _DemoModuleInfo info;
  final int replay;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = math.min(constraints.maxWidth, device.targetWidth).toDouble();
        final double height = width * device.heightRatio;
        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: width,
            height: height,
            child: _DeviceFrame(
              palette: palette,
              device: device,
              child: _DemoMedia(
                key: ValueKey('${device.folder}-${info.slug}-$replay'),
                palette: palette,
                device: device,
                info: info,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({required this.palette, required this.device, required this.child});

  final AppPalette palette;
  final PublicDemoDevice device;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = device == PublicDemoDevice.phone ? 38.0 : 27.0;
    final body = Column(
      children: [
        _DeviceTopChrome(palette: palette, device: device),
        Expanded(child: child),
        if (device == PublicDemoDevice.phone)
          Container(
            height: 23,
            alignment: Alignment.center,
            color: const Color(0xFF040B11),
            child: Container(
              width: 92,
              height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.35), borderRadius: BorderRadius.circular(99)),
            ),
          ),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF040B11),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.translucentBorder, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.42), blurRadius: 46, offset: const Offset(0, 22)),
          BoxShadow(color: palette.secondary.withOpacity(0.09), blurRadius: 38, spreadRadius: -8),
        ],
      ),
      child: body,
    );
  }
}

class _DeviceTopChrome extends StatelessWidget {
  const _DeviceTopChrome({required this.palette, required this.device});

  final AppPalette palette;
  final PublicDemoDevice device;

  @override
  Widget build(BuildContext context) {
    if (device == PublicDemoDevice.phone) {
      return Container(
        height: 31,
        color: const Color(0xFF040B11),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Text('9:41', style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w800, fontSize: 9)),
            const Spacer(),
            Container(width: 58, height: 17, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(99))),
            const Spacer(),
            Icon(Icons.signal_cellular_alt_rounded, size: 11, color: Colors.white.withOpacity(0.78)),
            const SizedBox(width: 3),
            Icon(Icons.wifi_rounded, size: 11, color: Colors.white.withOpacity(0.78)),
            const SizedBox(width: 3),
            Icon(Icons.battery_full_rounded, size: 12, color: Colors.white.withOpacity(0.78)),
            const SizedBox(width: 12),
          ],
        ),
      );
    }

    if (device == PublicDemoDevice.tablet) {
      return Container(
        height: 32,
        color: const Color(0xFF07131C),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(width: 7, height: 7, decoration: BoxDecoration(color: palette.primary, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text('BarLytics · Tablet', style: TextStyle(color: Colors.white.withOpacity(0.72), fontWeight: FontWeight.w800, fontSize: 9)),
            const Spacer(),
            Icon(Icons.wifi_rounded, size: 12, color: Colors.white.withOpacity(0.72)),
            const SizedBox(width: 10),
          ],
        ),
      );
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      color: const Color(0xFF07131C),
      child: Row(
        children: [
          for (final color in const [Color(0xFFFF5F57), Color(0xFFFFBD2E), Color(0xFF28C840)]) ...[
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.055), borderRadius: BorderRadius.circular(8)),
              child: Text(
                'BarLytics · Demo real',
                style: TextStyle(color: Colors.white.withOpacity(0.62), fontWeight: FontWeight.w700, fontSize: 9),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _DemoMedia extends StatelessWidget {
  const _DemoMedia({super.key, required this.palette, required this.device, required this.info});

  final AppPalette palette;
  final PublicDemoDevice device;
  final _DemoModuleInfo info;

  @override
  Widget build(BuildContext context) {
    final url = _demoMediaUrl(device, info.slug);
    if (url.isEmpty) {
      return _MediaPlaceholder(palette: palette, device: device, info: info);
    }

    final media = _DemoVideo(url: url, palette: palette, device: device, info: info);

    return Stack(
      fit: StackFit.expand,
      children: [
        media,
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF061723).withOpacity(0.84),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.primary.withOpacity(0.24)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: palette.success, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('DEMO REAL · ${device.label.toUpperCase()}', style: TextStyle(color: Colors.white.withOpacity(0.88), fontWeight: FontWeight.w900, fontSize: 7.5, letterSpacing: 0.45)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoVideo extends StatefulWidget {
  const _DemoVideo({required this.url, required this.palette, required this.device, required this.info});

  final String url;
  final AppPalette palette;
  final PublicDemoDevice device;
  final _DemoModuleInfo info;

  @override
  State<_DemoVideo> createState() => _DemoVideoState();
}

class _DemoVideoState extends State<_DemoVideo> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _MediaPlaceholder(
        palette: widget.palette,
        device: widget.device,
        info: widget.info,
      );
    }
    if (!_controller.value.isInitialized) {
      return _MediaLoading(palette: widget.palette, info: widget.info);
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

class _MediaLoading extends StatelessWidget {
  const _MediaLoading({required this.palette, required this.info});

  final AppPalette palette;
  final _DemoModuleInfo info;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.pageGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: palette.secondary, strokeWidth: 2.5),
            const SizedBox(height: 12),
            Text('Cargando ${info.label.toLowerCase()}…', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.palette, required this.device, required this.info});

  final AppPalette palette;
  final PublicDemoDevice device;
  final _DemoModuleInfo info;

  @override
  Widget build(BuildContext context) {
    const extension = 'mp4';
    final relativePath = 'web/demos/${device.folder}/${info.slug}.$extension';
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.background, Color.lerp(palette.background, palette.secondary, 0.13)!, palette.surface],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -90, right: -70, child: _Glow(size: 250, color: palette.secondary)),
          Positioned(bottom: -110, left: -80, child: _Glow(size: 300, color: palette.primary)),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final micro = constraints.maxWidth < 150 || constraints.maxHeight < 220;
                final compact = constraints.maxWidth < 280 || constraints.maxHeight < 330;

                if (micro) {
                  return Center(
                    child: Container(
                      width: math.min(54.0, constraints.maxWidth * 0.56).toDouble(),
                      height: math.min(54.0, constraints.maxWidth * 0.56).toDouble(),
                      decoration: BoxDecoration(
                        color: palette.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.secondary.withOpacity(0.20)),
                      ),
                      child: Icon(
                        info.icon,
                        color: palette.secondary,
                        size: math.min(27.0, constraints.maxWidth * 0.28).toDouble(),
                      ),
                    ),
                  );
                }

                if (compact) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: palette.secondary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: palette.secondary.withOpacity(0.18)),
                            ),
                            child: Icon(info.icon, color: palette.secondary, size: 22),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            info.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vista real del aplicativo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: palette.secondary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: palette.secondary.withOpacity(0.18)),
                            ),
                            child: Icon(info.icon, color: palette.secondary, size: 34),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Aquí irá la grabación real de ${info.label}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No mostramos una maqueta inventada. Cuando agregues la grabación real de BarLytics, aparecerá automáticamente en este marco.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.45, fontSize: 11.5),
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: palette.cardBorder),
                            ),
                            child: Text(
                              relativePath,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.primary, fontWeight: FontWeight.w800, fontSize: 9.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withOpacity(0.13), Colors.transparent]),
          ),
        ),
      );
}

class _DemoDescription extends StatelessWidget {
  const _DemoDescription({
    required this.palette,
    required this.device,
    required this.info,
    required this.onReplay,
  });

  final AppPalette palette;
  final PublicDemoDevice device;
  final _DemoModuleInfo info;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.primary, elevated: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 5),
              Text(info.description, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, height: 1.45, fontSize: 11.5)),
              const SizedBox(height: 11),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final item in info.highlights)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(color: palette.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: palette.primary.withOpacity(0.13))),
                      child: Text(item, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 9)),
                    ),
                ],
              ),
            ],
          );
          final replay = OutlinedButton.icon(
            onPressed: onReplay,
            icon: const Icon(Icons.replay_rounded),
            label: Text('Repetir ${device.label.toLowerCase()}'),
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 14), replay]);
          return Row(children: [Expanded(child: copy), const SizedBox(width: 20), replay]);
        },
      ),
    );
  }
}

class PublicResponsivePreviewGallery extends StatelessWidget {
  const PublicResponsivePreviewGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = appPalettes.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final cards = const [
          (PublicDemoDevice.desktop, _DemoModule.mesas),
          (PublicDemoDevice.tablet, _DemoModule.cobro),
          (PublicDemoDevice.phone, _DemoModule.ventaRapida),
        ];

        if (compact) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                _ResponsiveMediaCard(palette: palette, device: cards[i].$1, module: cards[i].$2),
                if (i != cards.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: _ResponsiveMediaCard(palette: palette, device: cards[i].$1, module: cards[i].$2)),
              if (i != cards.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }
}

class _ResponsiveMediaCard extends StatelessWidget {
  const _ResponsiveMediaCard({required this.palette, required this.device, required this.module});

  final AppPalette palette;
  final PublicDemoDevice device;
  final _DemoModule module;

  @override
  Widget build(BuildContext context) {
    final info = _infoFor(module);
    final previewHeight = switch (device) {
      PublicDemoDevice.desktop => 225.0,
      PublicDemoDevice.tablet => 260.0,
      PublicDemoDevice.phone => 330.0,
    };

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: palette.panelDecoration(baseRadius: 24, tint: device == PublicDemoDevice.phone ? palette.primary : palette.secondary, elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(11)), child: Icon(device.icon, color: palette.secondary, size: 18)),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(device.label, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12)), Text(info.label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 9))])),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: previewHeight,
            child: Center(
              child: _MiniDeviceFrame(
                palette: palette,
                device: device,
                info: info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDeviceFrame extends StatelessWidget {
  const _MiniDeviceFrame({required this.palette, required this.device, required this.info});

  final AppPalette palette;
  final PublicDemoDevice device;
  final _DemoModuleInfo info;

  @override
  Widget build(BuildContext context) {
    final aspect = switch (device) {
      PublicDemoDevice.desktop => 16 / 10,
      PublicDemoDevice.tablet => 736 / 512,
      PublicDemoDevice.phone => 512 / 1108,
    };
    return AspectRatio(
      aspectRatio: aspect,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF040B11),
          borderRadius: BorderRadius.circular(device == PublicDemoDevice.phone ? 24 : 17),
          border: Border.all(color: palette.translucentBorder),
        ),
        child: _DemoMedia(palette: palette, device: device, info: info),
      ),
    );
  }
}

class PublicHeroDemoPreview extends StatelessWidget {
  const PublicHeroDemoPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = appPalettes.first;
    final desktopInfo = _infoFor(_DemoModule.mesas);
    final phoneInfo = _infoFor(_DemoModule.ventaRapida);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return AspectRatio(
          aspectRatio: compact ? 1.48 : 1.72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                right: compact ? 28 : 34,
                bottom: compact ? 22 : 10,
                child: Container(
                  padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: palette.panelGradient(tint: palette.secondary),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: palette.translucentBorder),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.34), blurRadius: 40, offset: const Offset(0, 20))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _DemoMedia(palette: palette, device: PublicDemoDevice.desktop, info: desktopInfo),
              ),
            ),
          ),
              Positioned(
                right: compact ? -2 : -10,
                bottom: compact ? -12 : -24,
                child: Container(
                  width: compact ? 112 : 132,
                  height: compact ? 226 : 258,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF040B11),
                borderRadius: BorderRadius.circular(29),
                border: Border.all(color: palette.translucentBorder),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.38), blurRadius: 28, offset: const Offset(0, 14))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: _DemoMedia(palette: palette, device: PublicDemoDevice.phone, info: phoneInfo),
              ),
            ),
          ),
            ],
          ),
        );
      },
    );
  }
}

String _demoMediaUrl(PublicDemoDevice device, String slug) {
  final base = PublicSiteConfig.demoMediaBaseUrl.trim();
  if (base.isEmpty) return '';
  final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  const extension = 'mp4';
  final relative = '$normalized/${device.folder}/$slug.$extension';
  if (normalized.startsWith('http://') || normalized.startsWith('https://')) return relative;
  if (!kIsWeb) return '';
  return Uri.base.resolve(relative).toString();
}
