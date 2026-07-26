
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
    final sale = precioActivo?.precValorVenta?.toDouble() ?? 0.0;
    final purchaseTotal = precioActivo?.precValorCompra?.toDouble() ?? 0.0;
    final purchaseUnit = _unitPurchaseCost(producto, purchaseTotal);
    final utility = sale - purchaseUnit;
    final margin = sale > 0 ? (utility / sale) * 100 : 0.0;
    final purchaseQuantity = producto.prodCantidadCompra ?? 0;
    final purchaseByPackage =
        (producto.prodCompraPorCantidad ?? 0) == 1 && purchaseQuantity > 0;
    final purchasePresentation = _value(
      producto.prodPresentacionCompra,
      fallback: 'Presentación',
    );
    final purchaseSummary = purchaseByPackage
        ? '$purchasePresentation x ${_number(purchaseQuantity)}'
        : 'Compra por unidad';
    final expiration = _expirationSummary(
      producto.prodFechaVencimiento,
      palette,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PosProductSummary(
          palette: palette,
          producto: producto,
          marca: marca,
          tipo: tipo,
          price: precioActivo,
          inventory: cantidadInventario,
          purchaseUnit: purchaseUnit,
          utility: utility,
          margin: margin,
          purchaseSummary: purchaseSummary,
          expiration: expiration,
          sucursalNombre: sucursalNombre,
        ),
        const SizedBox(height: 12),
        _PosExpandableSection(
          palette: palette,
          icon: Icons.inventory_2_rounded,
          title: 'Inventario y movimientos',
          subtitle:
              '${_number(cantidadInventario)} unidades · ${inventarios.length} registros',
          child: inventarios.isEmpty
              ? _EmptyMiniMessage(
                  palette: palette,
                  text: 'Todavía no hay movimientos de inventario.',
                )
              : _InventoryHistoryTable(
                  palette: palette,
                  items: inventarios,
                  sucursalNombre: sucursalNombre,
                ),
        ),
        const SizedBox(height: 12),
        _PosExpandableSection(
          palette: palette,
          icon: Icons.history_rounded,
          title: 'Historial de precios',
          subtitle: precios.isEmpty
              ? 'Sin registros'
              : '${precios.length} precios registrados',
          child: precios.isEmpty
              ? _EmptyMiniMessage(
                  palette: palette,
                  text: 'No hay historial de precios registrado.',
                )
              : _PriceHistoryTable(
                  palette: palette,
                  prices: precios,
                ),
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            color: palette.secondary,
            backgroundColor: palette.background,
          ),
        ],
      ],
    );
  }
}

class _PosProductSummary extends StatelessWidget {
  const _PosProductSummary({
    required this.palette,
    required this.producto,
    required this.marca,
    required this.tipo,
    required this.price,
    required this.inventory,
    required this.purchaseUnit,
    required this.utility,
    required this.margin,
    required this.purchaseSummary,
    required this.expiration,
    required this.sucursalNombre,
  });

  final AppPalette palette;
  final ProductosResponseModel producto;
  final MarcasResponseModel? marca;
  final TiposProductoResponseModel? tipo;
  final PreciosResponseModel? price;
  final double inventory;
  final double purchaseUnit;
  final double utility;
  final double margin;
  final String purchaseSummary;
  final _ExpirationSummary expiration;
  final String sucursalNombre;

  @override
  Widget build(BuildContext context) {
    final hasPrice = price != null;
    final positive = utility >= 0;
    final profitColor = positive ? palette.success : Colors.redAccent;
    final stockColor = inventory <= 0
        ? Colors.redAccent
        : inventory <= 5
            ? palette.warning
            : palette.success;

    final leftRows = [
      _PosDetailData(
        icon: Icons.sell_rounded,
        label: 'Marca',
        value: marca?.mrcaNombre ?? 'Sin marca',
      ),
      _PosDetailData(
        icon: Icons.category_rounded,
        label: 'Tipo',
        value: tipo?.tpprNombre ?? 'Sin tipo',
      ),
      _PosDetailData(
        icon: Icons.storefront_rounded,
        label: 'Sucursal',
        value: sucursalNombre,
      ),
    ];
    final rightRows = [
      _PosDetailData(
        icon: Icons.inventory_2_outlined,
        label: 'Forma de compra',
        value: purchaseSummary,
      ),
      _PosDetailData(
        icon: expiration.icon,
        label: 'Vencimiento',
        value: expiration.label,
        color: expiration.color,
      ),
      _PosDetailData(
        icon: Icons.update_rounded,
        label: 'Última actualización',
        value: _date(producto.prodFechaCambio),
      ),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(
              palette.darkBackground ? 0.96 : 0.99,
            ),
            borderRadius: BorderRadius.circular(palette.radius(26)),
            boxShadow: [
              BoxShadow(
                color: palette.cardShadow.withOpacity(0.38),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(palette.radius(26)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: palette.secondary.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: palette.secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen del producto',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Información principal para operar y vender.',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(
                        text: hasPrice ? 'Activo' : 'Sin precio',
                        active: hasPrice,
                        palette: palette,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 620;
                          final priceValue = _PosPrimaryValue(
                            palette: palette,
                            icon: Icons.payments_rounded,
                            label: 'Precio de venta',
                            value: hasPrice
                                ? _money(price!.precValorVenta)
                                : 'Sin precio',
                            color: palette.secondary,
                          );
                          final stockValue = _PosPrimaryValue(
                            palette: palette,
                            icon: Icons.inventory_rounded,
                            label: 'Stock disponible',
                            value: '${_number(inventory)} unidades',
                            color: stockColor,
                          );

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: palette.background.withOpacity(
                                palette.darkBackground ? 0.48 : 0.72,
                              ),
                              borderRadius: BorderRadius.circular(
                                palette.radius(20),
                              ),
                            ),
                            child: compact
                                ? Column(
                                    children: [
                                      priceValue,
                                      const SizedBox(height: 12),
                                      stockValue,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: priceValue),
                                      const SizedBox(width: 18),
                                      Expanded(child: stockValue),
                                    ],
                                  ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 720;
                          final left = _PosDetailList(
                            palette: palette,
                            rows: leftRows,
                          );
                          final right = _PosDetailList(
                            palette: palette,
                            rows: rightRows,
                          );

                          if (compact) {
                            return Column(
                              children: [
                                left,
                                const SizedBox(height: 8),
                                right,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: left),
                              const SizedBox(width: 10),
                              Expanded(child: right),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: profitColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(
                            palette.radius(18),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 560;
                            final items = [
                              _PosProfitValue(
                                palette: palette,
                                label: 'Costo unitario',
                                value: hasPrice ? _money(purchaseUnit) : '-',
                              ),
                              _PosProfitValue(
                                palette: palette,
                                label: 'Utilidad',
                                value: hasPrice ? _money(utility) : '-',
                                color: profitColor,
                              ),
                              _PosProfitValue(
                                palette: palette,
                                label: 'Margen',
                                value: hasPrice ? '${_number(margin)}%' : '-',
                                color: profitColor,
                              ),
                            ];

                            if (compact) {
                              return Column(
                                children: [
                                  for (var index = 0;
                                      index < items.length;
                                      index++) ...[
                                    items[index],
                                    if (index != items.length - 1)
                                      const SizedBox(height: 10),
                                  ],
                                ],
                              );
                            }
                            return Row(
                              children: [
                                for (var index = 0;
                                    index < items.length;
                                    index++) ...[
                                  Expanded(child: items[index]),
                                  if (index != items.length - 1)
                                    const SizedBox(width: 12),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      if (hasPrice) ...[
                        const SizedBox(height: 4),
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(top: 2),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            iconColor: palette.secondary,
                            collapsedIconColor: palette.textSecondary,
                            title: Text(
                              'Vigencia del precio',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            children: [
                              _SimpleInfoList(
                                palette: palette,
                                rows: [
                                  _InfoItem('Impuesto', _taxSummary(price!)),
                                  _InfoItem(
                                    'Inicio',
                                    _date(price!.precFechaInicia),
                                  ),
                                  _InfoItem(
                                    'Finaliza',
                                    _date(price!.precFechaFinaliza),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosPrimaryValue extends StatelessWidget {
  const _PosPrimaryValue({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final AppPalette palette;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PosDetailData {
  const _PosDetailData({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
}

class _PosDetailList extends StatelessWidget {
  const _PosDetailList({required this.palette, required this.rows});

  final AppPalette palette;
  final List<_PosDetailData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(
          palette.darkBackground ? 0.34 : 0.58,
        ),
        borderRadius: BorderRadius.circular(palette.radius(18)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _PosDetailRow(palette: palette, data: rows[index]),
            if (index != rows.length - 1)
              Divider(
                height: 1,
                color: palette.textSecondary.withOpacity(0.10),
              ),
          ],
        ],
      ),
    );
  }
}

class _PosDetailRow extends StatelessWidget {
  const _PosDetailRow({required this.palette, required this.data});

  final AppPalette palette;
  final _PosDetailData data;

  @override
  Widget build(BuildContext context) {
    final color = data.color ?? palette.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(data.icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data.label,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              data.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosProfitValue extends StatelessWidget {
  const _PosProfitValue({
    required this.palette,
    required this.label,
    required this.value,
    this.color,
  });

  final AppPalette palette;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: color ?? palette.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _PosMetric extends StatelessWidget {
  const _PosMetric({
    required this.palette,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final AppPalette palette;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(
          palette.darkBackground ? 0.54 : 0.76,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosInfoChip extends StatelessWidget {
  const _PosInfoChip({
    required this.palette,
    required this.icon,
    required this.text,
    this.color,
  });

  final AppPalette palette;
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: foreground.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosExpandableSection extends StatelessWidget {
  const _PosExpandableSection({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.99),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withOpacity(0.32),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: palette.secondary,
            collapsedIconColor: palette.textSecondary,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: palette.secondary, size: 20),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
            children: [child],
          ),
        ),
      ),
    );
  }
}

class _ProductInformationCard extends StatelessWidget {
  const _ProductInformationCard({
    required this.palette,
    required this.producto,
    required this.marca,
    required this.tipo,
    required this.sucursalNombre,
  });

  final AppPalette palette;
  final ProductosResponseModel producto;
  final MarcasResponseModel? marca;
  final TiposProductoResponseModel? tipo;
  final String sucursalNombre;

  @override
  Widget build(BuildContext context) {
    final purchaseQuantity = producto.prodCantidadCompra ?? 0;
    final purchaseByPackage =
        (producto.prodCompraPorCantidad ?? 0) == 1 && purchaseQuantity > 0;
    final purchasePresentation = _value(
      producto.prodPresentacionCompra,
      fallback: 'Presentación',
    );
    final purchaseSummary = purchaseByPackage
        ? '$purchasePresentation x ${_number(purchaseQuantity)}'
        : 'Por unidad';
    final expiration = _expirationSummary(
      producto.prodFechaVencimiento,
      palette,
    );

    return _SectionCard(
      palette: palette,
      title: 'Datos del producto',
      icon: Icons.info_outline_rounded,
      child: _SimpleInfoList(
        palette: palette,
        rows: [
          _InfoItem('Marca', marca?.mrcaNombre ?? 'Sin marca'),
          _InfoItem('Tipo', tipo?.tpprNombre ?? 'Sin tipo'),
          _InfoItem('Sucursal', sucursalNombre),
          _InfoItem('Compra', purchaseSummary),
          _InfoItem('Vencimiento', expiration.label),
          _InfoItem('Actualizado', _date(producto.prodFechaCambio)),
        ],
      ),
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
            ? palette.warning
            : palette.success;
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
                    color: Color.alphaBlend(
                      stockColor.withOpacity(palette.darkBackground ? 0.22 : 0.14),
                      palette.surface,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: stockColor.withOpacity(
                        palette.darkBackground ? 0.70 : 0.50,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: stockColor),
                      const SizedBox(width: 5),
                      Text(
                        stockText,
                        style: TextStyle(
                          color: palette.darkBackground
                              ? Color.lerp(stockColor, Colors.white, 0.20)
                              : Color.lerp(
                                  stockColor,
                                  const Color(0xFF0F172A),
                                  stockColor.computeLuminance() > 0.36 ? 0.42 : 0.14,
                                ),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          final classification = [
            marca?.mrcaNombre,
            tipo?.tpprNombre,
          ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' · ');

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
                    _HeaderActions(
                      palette: palette,
                      onEdit: onEdit,
                      onRefresh: onRefresh,
                    ),
                  ],
                ],
              ),
              if (classification.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  classification,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderChip(
                    icon: Icons.inventory_2_rounded,
                    text: '${_number(cantidadInventario)} unidades',
                  ),
                  if (precioActivo != null)
                    _HeaderChip(
                      icon: Icons.payments_rounded,
                      text: _money(precioActivo!.precValorVenta),
                    ),
                  _HeaderChip(
                    icon: Icons.storefront_rounded,
                    text: sucursalNombre,
                  ),
                ],
              ),
              if (compact) ...[
                const SizedBox(height: 12),
                _HeaderActions(
                  palette: palette,
                  onEdit: onEdit,
                  onRefresh: onRefresh,
                ),
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
  const _ActivePriceSummary({
    required this.palette,
    required this.price,
    required this.producto,
    required this.unitPurchaseCost,
  });

  final AppPalette palette;
  final PreciosResponseModel price;
  final ProductosResponseModel producto;
  final double unitPurchaseCost;

  @override
  Widget build(BuildContext context) {
    final purchaseByPackage =
        (producto.prodCompraPorCantidad ?? 0) == 1 &&
            (producto.prodCantidadCompra ?? 0) > 0;
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
            _InfoItem(
              purchaseByPackage ? 'Costo del empaque' : 'Precio de compra',
              _money(price.precValorCompra),
            ),
            if (purchaseByPackage)
              _InfoItem('Costo unitario calculado', _money(unitPurchaseCost)),
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



double _unitPurchaseCost(
  ProductosResponseModel producto,
  num? totalPurchase,
) {
  final total = totalPurchase?.toDouble() ?? 0;
  final quantity = producto.prodCantidadCompra ?? 0;
  final purchasedByPackage =
      (producto.prodCompraPorCantidad ?? 0) == 1 && quantity > 0;
  if (!purchasedByPackage) return total;
  return total / quantity;
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
