import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../business_setup/presentation/providers/business_setup_provider.dart';

class TablasParametricasPage extends ConsumerWidget {
  const TablasParametricasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final width = MediaQuery.sizeOf(context).width;
    final guidedSetup = ref.watch(businessSetupGuidedModeProvider);
    final columns = width >= 1120
        ? 3
        : width >= 720
            ? 2
            : 1;

    const companyCatalogItems = <_ParametricItem>[
      _ParametricItem(
        title: 'Tipos de producto',
        description: 'Organiza los productos por categorías propias de tu empresa. Se comparten entre tus sucursales.',
        icon: Icons.category_rounded,
        route: '/tipos_producto',
        createRoute: '/tipos_producto/nuevo',
        actionLabel: 'Administrar tipos',
      ),
      _ParametricItem(
        title: 'Marcas',
        description: 'Mantén las marcas que utiliza tu empresa. Ninguna otra empresa puede verlas ni modificarlas.',
        icon: Icons.sell_rounded,
        route: '/marcas',
        createRoute: '/marcas/nuevo',
        actionLabel: 'Administrar marcas',
      ),
    ];
    final items = guidedSetup
        ? companyCatalogItems
        : <_ParametricItem>[
            const _ParametricItem(
              title: 'Tipos de movimiento',
              description: 'Define si cada operación aumenta, disminuye o solicita el sentido del ajuste.',
              icon: Icons.sync_alt_rounded,
              route: '/tipos_movimiento',
              createRoute: '/tipos_movimiento/nuevo',
              actionLabel: 'Administrar movimientos',
            ),
            ...companyCatalogItems,
            const _ParametricItem(
              title: 'Medios de pago',
              description: 'Activa los medios disponibles y configura el código QR de cada sucursal.',
              icon: Icons.payments_rounded,
              route: '/medios_pago',
              actionLabel: 'Configurar pagos',
            ),
          ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18 * palette.spacingScale,
          20 * palette.spacingScale,
          18 * palette.spacingScale,
          110,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IntroStrip(palette: palette, guidedSetup: guidedSetup),
                SizedBox(height: 18 * palette.spacingScale),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final spacing = 16 * palette.spacingScale;
                    final cardWidth = columns == 1
                        ? constraints.maxWidth
                        : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final item in items)
                          SizedBox(
                            width: cardWidth,
                            child: _ParametricCard(item: item, palette: palette),
                          ),
                      ],
                    );
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

class _IntroStrip extends StatelessWidget {
  const _IntroStrip({required this.palette, required this.guidedSetup});

  final AppPalette palette;
  final bool guidedSetup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 18 * palette.spacingScale,
        vertical: 14 * palette.spacingScale,
      ),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.72 : 0.94),
        borderRadius: BorderRadius.circular(palette.radius(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.darkBackground ? 0.16 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.16),
              borderRadius: BorderRadius.circular(palette.radius(13)),
            ),
            child: Icon(Icons.tune_rounded, color: palette.secondary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              guidedSetup
                  ? 'Revisa las marcas y tipos de producto iniciales. Estos catálogos pertenecen únicamente a tu empresa y son obligatorios para crear productos.'
                  : 'Configura aquí los catálogos que apoyan la operación diaria del inventario.',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParametricCard extends StatelessWidget {
  const _ParametricCard({required this.item, required this.palette});

  final _ParametricItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface.withOpacity(palette.darkBackground ? 0.98 : 1),
            Color.lerp(
                  palette.surface,
                  palette.secondary,
                  palette.darkBackground ? 0.13 : 0.055,
                ) ??
                palette.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(palette.radius(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.darkBackground ? 0.18 : 0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(palette.radius(22)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(item.route),
          child: Padding(
            padding: EdgeInsets.all(18 * palette.spacingScale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: palette.secondary.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(palette.radius(16)),
                      ),
                      child: Icon(item.icon, color: palette.secondary, size: 28),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: palette.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  item.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.description,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go(item.route),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(item.actionLabel),
                      ),
                    ),
                    if (item.createRoute != null) ...[
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Crear nuevo',
                        onPressed: () => context.go(item.createRoute!),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParametricItem {
  const _ParametricItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.actionLabel,
    this.createRoute,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;
  final String actionLabel;
  final String? createRoute;
}
