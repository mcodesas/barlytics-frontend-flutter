
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../inventario/data/models/inventario_response_model.dart';
import '../../../inventario/presentation/providers/inventario_provider.dart';
import '../../../marcas/data/models/marcas_response_model.dart';
import '../../../marcas/presentation/providers/marcas_provider.dart';
import '../../../precios/data/models/precios_response_model.dart';
import '../../../precios/presentation/providers/precios_provider.dart';
import '../../../sucursales/presentation/providers/sucursales_provider.dart';
import '../../../tipos_producto/data/models/tipos_producto_response_model.dart';
import '../../../tipos_producto/presentation/providers/tipos_producto_provider.dart';
import '../../data/models/productos_response_model.dart';
import '../providers/productos_provider.dart';

class ProductosDetailPage extends ConsumerWidget {
  const ProductosDetailPage({super.key, required this.id});

  final String id;

  int? get _productId => int.tryParse(id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final productId = _productId;
    final productosState = ref.watch(productosProvider);
    final inventarioState = ref.watch(inventarioProvider);
    final preciosState = ref.watch(preciosProvider);
    final marcasState = ref.watch(marcasProvider);
    final tiposState = ref.watch(tiposproductoProvider);
    final sucursalesState = ref.watch(sucursalesProvider);

    final loading = productosState.loading ||
        inventarioState.loading ||
        preciosState.loading ||
        marcasState.loading ||
        tiposState.loading ||
        sucursalesState.loading;
    final failure = productosState.failure ??
        inventarioState.failure ??
        preciosState.failure ??
        marcasState.failure ??
        tiposState.failure ??
        sucursalesState.failure;

    final producto = _firstOrNull(
      productosState.items.where((item) => item.prodId == productId),
    );

    if (loading && producto == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(child: AppPageBackground()),
            AppLoader(),
          ],
        ),
      );
    }

    if (failure != null && producto == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: AppPageBackground()),
            AppErrorView(
              message: failure.message,
              onRetry: () => _reload(ref),
            ),
          ],
        ),
      );
    }

    if (producto == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(child: AppPageBackground()),
            AppEmptyView(
              message: 'No fue posible encontrar el producto seleccionado.',
            ),
          ],
        ),
      );
    }

    final inventarios = inventarioState.items
        .where((item) => item.prodId == producto.prodId && item.sucuId == producto.sucuId)
        .toList()
      ..sort((a, b) => (b.invtFecha ?? '').compareTo(a.invtFecha ?? ''));
    final cantidadInventario = inventarios.fold<double>(
      0,
      (total, item) => total + (item.invtCantidad ?? 0),
    );

    final precios = preciosState.items
        .where((item) => item.prodId == producto.prodId && item.sucuId == producto.sucuId)
        .toList()
      ..sort((a, b) => (b.precFechaInicia ?? '').compareTo(a.precFechaInicia ?? ''));
    final precioActivo = _firstOrNull(precios.where((item) => item.precEstado == 1));

    final marca = _firstOrNull(
      marcasState.items.where((item) => item.mrcaId == producto.mrcaId),
    );
    final tipo = _firstOrNull(
      tiposState.items.where((item) => item.tpprId == producto.tpprId),
    );
    final sucursal = _firstOrNull(
      sucursalesState.items.where((item) => item.sucuId == producto.sucuId),
    );
    final sucursalNombre =
        sucursal?.sucuNombre ?? 'Sucursal ${producto.sucuId ?? '-'}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: () => _reload(ref),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      _ProductHeader(
                        producto: producto,
                        marca: marca,
                        tipo: tipo,
                        sucursalNombre: sucursalNombre,
                        cantidadInventario: cantidadInventario,
                        precioActivo: precioActivo,
                        palette: palette,
                        onEdit: () => context.go('/productos/$id/editar'),
                        onRefresh: () => _reload(ref),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 8,
                        left: 8,
                        child: _HeaderBackButton(
                          onPressed: () => context.go('/productos'),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  sliver: SliverToBoxAdapter(
                    child: _ProductDetailBody(
                      producto: producto,
                      marca: marca,
                      tipo: tipo,
                      sucursalNombre: sucursalNombre,
                      inventarios: inventarios,
                      cantidadInventario: cantidadInventario,
                      precios: precios,
                      precioActivo: precioActivo,
                      loading: loading,
                      palette: palette,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reload(WidgetRef ref) async {
    await Future.wait([
      ref.read(productosProvider.notifier).load(),
      ref.read(inventarioProvider.notifier).load(),
      ref.read(preciosProvider.notifier).load(),
      ref.read(marcasProvider.notifier).load(),
      ref.read(tiposproductoProvider.notifier).load(),
      ref.read(sucursalesProvider.notifier).load(),
    ]);
  }
}


class _ProductDetailBody extends StatelessWidget {
  const _ProductDetailBody({
    required this.producto,
    required this.marca,
    required this.tipo,
    required this.sucursalNombre,
    required this.inventarios,
    required this.cantidadInventario,
    required this.precios,
    required this.precioActivo,
    required this.loading,
    required this.palette,
  });

  final ProductosResponseModel producto;
  final MarcasResponseModel? marca;
  final TiposProductoResponseModel? tipo;
  final String sucursalNombre;
  final List<InventarioResponseModel> inventarios;
  final double cantidadInventario;
  final List<PreciosResponseModel> precios;
  final PreciosResponseModel? precioActivo;
  final bool loading;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final sale = precioActivo?.precValorVenta ?? 0;
    final purchase = precioActivo?.precValorCompra ?? 0;
    final utility = sale - purchase;
    final margin = sale > 0 ? (utility / sale) * 100 : 0.0;

    final infoCard = _SectionCard(
      palette: palette,
      title: 'Ficha del producto',
      icon: Icons.info_outline_rounded,
      child: _SimpleInfoList(
        palette: palette,
        rows: [
          _InfoItem('Producto', _value(producto.prodNombre)),
          _InfoItem('Descripción', _value(producto.prodDescripcion, fallback: 'Sin descripción registrada.')),
          _InfoItem('Sucursal', sucursalNombre),
          _InfoItem('Marca', marca?.mrcaNombre ?? 'Marca no definida'),
          _InfoItem('Tipo de producto', tipo?.tpprNombre ?? 'Tipo no definido'),
          _InfoItem('Fecha de vencimiento', _date(producto.prodFechaVencimiento)),
          _InfoItem(
            'Compra por presentación',
            (producto.prodCompraPorCantidad ?? 0) == 1
                ? '${_number(producto.prodCantidadCompra ?? 0)} unidades · ${_value(producto.prodPresentacionCompra, fallback: 'Presentación')}'
                : 'Compra por unidad',
          ),
          _InfoItem('Última modificación', _date(producto.prodFechaCambio)),
        ],
      ),
    );

    final inventoryCard = _SectionCard(
      palette: palette,
      title: 'Inventario',
      icon: Icons.inventory_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InventoryOverview(
            palette: palette,
            total: cantidadInventario,
            records: inventarios.length,
            sucursalNombre: sucursalNombre,
          ),
          const SizedBox(height: 16),
          Text('Movimientos recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: palette.textPrimary)),
          const SizedBox(height: 10),
          inventarios.isEmpty
              ? _EmptyMiniMessage(palette: palette, text: 'Este producto todavía no tiene inventario registrado.')
              : _InventoryHistoryTable(palette: palette, items: inventarios, sucursalNombre: sucursalNombre),
        ],
      ),
    );

    final activePriceCard = _SectionCard(
      palette: palette,
      title: 'Precio y rentabilidad',
      icon: Icons.local_offer_rounded,
      trailing: precioActivo == null
          ? _StatusPill(text: 'Sin precio activo', active: false, palette: palette)
          : _StatusPill(text: 'Activo', active: true, palette: palette),
      child: precioActivo == null
          ? _EmptyMiniMessage(palette: palette, text: 'No se encontró un precio activo para este producto.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActivePriceSummary(palette: palette, price: precioActivo!),
                const SizedBox(height: 14),
                _ProfitabilitySummary(
                  palette: palette,
                  utility: utility,
                  margin: margin,
                  sale: sale,
                  purchase: purchase,
                ),
              ],
            ),
    );

    final historyCard = _SectionCard(
      palette: palette,
      title: 'Historial de precios',
      icon: Icons.history_rounded,
      child: precios.isEmpty
          ? _EmptyMiniMessage(palette: palette, text: 'No hay historial de precios registrado.')
          : _PriceHistoryTable(palette: palette, prices: precios),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProductQuickSummary(
          palette: palette,
          inventory: cantidadInventario,
          salesYesterday: producto.ventasAyer ?? 0,
          salePrice: precioActivo?.precValorVenta,
          margin: precioActivo == null ? null : margin,
          expirationDate: producto.prodFechaVencimiento,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 980) {
              return Column(
                children: [
                  infoCard,
                  const SizedBox(height: 14),
                  activePriceCard,
                  const SizedBox(height: 14),
                  inventoryCard,
                  const SizedBox(height: 14),
                  historyCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(children: [infoCard, const SizedBox(height: 14), inventoryCard]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: Column(children: [activePriceCard, const SizedBox(height: 14), historyCard]),
                ),
              ],
            );
          },
        ),
        if (loading) ...[
          const SizedBox(height: 14),
          LinearProgressIndicator(color: palette.secondary, backgroundColor: palette.background),
        ],
      ],
    );
  }
}

class _ProductQuickSummary extends StatelessWidget {
  const _ProductQuickSummary({
    required this.palette,
    required this.inventory,
    required this.salesYesterday,
    required this.salePrice,
    required this.margin,
    required this.expirationDate,
  });

  final AppPalette palette;
  final double inventory;
  final double salesYesterday;
  final double? salePrice;
  final double? margin;
  final String? expirationDate;

  @override
  Widget build(BuildContext context) {
    final expiration = _expirationSummary(expirationDate, palette);
    final metrics = [
      _DetailMetric(icon: Icons.inventory_2_rounded, label: 'Inventario actual', value: '${_number(inventory)} unidades', color: inventory <= 0 ? Colors.redAccent : palette.secondary),
      _DetailMetric(icon: Icons.trending_up_rounded, label: 'Vendido ayer', value: '${_number(salesYesterday)} unidades', color: Colors.greenAccent.shade400),
      _DetailMetric(icon: Icons.payments_rounded, label: 'Precio de venta', value: salePrice == null ? 'Sin precio' : _money(salePrice), color: palette.secondary),
      _DetailMetric(icon: Icons.analytics_rounded, label: 'Margen estimado', value: margin == null ? 'Sin cálculo' : '${_number(margin!)}%', color: (margin ?? 0) >= 0 ? Colors.greenAccent.shade400 : Colors.redAccent),
      _DetailMetric(icon: expiration.icon, label: 'Vencimiento', value: expiration.label, color: expiration.color),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 720
                ? 3
                : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final metric in metrics) SizedBox(width: width, child: _DetailMetricCard(metric: metric, palette: palette))],
        );
      },
    );
  }
}

class _DetailMetric {
  const _DetailMetric({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _DetailMetricCard extends StatelessWidget {
  const _DetailMetricCard({required this.metric, required this.palette});
  final _DetailMetric metric;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: metric.color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(metric.icon, color: metric.color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.5)),
                const SizedBox(height: 4),
                Text(metric.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitabilitySummary extends StatelessWidget {
  const _ProfitabilitySummary({
    required this.palette,
    required this.utility,
    required this.margin,
    required this.sale,
    required this.purchase,
  });

  final AppPalette palette;
  final double utility;
  final double margin;
  final double sale;
  final double purchase;

  @override
  Widget build(BuildContext context) {
    final positive = utility >= 0;
    final color = positive ? Colors.greenAccent.shade400 : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          _ProfitRow(label: 'Costo unitario', value: _money(purchase), palette: palette),
          const SizedBox(height: 8),
          _ProfitRow(label: 'Precio de venta', value: _money(sale), palette: palette),
          Divider(height: 20, color: palette.cardBorder),
          _ProfitRow(label: 'Utilidad estimada', value: _money(utility), palette: palette, valueColor: color, strong: true),
          const SizedBox(height: 8),
          _ProfitRow(label: 'Margen estimado', value: '${_number(margin)}%', palette: palette, valueColor: color, strong: true),
        ],
      ),
    );
  }
}

class _ProfitRow extends StatelessWidget {
  const _ProfitRow({required this.label, required this.value, required this.palette, this.valueColor, this.strong = false});
  final String label;
  final String value;
  final AppPalette palette;
  final Color? valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Text(value, style: TextStyle(color: valueColor ?? palette.textPrimary, fontWeight: strong ? FontWeight.w900 : FontWeight.w800)),
      ],
    );
  }
}

class _ExpirationSummary {
  const _ExpirationSummary({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;
}

_ExpirationSummary _expirationSummary(String? value, AppPalette palette) {
  if (value == null || value.trim().isEmpty) {
    return _ExpirationSummary(label: 'No aplica', icon: Icons.event_available_rounded, color: palette.textSecondary);
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return _ExpirationSummary(label: value, icon: Icons.event_rounded, color: palette.secondary);
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(parsed.year, parsed.month, parsed.day);
  final days = target.difference(today).inDays;
  if (days < 0) {
    return const _ExpirationSummary(label: 'Vencido', icon: Icons.event_busy_rounded, color: Colors.redAccent);
  }
  if (days <= 30) {
    return _ExpirationSummary(label: '$days días', icon: Icons.schedule_rounded, color: palette.primary);
  }
  return _ExpirationSummary(label: _date(value), icon: Icons.event_rounded, color: palette.secondary);
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.18),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    required this.producto,
    required this.marca,
    required this.tipo,
    required this.sucursalNombre,
    required this.cantidadInventario,
    required this.precioActivo,
    required this.palette,
    required this.onEdit,
    required this.onRefresh,
  });

  final ProductosResponseModel producto;
  final MarcasResponseModel? marca;
  final TiposProductoResponseModel? tipo;
  final String sucursalNombre;
  final double cantidadInventario;
  final PreciosResponseModel? precioActivo;
  final AppPalette palette;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final title = _value(producto.prodNombre, fallback: 'Producto sin nombre');
    final stockColor = cantidadInventario <= 0
        ? Colors.redAccent
        : cantidadInventario <= 5
            ? palette.primary
            : Colors.greenAccent.shade400;
    final stockText = cantidadInventario <= 0
        ? 'Sin stock'
        : cantidadInventario <= 5
            ? 'Stock bajo'
            : 'Disponible';

    return TechBackground(
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final image = Stack(
            clipBehavior: Clip.none,
            children: [
              _ProductImage(value: producto.prodFoto, size: compact ? 112 : 124),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF071A1C),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: stockColor.withOpacity(0.72)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: stockColor),
                      const SizedBox(width: 5),
                      Text(stockText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    _HeaderActions(palette: palette, onEdit: onEdit, onRefresh: onRefresh),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _value(producto.prodDescripcion, fallback: 'Sin descripción registrada.'),
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.80), fontWeight: FontWeight.w700, height: 1.35),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderChip(icon: Icons.inventory_2_rounded, text: '${_number(cantidadInventario)} unidades'),
                  _HeaderChip(icon: Icons.storefront_rounded, text: sucursalNombre),
                  _HeaderChip(icon: Icons.sell_rounded, text: marca?.mrcaNombre ?? 'Marca no definida'),
                  _HeaderChip(icon: Icons.category_rounded, text: tipo?.tpprNombre ?? 'Tipo no definido'),
                  if (precioActivo != null)
                    _HeaderChip(icon: Icons.payments_rounded, text: _money(precioActivo!.precValorVenta)),
                ],
              ),
              if (compact) ...[
                const SizedBox(height: 12),
                _HeaderActions(palette: palette, onEdit: onEdit, onRefresh: onRefresh),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [image, const SizedBox(width: 16), Expanded(child: details)],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              image,
              if ((marca?.mrcaLogo ?? '').trim().isNotEmpty) ...[
                const SizedBox(width: 10),
                _BrandLogo(value: marca?.mrcaLogo),
              ],
              const SizedBox(width: 18),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.palette,
    required this.onEdit,
    required this.onRefresh,
  });

  final AppPalette palette;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showText = MediaQuery.sizeOf(context).width >= 720;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            _HeaderActionButton(
              palette: palette,
              icon: Icons.edit_rounded,
              label: 'Modificar',
              showText: showText,
              onPressed: onEdit,
            ),
            _HeaderActionButton(
              palette: palette,
              icon: Icons.refresh_rounded,
              label: 'Actualizar',
              showText: showText,
              onPressed: onRefresh,
            ),
          ],
        );
      },
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.showText,
    required this.onPressed,
  });

  final AppPalette palette;
  final IconData icon;
  final String label;
  final bool showText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = showText
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          )
        : Icon(icon, color: Colors.white, size: 20);

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(showText ? 999 : 16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(showText ? 999 : 16),
          child: Container(
            height: 42,
            constraints: BoxConstraints(minWidth: showText ? 118 : 42),
            padding: EdgeInsets.symmetric(
              horizontal: showText ? 14 : 0,
              vertical: 8,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(showText ? 999 : 16),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.palette,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final AppPalette palette;
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: palette.secondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);

  final String label;
  final String value;
}

class _SimpleInfoList extends StatelessWidget {
  const _SimpleInfoList({required this.palette, required this.rows});

  final AppPalette palette;
  final List<_InfoItem> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 148,
                child: Text(
                  rows[i].label,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rows[i].value,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (i < rows.length - 1)
            Divider(
              height: 20,
              color: palette.cardBorder,
            ),
        ],
      ],
    );
  }
}

class _InventoryOverview extends StatelessWidget {
  const _InventoryOverview({
    required this.palette,
    required this.total,
    required this.records,
    required this.sucursalNombre,
  });

  final AppPalette palette;
  final double total;
  final int records;
  final String sucursalNombre;

  @override
  Widget build(BuildContext context) {
    return _SimpleInfoList(
      palette: palette,
      rows: [
        _InfoItem('Inventario actual', '${_number(total)} unidades'),
        _InfoItem('Sucursal', sucursalNombre),
        _InfoItem('Registros', '$records movimientos'),
      ],
    );
  }
}

class _ActivePriceSummary extends StatelessWidget {
  const _ActivePriceSummary({required this.palette, required this.price});

  final AppPalette palette;
  final PreciosResponseModel price;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _money(price.precValorVenta),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Precio de venta activo',
          style: TextStyle(
            color: palette.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        _SimpleInfoList(
          palette: palette,
          rows: [
            _InfoItem('Precio de compra', _money(price.precValorCompra)),
            _InfoItem('Impuesto', _taxSummary(price)),
            _InfoItem('Fecha de inicio', _date(price.precFechaInicia)),
            _InfoItem('Fecha de finalización', _date(price.precFechaFinaliza)),
          ],
        ),
      ],
    );
  }
}

class _PriceHistoryTable extends StatelessWidget {
  const _PriceHistoryTable({required this.palette, required this.prices});

  final AppPalette palette;
  final List<PreciosResponseModel> prices;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              for (final price in prices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MobileTableCard(
                    palette: palette,
                    title: _money(price.precValorVenta),
                    trailing: _StatusPill(
                      text: price.precEstado == 1 ? 'Activo' : 'Inactivo',
                      active: price.precEstado == 1,
                      palette: palette,
                    ),
                    rows: [
                      _InfoItem('Precio compra', _money(price.precValorCompra)),
                      _InfoItem('Impuesto', _taxSummary(price)),
                      _InfoItem('Inicia', _date(price.precFechaInicia)),
                      _InfoItem('Finaliza', _date(price.precFechaFinaliza)),
                    ],
                  ),
                ),
            ],
          );
        }

        return _DesktopTable(
          palette: palette,
          headers: const ['Estado', 'Venta', 'Compra', 'Impuesto', 'Inicia', 'Finaliza'],
          rows: prices.map((price) {
            return [
              _StatusPill(
                text: price.precEstado == 1 ? 'Activo' : 'Inactivo',
                active: price.precEstado == 1,
                palette: palette,
              ),
              Text(
                _money(price.precValorVenta),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                _money(price.precValorCompra),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                _taxSummary(price),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                _date(price.precFechaInicia),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
              Text(
                _date(price.precFechaFinaliza),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ];
          }).toList(),
        );
      },
    );
  }
}

class _InventoryHistoryTable extends StatelessWidget {
  const _InventoryHistoryTable({
    required this.palette,
    required this.items,
    required this.sucursalNombre,
  });

  final AppPalette palette;
  final List<InventarioResponseModel> items;
  final String sucursalNombre;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MobileTableCard(
                    palette: palette,
                    title: '${_number(item.invtCantidad)} unidades',
                    rows: [
                      _InfoItem('Fecha', _date(item.invtFecha)),
                      _InfoItem('Sucursal', sucursalNombre),
                      _InfoItem('Registro', '#${item.invtId ?? '-'}'),
                    ],
                  ),
                ),
            ],
          );
        }

        return _DesktopTable(
          palette: palette,
          headers: const ['Cantidad', 'Fecha', 'Sucursal', 'Registro'],
          rows: items.map((item) {
            return [
              Text(
                '${_number(item.invtCantidad)} unidades',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                _date(item.invtFecha),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
              Text(
                sucursalNombre,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                '#${item.invtId ?? '-'}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ];
          }).toList(),
        );
      },
    );
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({
    required this.palette,
    required this.headers,
    required this.rows,
  });

  final AppPalette palette;
  final List<String> headers;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: palette.darkBackground
                ? Colors.white.withOpacity(0.03)
                : palette.background.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.cardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: {
                    for (var i = 0; i < headers.length; i++) i: const FlexColumnWidth(),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: palette.darkBackground
                            ? Colors.white.withOpacity(0.05)
                            : palette.surface.withOpacity(0.90),
                      ),
                      children: [
                        for (final header in headers)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Text(
                              header,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    for (final row in rows)
                      TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: palette.cardBorder),
                          ),
                        ),
                        children: [
                          for (final cell in row)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: cell,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileTableCard extends StatelessWidget {
  const _MobileTableCard({
    required this.palette,
    required this.title,
    required this.rows,
    this.trailing,
  });

  final AppPalette palette;
  final String title;
  final List<_InfoItem> rows;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.darkBackground
            ? Colors.white.withOpacity(0.04)
            : palette.background.withOpacity(0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          _SimpleInfoList(palette: palette, rows: rows),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.active,
    required this.palette,
  });

  final String text;
  final bool active;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final background = active
        ? palette.success.withOpacity(0.14)
        : palette.warning.withOpacity(0.15);
    final foreground = active ? palette.success : palette.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: foreground,
        ),
      ),
    );
  }
}

class _EmptyMiniMessage extends StatelessWidget {
  const _EmptyMiniMessage({required this.palette, required this.text});

  final AppPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.darkBackground
            ? Colors.white.withOpacity(0.04)
            : palette.background.withOpacity(0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final logoValue = (value ?? '').trim();
    if (logoValue.isEmpty) return const SizedBox.shrink();

    final placeholder = Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: const Icon(Icons.verified_rounded, color: Colors.white, size: 26),
    );

    if (logoValue.startsWith('data:image')) {
      final commaIndex = logoValue.indexOf(',');
      if (commaIndex > -1) {
        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(
              base64Decode(logoValue.substring(commaIndex + 1)),
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
          );
        } catch (_) {
          return placeholder;
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        logoValue,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.value, required this.size});

  final String? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageValue = (value ?? '').trim();
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: const Icon(Icons.image_rounded, color: Colors.white, size: 36),
    );

    if (imageValue.isEmpty) return placeholder;

    if (imageValue.startsWith('data:image')) {
      final commaIndex = imageValue.indexOf(',');
      if (commaIndex > -1) {
        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.memory(
              base64Decode(imageValue.substring(commaIndex + 1)),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
          );
        } catch (_) {
          return placeholder;
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.network(
        imageValue,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}


String _taxSummary(PreciosResponseModel price) {
  if ((price.precAplicaImpuesto ?? 0) != 1) return 'No aplica';
  final percentage = price.precPorcentajeImpuesto == null ? '-' : '${_formatNumber(price.precPorcentajeImpuesto!)}%';
  final value = price.precValorImpuesto == null ? '' : ' · ${_money(price.precValorImpuesto)}';
  return '$percentage$value';
}

String _formatNumber(num value) {
  final asDouble = value.toDouble();
  if (asDouble % 1 == 0) return asDouble.toInt().toString();
  return asDouble.toStringAsFixed(2);
}

String _value(String? value, {String fallback = '-'}) {
  final text = (value ?? '').trim();
  return text.isEmpty ? fallback : text;
}

String _money(num? value) {
  if (value == null) return '-';
  return NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  ).format(value);
}

String _number(num? value) {
  if (value == null) return '0';
  return NumberFormat.decimalPattern('es_CO').format(value);
}

String _date(String? value) {
  if (value == null || value.trim().isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('dd/MM/yyyy HH:mm', 'es_CO').format(parsed);
}

T? _firstOrNull<T>(Iterable<T> items) {
  final iterator = items.iterator;
  if (!iterator.moveNext()) return null;
  return iterator.current;
}
