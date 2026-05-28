import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/mesero_remote_datasource.dart';
import '../../data/models/mesero_models.dart';
import '../providers/mesero_tab_provider.dart';


String _cuentaNombreVisible(MeseroCuentaModel? cuenta) {
  final descripcion = (cuenta?.descripcion ?? '').trim();
  if (descripcion.isNotEmpty) return descripcion;
  final numero = cuenta?.numero;
  if (numero != null) return 'Cuenta $numero';
  final cuentaId = cuenta?.cuentaId;
  if (cuentaId != null) return 'Cuenta $cuentaId';
  return 'Cuenta';
}

String _cuentaEtiquetaVisible(MeseroCuentaModel? cuenta) {
  return 'Cuenta: ${_cuentaNombreVisible(cuenta)}';
}

bool _cuentaEstaVacia(MeseroCuentaModel cuenta) {
  final propina = cuenta.propina ?? 0;
  final total = cuenta.total ?? 0;
  return cuenta.productos.isEmpty && cuenta.pagos.isEmpty && propina.abs() < 0.01 && total.abs() < 0.01;
}

double _parseCurrencyInput(String value) {
  final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}

String _formatCurrencyInputAmount(double value) {
  if (value <= 0) return '';

  final hasDecimals = (value - value.truncateToDouble()).abs() > 0.009;
  final fixed = hasDecimals
      ? value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : value.toStringAsFixed(0);
  final parts = fixed.split('.');
  final integer = _formatIntegerWithThousands(parts.first);
  if (parts.length == 1 || parts.last.isEmpty) return integer;
  return '$integer,${parts.last}';
}

String _formatIntegerWithThousands(String digits) {
  final clean = digits.replaceAll(RegExp(r'\D'), '');
  if (clean.isEmpty) return '';

  final buffer = StringBuffer();
  for (var index = 0; index < clean.length; index++) {
    final remaining = clean.length - index;
    buffer.write(clean[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}

class _CurrencyThousandsInputFormatter extends TextInputFormatter {
  const _CurrencyThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = _formatRawCurrencyText(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatRawCurrencyText(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';

    final commaIndex = raw.indexOf(',');
    final hasDecimal = commaIndex >= 0;
    final integerRaw = hasDecimal ? raw.substring(0, commaIndex) : raw;
    final decimalRaw = hasDecimal ? raw.substring(commaIndex + 1) : '';

    final integerDigits = integerRaw.replaceAll(RegExp(r'\D'), '');
    final decimalDigits = decimalRaw.replaceAll(RegExp(r'\D'), '');
    final formattedInteger = _formatIntegerWithThousands(integerDigits);

    if (!hasDecimal) return formattedInteger;
    if (formattedInteger.isEmpty && decimalDigits.isEmpty) return '';

    final decimals = decimalDigits.length > 2 ? decimalDigits.substring(0, 2) : decimalDigits;
    return '$formattedInteger,$decimals';
  }
}

const List<TextInputFormatter> _currencyInputFormatters = [
  _CurrencyThousandsInputFormatter(),
];

class MeseroPage extends ConsumerStatefulWidget {
  const MeseroPage({super.key, this.initialMode});

  /// Pestaña inicial usada solo al entrar por una ruta directa antigua
  /// como `/mesero/productos` o `/mesero/resumen`.
  ///
  /// Cuando se entra por `/mesero`, se conserva la pestaña actual del provider
  /// para que la barra inferior no recree la página ni recargue toda la información.
  final MeseroPageMode? initialMode;

  @override
  ConsumerState<MeseroPage> createState() => _MeseroPageState();
}

class _MeseroPageState extends ConsumerState<MeseroPage> {
  late MeseroRemoteDataSource _dataSource;
  late Future<void> _future;
  List<MeseroMesaResumenModel> _mesas = const [];
  List<MeseroProductoModel> _productos = const [];
  List<MeseroMedioPagoModel> _mediosPago = const [];
  MeseroVentaModel? _ventaActiva;
  bool _mostrandoDetalleVenta = false;
  bool _mostrandoPestanaAgregarProductos = false;
  bool _irACuentaDespuesAgregarProducto = false;
  int? _cuentaSeleccionadaId;
  bool _processing = false;
  final TextEditingController _productoFiltroController = TextEditingController();
  String _productoFiltro = '';
  String? _tipoProductoFiltro;
  String? _marcaProductoFiltro;
  Future<List<MeseroVentaModel>>? _historialVentasFuture;
  List<MeseroVentaModel> _historialVentas = const [];
  DateTime? _historialDiaFiltro;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _historialDiaFiltro = DateTime(today.year, today.month, today.day);
    _dataSource = MeseroRemoteDataSource(ref.read(apiClientProvider));
    final initialMode = widget.initialMode;
    if (initialMode != null) {
      ref.read(meseroSelectedModeProvider.notifier).state = initialMode;
    }
    _future = _load();
  }

  @override
  void dispose() {
    _productoFiltroController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MeseroPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initialMode = widget.initialMode;
    if (initialMode != null && oldWidget.initialMode != initialMode) {
      ref.read(meseroSelectedModeProvider.notifier).state = initialMode;
    }
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _dataSource.listarMesas(),
      _dataSource.listarProductos(),
      _dataSource.listarMediosPago(),
    ]);
    _mesas = results[0] as List<MeseroMesaResumenModel>;
    _productos = results[1] as List<MeseroProductoModel>;
    _mediosPago = results[2] as List<MeseroMedioPagoModel>;
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<List<MeseroVentaModel>> _cargarHistorialVentas() async {
    final ventas = await _dataSource.historialVentas();
    _historialVentas = ventas;
    return ventas;
  }

  Future<void> _reloadHistorialVentas() async {
    final future = _cargarHistorialVentas();
    setState(() {
      _historialVentasFuture = future;
    });
    await future;
  }

  String _productoTipoLabel(MeseroProductoModel producto) {
    final nombre = (producto.tipoProductoNombre ?? '').trim();
    if (nombre.isNotEmpty) return nombre;
    final id = producto.tipoProductoId;
    return id == null ? 'Sin tipo' : 'Tipo $id';
  }

  String _productoMarcaLabel(MeseroProductoModel producto) {
    final nombre = (producto.marcaNombre ?? '').trim();
    if (nombre.isNotEmpty) return nombre;
    final id = producto.marcaId;
    return id == null ? 'Sin marca' : 'Marca $id';
  }

  List<String> get _tiposProductoDisponibles {
    final values = _productos.map(_productoTipoLabel).where((value) => value.trim().isNotEmpty).toSet().toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get _marcasProductoDisponibles {
    final values = _productos.map(_productoMarcaLabel).where((value) => value.trim().isNotEmpty).toSet().toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }


  List<MeseroProductoModel> get _productosFiltrados {
    final query = _productoFiltro.trim().toLowerCase();
    final tipo = (_tipoProductoFiltro ?? '').trim().toLowerCase();
    final marca = (_marcaProductoFiltro ?? '').trim().toLowerCase();

    return _productos.where((producto) {
      final tipoProducto = _productoTipoLabel(producto);
      final marcaProducto = _productoMarcaLabel(producto);
      final nombre = (producto.nombre ?? '').toLowerCase();
      final descripcion = (producto.descripcion ?? '').toLowerCase();
      final id = (producto.prodId?.toString() ?? '').toLowerCase();
      final tipoId = (producto.tipoProductoId?.toString() ?? '').toLowerCase();
      final marcaId = (producto.marcaId?.toString() ?? '').toLowerCase();
      final precio = (producto.precioVenta?.toString() ?? '').toLowerCase();

      final matchesText = query.isEmpty ||
          nombre.contains(query) ||
          descripcion.contains(query) ||
          id.contains(query) ||
          tipoProducto.toLowerCase().contains(query) ||
          marcaProducto.toLowerCase().contains(query) ||
          tipoId.contains(query) ||
          marcaId.contains(query) ||
          precio.contains(query);
      final matchesTipo = tipo.isEmpty || tipoProducto.toLowerCase() == tipo;
      final matchesMarca = marca.isEmpty || marcaProducto.toLowerCase() == marca;
      return matchesText && matchesTipo && matchesMarca;
    }).toList();
  }


  bool _mismoProductoPedido(MeseroProductoModel producto, MeseroDetalleProductoModel detalle) {
    final productoId = producto.prodId;
    final detalleProductoId = detalle.productoId;
    if (productoId != null && detalleProductoId != null) {
      return productoId == detalleProductoId;
    }

    final productoNombre = (producto.nombre ?? '').trim().toLowerCase();
    final detalleNombre = (detalle.productoNombre ?? '').trim().toLowerCase();
    return productoNombre.isNotEmpty && productoNombre == detalleNombre;
  }

  double _cantidadPedidaProductoEnVenta(MeseroProductoModel producto) {
    final venta = _ventaActiva;
    if (venta == null) return 0;

    return venta.cuentas.fold<double>(0, (total, cuenta) {
      return total + _cantidadPedidaProductoEnCuenta(cuenta, producto);
    });
  }

  double _cantidadPedidaProductoEnCuenta(MeseroCuentaModel cuenta, MeseroProductoModel producto) {
    return cuenta.productos.fold<double>(0, (total, detalle) {
      if (!_mismoProductoPedido(producto, detalle)) return total;
      return total + (detalle.cantidad ?? 0).toDouble();
    });
  }

  List<MeseroProductoModel> _productosOrdenadosPorPedido(List<MeseroProductoModel> productos, MeseroCuentaModel cuenta) {
    final ordenados = List<MeseroProductoModel>.from(productos);
    ordenados.sort((a, b) {
      final cantidadVentaA = _cantidadPedidaProductoEnVenta(a);
      final cantidadVentaB = _cantidadPedidaProductoEnVenta(b);
      final compareVenta = cantidadVentaB.compareTo(cantidadVentaA);
      if (compareVenta != 0) return compareVenta;

      final cantidadCuentaA = _cantidadPedidaProductoEnCuenta(cuenta, a);
      final cantidadCuentaB = _cantidadPedidaProductoEnCuenta(cuenta, b);
      final compareCuenta = cantidadCuentaB.compareTo(cantidadCuentaA);
      if (compareCuenta != 0) return compareCuenta;

      final nombreA = (a.nombre ?? 'Producto ${a.prodId ?? ''}').toLowerCase();
      final nombreB = (b.nombre ?? 'Producto ${b.prodId ?? ''}').toLowerCase();
      return nombreA.compareTo(nombreB);
    });
    return ordenados;
  }

  Widget _buildProductoFiltro({String hintText = 'Buscar producto por nombre, descripción, código, tipo, marca o precio'}) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final tipos = _tiposProductoDisponibles;
    final marcas = _marcasProductoDisponibles;
    final hayFiltros = _productoFiltro.trim().isNotEmpty ||
        (_tipoProductoFiltro ?? '').trim().isNotEmpty ||
        (_marcaProductoFiltro ?? '').trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final searchField = TextField(
            controller: _productoFiltroController,
            decoration: InputDecoration(
              labelText: 'Buscar productos',
              hintText: hintText,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _productoFiltro.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _productoFiltroController.clear();
                        setState(() => _productoFiltro = '');
                      },
                    ),
            ),
            onChanged: (value) => setState(() => _productoFiltro = value),
          );

          final tipoField = DropdownButtonFormField<String>(
            value: tipos.contains(_tipoProductoFiltro) ? _tipoProductoFiltro : null,
            decoration: const InputDecoration(
              labelText: 'Tipo de producto',
              prefixIcon: Icon(Icons.category_rounded),
            ),
            items: tipos.map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo))).toList(growable: false),
            onChanged: tipos.isEmpty ? null : (value) => setState(() => _tipoProductoFiltro = value),
          );

          final marcaField = DropdownButtonFormField<String>(
            value: marcas.contains(_marcaProductoFiltro) ? _marcaProductoFiltro : null,
            decoration: const InputDecoration(
              labelText: 'Marca',
              prefixIcon: Icon(Icons.local_offer_rounded),
            ),
            items: marcas.map((marca) => DropdownMenuItem(value: marca, child: Text(marca))).toList(growable: false),
            onChanged: marcas.isEmpty ? null : (value) => setState(() => _marcaProductoFiltro = value),
          );

          final clearButton = OutlinedButton.icon(
            onPressed: hayFiltros
                ? () {
                    _productoFiltroController.clear();
                    setState(() {
                      _productoFiltro = '';
                      _tipoProductoFiltro = null;
                      _marcaProductoFiltro = null;
                    });
                  }
                : null,
            icon: const Icon(Icons.filter_alt_off_rounded),
            label: const Text('Limpiar filtros'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 12),
                tipoField,
                const SizedBox(height: 12),
                marcaField,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: clearButton),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: tipoField),
                  const SizedBox(width: 12),
                  Expanded(child: marcaField),
                  const SizedBox(width: 12),
                  clearButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _normalizeRole(String value) => value
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

  bool _hasAnyRole(List<String> roleNames) {
    final rawRoles = ref.watch(authControllerProvider).roles;
    final normalizedRoles = rawRoles.map(_normalizeRole).toList(growable: false);
    final joinedRoles = normalizedRoles.join('_');
    final normalizedCandidates = roleNames.map(_normalizeRole).toList(growable: false);

    return normalizedRoles.any((role) {
          return normalizedCandidates.any((candidate) {
            return role == candidate ||
                role == 'ROLE_$candidate' ||
                role.endsWith('_$candidate') ||
                role.contains(candidate);
          });
        }) ||
        normalizedCandidates.any(joinedRoles.contains);
  }

  bool _isCajeroOperativo() {
    final rawRoles = ref.watch(authControllerProvider).roles;
    final joined = rawRoles.map(_normalizeRole).join('_');
    return _hasAnyRole(const [
          'CAJERO',
          'CAJERA',
          'CAJER',
          'CAJ',
          'CAJA',
          'CASHIER',
          'ROLE_CAJERO',
          'ROLE_CAJERA',
        ]) ||
        joined.contains('CAJER') ||
        joined.contains('CAJA');
  }

  bool _mesaInactiva(MeseroMesaResumenModel mesa) => (mesa.estadoMesa ?? '').toUpperCase() == 'INACTIVA';

  MeseroCuentaModel? _resolverCuentaSeleccionada(MeseroVentaModel venta) {
    for (final cuenta in venta.cuentas) {
      if (cuenta.cuentaId == _cuentaSeleccionadaId) {
        return cuenta;
      }
    }
    return venta.cuentas.isNotEmpty ? venta.cuentas.first : null;
  }

  Widget _buildAgregarProductosFloatingAction(MeseroCuentaModel cuenta) {
    final cuentaId = cuenta.cuentaId;
    final descripcion = (cuenta.descripcion ?? '').trim();
    final enabled = !_processing && cuentaId != null;

    return Positioned(
      right: 20,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: FloatingActionButton.extended(
          heroTag: 'mesero-agregar-productos-cuenta-${cuentaId ?? 'sin-cuenta'}',
          onPressed: enabled ? () => _abrirPestanaAgregarProductos(cuenta) : null,
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: Text(
            descripcion.isEmpty ? 'Agregar productos' : 'Agregar a ${_cuentaNombreVisible(cuenta)}',
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: enabled ? Theme.of(context).colorScheme.secondary : AppColors.textSecondary.withOpacity(0.45),
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawSelectedMode = ref.watch(meseroSelectedModeProvider);


    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const AppLoader(message: 'Cargando operación de mesas...');
        if (snapshot.hasError) return AppErrorView(message: snapshot.error.toString(), onRetry: _reload);

        final isCajero = _isCajeroOperativo();
        final selectedMode = !isCajero && rawSelectedMode == MeseroPageMode.historial
            ? MeseroPageMode.resumen
            : rawSelectedMode;

        if (selectedMode != rawSelectedMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(meseroSelectedModeProvider.notifier).state = selectedMode;
            }
          });
        }

        final content = RefreshIndicator(
          onRefresh: _reload,
          child: _buildScrollableContent(isCajero, selectedMode),
        );

        if (selectedMode == MeseroPageMode.mesas && _mostrandoDetalleVenta && _ventaActiva != null) {
          final cuenta = _resolverCuentaSeleccionada(_ventaActiva!);
          if (!_mostrandoPestanaAgregarProductos && cuenta?.cuentaId != null) {
            return Stack(
              children: [
                content,
                _buildAgregarProductosFloatingAction(cuenta!),
              ],
            );
          }
          return content;
        }

        if (!isCajero || selectedMode != MeseroPageMode.mesas) {
          return content;
        }

        return Stack(
          children: [
            content,
            Positioned(
              right: 22,
              bottom: 22,
              child: _CrearMesaFloatingButton(
                enabled: !_processing,
                onPressed: _crearMesa,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScrollableContent(bool isCajero, MeseroPageMode selectedMode) {
    return CustomScrollView(
      key: PageStorageKey<String>('mesero-operational-scroll-${selectedMode.name}'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(mode: selectedMode, isCajero: isCajero),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (selectedMode == MeseroPageMode.mesas) ...[
          if (_mostrandoDetalleVenta && _ventaActiva != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
                    final cuenta = _resolverCuentaSeleccionada(_ventaActiva!);
                    if (_mostrandoPestanaAgregarProductos && cuenta != null) {
                      return _buildPantallaAgregarProductos(_ventaActiva!, cuenta);
                    }
                    return _buildPantallaDetalleVenta(_ventaActiva!);
                  },
                ),
              ),
            )
          else
            ..._buildMesaGridSlivers(),
        ] else if (selectedMode == MeseroPageMode.productos)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            sliver: SliverToBoxAdapter(child: _buildProductosStandalone()),
          )
        else if (selectedMode == MeseroPageMode.historial)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            sliver: SliverToBoxAdapter(child: _buildHistorialVentas()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            sliver: SliverToBoxAdapter(child: _buildResumenMesas()),
          ),
        SliverToBoxAdapter(child: SizedBox(height: _mostrandoDetalleVenta ? 190 : 110)),
      ],
    );
  }

  List<Widget> _buildMesaGridSlivers() {
    if (_mesas.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 110),
            child: AppEmptyView(message: 'No hay mesas asociadas a tu sucursal.'),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        sliver: SliverToBoxAdapter(child: _MesasOperacionResumen(mesas: _mesas)),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.crossAxisExtent.isFinite
                ? constraints.crossAxisExtent
                : MediaQuery.sizeOf(context).width;
            final crossAxisCount = availableWidth >= 1100
                ? 4
                : availableWidth >= 720
                    ? 3
                    : availableWidth >= 460
                        ? 2
                        : 1;
            final childAspectRatio = availableWidth >= 1100
                ? 1.72
                : availableWidth >= 720
                    ? 1.62
                    : availableWidth >= 460
                        ? 1.55
                        : 2.05;

            return SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final mesa = _mesas[index];
                  final isCajero = _isCajeroOperativo();
                  final inactiva = _mesaInactiva(mesa);
                  return _MesaCard(
                    mesa: mesa,
                    canEdit: !inactiva || isCajero,
                    canDelete: isCajero,
                    onEdit: () => _editarMesa(mesa, isCajero: isCajero),
                    onDelete: isCajero ? () => _eliminarMesa(mesa) : null,
                    onTap: inactiva ? null : () => _abrirVenta(mesa),
                  );
                },
                childCount: _mesas.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: childAspectRatio,
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildMesaGrid() {
    if (_mesas.isEmpty) {
      return const AppEmptyView(message: 'No hay mesas asociadas a tu sucursal.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final crossAxisCount = availableWidth >= 1100
            ? 4
            : availableWidth >= 720
                ? 3
                : availableWidth >= 460
                    ? 2
                    : 1;
        final childAspectRatio = availableWidth >= 1100
            ? 1.72
            : availableWidth >= 720
                ? 1.62
                : availableWidth >= 460
                    ? 1.55
                    : 2.05;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MesasOperacionResumen(mesas: _mesas),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _mesas.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final mesa = _mesas[index];
                final isCajero = _isCajeroOperativo();
                final inactiva = _mesaInactiva(mesa);
                return _MesaCard(
                  mesa: mesa,
                  canEdit: !inactiva || isCajero,
                  canDelete: isCajero,
                  onEdit: () => _editarMesa(mesa, isCajero: isCajero),
                  onDelete: isCajero ? () => _eliminarMesa(mesa) : null,
                  onTap: inactiva ? null : () => _abrirVenta(mesa),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildResumenMesas() {
    if (_mesas.isEmpty) return const AppEmptyView(message: 'No hay mesas para resumir.');
    final total = _mesas.fold<double>(0, (sum, item) => sum + (item.totalPendiente ?? 0));
    final abiertas = _mesas.where((m) => m.ventaId != null).length;
    final inactivas = _mesas.where(_mesaInactiva).length;
    final libres = _mesas.length - abiertas - inactivas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryBanner(total: total, totalMesas: _mesas.length, mesasAbiertas: abiertas, mesasLibres: libres < 0 ? 0 : libres),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            if (compact) {
              return Column(
                children: [
                  for (final mesa in _mesas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ResumenMesaTile(
                        mesa: mesa,
                        onTap: _mesaInactiva(mesa) ? null : () => _abrirVenta(mesa),
                      ),
                    ),
                ],
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final mesa in _mesas)
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: _ResumenMesaTile(
                      mesa: mesa,
                      onTap: _mesaInactiva(mesa) ? null : () => _abrirVenta(mesa),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }


  DateTime? _parseFechaVentaHistorial(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final isoText = text.contains(' ') ? text.replaceFirst(' ', 'T') : text;
    final parsedIso = DateTime.tryParse(isoText);
    if (parsedIso != null) {
      return DateTime(parsedIso.year, parsedIso.month, parsedIso.day);
    }

    final dmyMatch = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})').firstMatch(text);
    if (dmyMatch != null) {
      final day = int.tryParse(dmyMatch.group(1)!);
      final month = int.tryParse(dmyMatch.group(2)!);
      final year = int.tryParse(dmyMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    final ymdMatch = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})').firstMatch(text);
    if (ymdMatch != null) {
      final year = int.tryParse(ymdMatch.group(1)!);
      final month = int.tryParse(ymdMatch.group(2)!);
      final day = int.tryParse(ymdMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  bool _esMismoDia(DateTime first, DateTime second) =>
      first.year == second.year && first.month == second.month && first.day == second.day;

  DateTime _soloFecha(DateTime value) => DateTime(value.year, value.month, value.day);

  String _formatearDiaHistorial(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> _seleccionarDiaHistorial() async {
    final today = _soloFecha(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _historialDiaFiltro ?? today,
      firstDate: DateTime(today.year - 5, 1, 1),
      lastDate: DateTime(today.year + 1, 12, 31),
      helpText: 'Filtrar historial por día',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );

    if (!mounted || picked == null) return;
    setState(() {
      _historialDiaFiltro = _soloFecha(picked);
    });
  }

  void _filtrarHistorialHoy() {
    setState(() {
      _historialDiaFiltro = _soloFecha(DateTime.now());
    });
  }

  void _limpiarFiltroHistorial() {
    setState(() {
      _historialDiaFiltro = null;
    });
  }

  Widget _buildHistorialDiaFilterBar({required int totalVentas, required int ventasMostradas}) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final filtro = _historialDiaFiltro;
    final filtroActivo = filtro != null;
    final label = filtroActivo ? _formatearDiaHistorial(filtro) : 'Todos los días';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _SmallInfoPill(
            icon: Icons.calendar_month_rounded,
            text: filtroActivo ? 'Día: $label' : 'Filtro por día',
          ),
          _SmallInfoPill(
            icon: Icons.receipt_long_rounded,
            text: '$ventasMostradas de $totalVentas ventas',
          ),
          OutlinedButton.icon(
            onPressed: _seleccionarDiaHistorial,
            icon: const Icon(Icons.event_rounded),
            label: Text(filtroActivo ? 'Cambiar día' : 'Seleccionar día'),
          ),
          TextButton.icon(
            onPressed: _filtrarHistorialHoy,
            icon: const Icon(Icons.today_rounded),
            label: const Text('Hoy'),
          ),
          if (filtroActivo)
            TextButton.icon(
              onPressed: _limpiarFiltroHistorial,
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Quitar filtro'),
            ),
        ],
      ),
    );
  }

  Widget _buildHistorialVentas() {
    _historialVentasFuture ??= _cargarHistorialVentas();

    return FutureBuilder<List<MeseroVentaModel>>(
      future: _historialVentasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: AppLoader(message: 'Cargando historial de ventas...'),
          );
        }
        if (snapshot.hasError) {
          return AppErrorView(
            message: snapshot.error.toString(),
            onRetry: _reloadHistorialVentas,
          );
        }

        final ventas = snapshot.data ?? _historialVentas;
        if (ventas.isEmpty) {
          return const AppEmptyView(message: 'Todavía no hay ventas registradas para las mesas de tu sucursal.');
        }

        final filtroDia = _historialDiaFiltro;
        final ventasFiltradas = filtroDia == null
            ? ventas
            : ventas.where((venta) {
                final fechaVenta = _parseFechaVentaHistorial(venta.fecha);
                return fechaVenta != null && _esMismoDia(fechaVenta, filtroDia);
              }).toList(growable: false);

        final ventasPorMesa = <String, List<MeseroVentaModel>>{};
        for (final venta in ventasFiltradas) {
          final key = 'Mesa ${venta.mesaNumero ?? '-'}';
          ventasPorMesa.putIfAbsent(key, () => <MeseroVentaModel>[]).add(venta);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Historial de ventas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _reloadHistorialVentas,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Consulta las ventas por mesa y abre el detalle para ver qué se vendió, cómo se pagó y cuántas cuentas/cuotas tuvo la venta.',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            _buildHistorialDiaFilterBar(totalVentas: ventas.length, ventasMostradas: ventasFiltradas.length),
            const SizedBox(height: 18),
            if (ventasFiltradas.isEmpty)
              AppEmptyView(
                message: filtroDia == null
                    ? 'Todavía no hay ventas para mostrar.'
                    : 'No hay ventas registradas para el día ${_formatearDiaHistorial(filtroDia)}.',
              )
            else
              ...ventasPorMesa.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _HistorialMesaSection(
                    mesa: entry.key,
                    ventas: entry.value,
                    onVerDetalle: _mostrarDetalleHistorialVenta,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarDetalleHistorialVenta(MeseroVentaModel venta) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _DetalleHistorialVentaPage(venta: venta),
      ),
    );
  }

  Widget _buildProductosStandalone() {
    final productos = _productosFiltrados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductoFiltro(),
        const SizedBox(height: 16),
        if (_productos.isEmpty)
          const AppEmptyView(message: 'No hay productos con precio vigente para tu sucursal.')
        else if (productos.isEmpty)
          const AppEmptyView(message: 'No se encontraron productos con los filtros ingresados.')
        else
          _ProductosCatalogoTabla(productos: productos),
      ],
    );
  }

  Widget _buildPantallaDetalleVenta(MeseroVentaModel venta) {
    final descripcion = (venta.mesaDescripcion ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Volver a mesas',
              onPressed: () => setState(() {
                _mostrandoDetalleVenta = false;
                _mostrandoPestanaAgregarProductos = false;
              }),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Venta de mesa ${venta.mesaNumero ?? '-'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion.isEmpty ? 'Selecciona la cuenta y agrega los productos pedidos.' : descripcion,
                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildVentaActiva(venta),
      ],
    );
  }

  Widget _buildPantallaAgregarProductos(MeseroVentaModel venta, MeseroCuentaModel cuenta) {
    final descripcionVenta = (venta.mesaDescripcion ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Volver a la venta',
              onPressed: _processing
                  ? null
                  : () {
                      _productoFiltroController.clear();
                      setState(() {
                        _productoFiltro = '';
                        _tipoProductoFiltro = null;
                        _marcaProductoFiltro = null;
                        _mostrandoPestanaAgregarProductos = false;
                      });
                    },
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agregar productos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mesa ${venta.mesaNumero ?? '-'} · ${_cuentaEtiquetaVisible(cuenta)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                  ),
                  if (descripcionVenta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      descripcionVenta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildPestanaAgregarProductos(cuenta),
      ],
    );
  }

  Widget _buildVentaActiva(MeseroVentaModel venta) {
    final cuentas = venta.cuentas;
    MeseroCuentaModel? cuentaSeleccionada;
    for (final cuenta in cuentas) {
      if (cuenta.cuentaId == _cuentaSeleccionadaId) {
        cuentaSeleccionada = cuenta;
        break;
      }
    }
    cuentaSeleccionada ??= cuentas.isNotEmpty ? cuentas.first : null;
    if (_cuentaSeleccionadaId == null && cuentaSeleccionada?.cuentaId != null) {
      _cuentaSeleccionadaId = cuentaSeleccionada!.cuentaId;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VentaInfoPanel(
          venta: venta,
          onModificarDivision: null,
          onPagarCuenta: cuentaSeleccionada?.cuentaId == null || _processing
              ? null
              : () => _pagarCuenta(venta, cuentaSeleccionada!),
          onFinalizarVenta: _processing || venta.ventaId == null || venta.pagada != true
              ? null
              : () => _finalizarVenta(venta),
          onLimpiarVentaSinConsumos: _processing || venta.ventaId == null || !_ventaSinProductos(venta)
              ? null
              : () => _limpiarVentaSinConsumos(venta),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 28, offset: const Offset(0, 14))],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeader = constraints.maxWidth < 620;
                  final modificarCuentasButton = FilledButton.tonalIcon(
                    onPressed: _processing || venta.ventaId == null ? null : () => _cambiarNumeroCuentas(venta),
                    icon: const Icon(Icons.groups_2_rounded),
                    label: const Text('Modificar cuentas'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  );

                  if (compactHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuentas de la venta',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            modificarCuentasButton,
                            _TotalPill(total: venta.total),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Cuentas de la venta',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      modificarCuentasButton,
                      const SizedBox(width: 10),
                      _TotalPill(total: venta.total),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Cada cuenta puede tener una descripción para recordar a quién pertenece. Selecciona una cuenta y asigna sus productos.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (cuentas.isEmpty)
                const AppEmptyView(message: 'Esta venta todavía no tiene cuentas registradas.')
              else
                _CuentasTabMenu(
                  cuentas: cuentas,
                  selectedCuentaId: cuentaSeleccionada?.cuentaId,
                  onSelected: (cuenta) => setState(() {
                    _cuentaSeleccionadaId = cuenta.cuentaId;
                    _mostrandoPestanaAgregarProductos = false;
                  }),
                  onDeleteEmptyAccount: (cuenta) => _eliminarCuentaVacia(venta, cuenta),
                ),
              const SizedBox(height: 20),
              if (cuentaSeleccionada != null)
                _CuentaDetalle(
                  cuenta: cuentaSeleccionada,
                  onEliminarProducto: _processing ? null : (producto) => _eliminarProductoCuenta(cuentaSeleccionada!, producto),
                  onMoverProducto: _processing ? null : (producto) => _moverProductoCuenta(venta, cuentaSeleccionada!, producto),
                  onPagarCuenta: cuentaSeleccionada.cuentaId == null || _processing
                      ? null
                      : () => _pagarCuenta(venta, cuentaSeleccionada!),
                  onFinalizarVenta: _processing || venta.ventaId == null || venta.pagada != true
                      ? null
                      : () => _finalizarVenta(venta),
                  onLimpiarVentaSinConsumos: _processing || venta.ventaId == null || !_ventaSinProductos(venta)
                      ? null
                      : () => _limpiarVentaSinConsumos(venta),
                ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildAgregarProductosCallToAction(MeseroCuentaModel? cuentaSeleccionada) {
    final cuentaValida = cuentaSeleccionada?.cuentaId != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_shopping_cart_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productos de la cuenta',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cuentaSeleccionada == null
                          ? 'Selecciona una cuenta para agregar productos.'
                          : _cuentaEtiquetaVisible(cuentaSeleccionada),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          );

          final button = ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 170, maxWidth: 240),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(170, 46),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _processing || !cuentaValida
                  ? null
                  : () => _abrirPestanaAgregarProductos(cuentaSeleccionada!),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar productos'),
            ),
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: button),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _buildPestanaAgregarProductos(MeseroCuentaModel cuenta) {
    final productos = _productosOrdenadosPorPedido(_productosFiltrados, cuenta);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.secondary.withOpacity(0.22)),
        boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.10), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductoFiltro(hintText: 'Busca por nombre, descripción, código o precio'),
          const SizedBox(height: 12),
          _IrACuentaDespuesAgregarSwitch(
            value: _irACuentaDespuesAgregarProducto,
            onChanged: _processing
                ? null
                : (value) => setState(() => _irACuentaDespuesAgregarProducto = value),
          ),
          const SizedBox(height: 16),
          if (_productos.isEmpty)
            const AppEmptyView(message: 'No hay productos con precio vigente para esta sucursal.')
          else if (productos.isEmpty)
            const AppEmptyView(message: 'No se encontraron productos con el filtro ingresado.')
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: AppColors.secondaryDark),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lista ordenada por cantidad pedida en esta venta. Los productos más solicitados aparecen primero.',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AgregarProductosList(
              productos: productos,
              processing: _processing,
              cantidadEnVenta: _cantidadPedidaProductoEnVenta,
              cantidadEnCuenta: (producto) => _cantidadPedidaProductoEnCuenta(cuenta, producto),
              onAgregar: cuenta.cuentaId == null
                  ? null
                  : (producto) => _seleccionarCantidadYAgregarProducto(cuenta.cuentaId!, producto),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _abrirPestanaAgregarProductos(MeseroCuentaModel cuenta) async {
    if (cuenta.cuentaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una cuenta antes de agregar productos.')),
      );
      return;
    }

    if (_productos.isEmpty) {
      setState(() => _processing = true);
      try {
        final productos = await _dataSource.listarProductos();
        if (!mounted) return;
        setState(() => _productos = productos);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    }

    if (!mounted) return;
    _productoFiltroController.clear();
    setState(() {
      _productoFiltro = '';
      _tipoProductoFiltro = null;
      _marcaProductoFiltro = null;
      _cuentaSeleccionadaId = cuenta.cuentaId;
      _mostrandoPestanaAgregarProductos = true;
    });
  }

  Future<void> _crearMesa() async {
    final data = await showDialog<_MesaFormData>(
      context: context,
      builder: (context) => const _CrearMesaDialog(),
    );
    if (data == null) return;

    setState(() => _processing = true);
    try {
      await _dataSource.crearMesa(mesaNumero: data.mesaNumero, mesaDescripcion: data.descripcion, mesaFoto: data.foto);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesa creada en tu sucursal.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _eliminarMesa(MeseroMesaResumenModel mesa) async {
    if (mesa.mesaId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar mesa ${mesa.mesaNumero ?? '-'}'),
        content: const Text('Si la mesa no tiene datos relacionados se eliminará. Si tiene histórico se marcará como inactiva.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processing = true);
    try {
      await _dataSource.eliminarMesa(mesa.mesaId!);
      if (_ventaActiva?.mesaId == mesa.mesaId) {
        _ventaActiva = null;
        _mostrandoDetalleVenta = false;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = null;
      }
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesa eliminada o inactivada correctamente.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _editarMesa(MeseroMesaResumenModel mesa, {required bool isCajero}) async {
    if (mesa.mesaId == null) return;
    final result = await showDialog<_MesaEditResult>(
      context: context,
      builder: (context) => _EditarMesaDialog(mesa: mesa, isCajero: isCajero),
    );
    if (result == null) return;

    setState(() => _processing = true);
    try {
      if (result.eliminar) {
        await _dataSource.eliminarMesa(mesa.mesaId!);
        if (_ventaActiva?.mesaId == mesa.mesaId) {
          _ventaActiva = null;
          _mostrandoPestanaAgregarProductos = false;
          _cuentaSeleccionadaId = null;
        }
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesa eliminada o inactivada correctamente.')));
      } else if (result.data != null) {
        await _dataSource.editarMesa(
          mesaId: mesa.mesaId!,
          mesaNumero: result.data!.mesaNumero,
          mesaDescripcion: result.data!.descripcion,
          mesaFoto: result.data!.foto,
          mesaEstado: result.estado,
        );
        await _reload();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesa actualizada correctamente.')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _abrirVenta(MeseroMesaResumenModel mesa) async {
    if (mesa.mesaId == null) return;

    setState(() => _processing = true);
    try {
      MeseroVentaModel venta;
      if (mesa.ventaId != null) {
        venta = await _dataSource.consultarVenta(mesa.ventaId!);
      } else {
        setState(() => _processing = false);
        final decision = await showDialog<_AbrirVentaDecision>(
          context: context,
          builder: (context) => _AbrirVentaDialog(mesa: mesa),
        );
        if (decision == null) return;
        setState(() => _processing = true);
        venta = await _dataSource.abrirVenta(
          mesaId: mesa.mesaId!,
          dividirCuentas: decision.dividir,
          numeroCuentas: decision.numeroCuentas,
          mesaDescripcion: decision.mesaDescripcion,
          descripcionesCuentas: decision.descripcionesCuentas,
        );
      }
      final future = _load();
      setState(() {
        _ventaActiva = venta;
        _mostrandoDetalleVenta = true;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = venta.cuentas.isNotEmpty ? venta.cuentas.first.cuentaId : null;
        _future = future;
      });
      await future;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cambiarNumeroCuentas(MeseroVentaModel venta) async {
    if (venta.ventaId == null) return;
    final result = await showDialog<_AjustarCuentasResult>(
      context: context,
      builder: (context) => _AjustarCuentasDialog(cuentas: venta.cuentas),
    );
    if (result == null) return;

    setState(() => _processing = true);
    try {
      final updated = await _dataSource.cambiarNumeroCuentas(
        ventaId: venta.ventaId!,
        numeroCuentas: result.numeroCuentas,
        descripcionesCuentas: result.descripcionesCuentas,
      );
      final selected = updated.cuentas.any((cuenta) => cuenta.cuentaId == _cuentaSeleccionadaId)
          ? _cuentaSeleccionadaId
          : (updated.cuentas.isNotEmpty ? updated.cuentas.first.cuentaId : null);
      final future = _load();
      setState(() {
        _ventaActiva = updated;
        _mostrandoDetalleVenta = true;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = selected;
        _future = future;
      });
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuentas y descripciones actualizadas.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _mostrarSelectorAgregarProducto(MeseroCuentaModel cuenta) async {
    final cuentaId = cuenta.cuentaId;
    if (cuentaId == null) return;

    final controller = TextEditingController();
    try {
      final productoSeleccionado = await showModalBottomSheet<MeseroProductoModel>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (bottomSheetContext) {
          String filtro = '';

          List<MeseroProductoModel> filtrarProductos() {
            final query = filtro.trim().toLowerCase();
            if (query.isEmpty) return _productos;
            return _productos.where((producto) {
              final nombre = (producto.nombre ?? '').toLowerCase();
              final descripcion = (producto.descripcion ?? '').toLowerCase();
              final id = (producto.prodId?.toString() ?? '').toLowerCase();
              final precio = (producto.precioVenta?.toString() ?? '').toLowerCase();
              return nombre.contains(query) || descripcion.contains(query) || id.contains(query) || precio.contains(query);
            }).toList(growable: false);
          }

          return StatefulBuilder(
            builder: (context, setModalState) {
              final productos = filtrarProductos();
              final height = MediaQuery.sizeOf(context).height;

              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  constraints: BoxConstraints(maxHeight: height * 0.88),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.secondaryDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Agregar productos',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _cuentaEtiquetaVisible(cuenta),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Buscar productos',
                          hintText: 'Nombre, descripción, código o precio',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) => setModalState(() => filtro = value),
                      ),
                      const SizedBox(height: 14),
                      if (_productos.isEmpty)
                        const AppEmptyView(message: 'No hay productos con precio vigente para esta sucursal.')
                      else if (productos.isEmpty)
                        const AppEmptyView(message: 'No se encontraron productos con el filtro ingresado.')
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: productos.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final producto = productos[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.12),
                                  child: const Icon(Icons.local_bar_rounded, color: AppColors.primary),
                                ),
                                title: Text(
                                  producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  producto.descripcion ?? 'Sin descripción',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(CurrencyUtils.format(producto.precioVenta), style: const TextStyle(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    const Text('Agregar', style: TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                onTap: () => Navigator.of(context).pop(producto),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (productoSeleccionado != null) {
        await _seleccionarCantidadYAgregarProducto(cuentaId, productoSeleccionado);
      }
    } finally {
      controller.dispose();
    }
  }

  bool _ventaSinProductos(MeseroVentaModel venta) {
    return venta.cuentas.isEmpty || venta.cuentas.every((cuenta) => cuenta.productos.isEmpty);
  }

  Future<void> _limpiarVentaSinConsumos(MeseroVentaModel venta) async {
    if (venta.ventaId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liberar mesa'),
        content: const Text(
          'Esta venta no tiene productos registrados. Se eliminarán las cuentas vacías, se cancelará la venta abierta y la mesa quedará disponible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.event_available_rounded),
            label: const Text('Liberar mesa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processing = true);
    try {
      await _dataSource.limpiarVentaSinConsumos(venta.ventaId!);
      final future = _load();
      setState(() {
        _ventaActiva = null;
        _mostrandoDetalleVenta = false;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = null;
        _future = future;
      });
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesa liberada correctamente.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _pagarCuenta(MeseroVentaModel venta, MeseroCuentaModel cuenta) async {
    final cuentaId = cuenta.cuentaId;
    if (cuentaId == null) return;

    if (_mediosPago.isEmpty) {
      setState(() => _processing = true);
      try {
        final medios = await _dataSource.listarMediosPago();
        if (!mounted) return;
        setState(() => _mediosPago = medios);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    }

    if (!mounted) return;
    if (_mediosPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay medios de pago activos para registrar el pago.')),
      );
      return;
    }

    final esMovil = MediaQuery.sizeOf(context).width < 700;
    final result = esMovil
        ? await Navigator.of(context).push<_PagarCuentaResult>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => _PagarCuentaDialog(
                venta: venta,
                cuenta: cuenta,
                mediosPago: _mediosPago,
                mostrarComoPagina: true,
              ),
            ),
          )
        : await showDialog<_PagarCuentaResult>(
            context: context,
            builder: (context) => _PagarCuentaDialog(venta: venta, cuenta: cuenta, mediosPago: _mediosPago),
          );
    if (result == null) return;

    setState(() => _processing = true);
    try {
      final updated = await _dataSource.registrarPagosCuenta(
        cuentaId: cuentaId,
        propina: result.propina,
        pagos: result.pagos
            .map((pago) => {
                  'medioPagoId': pago.medioPagoId,
                  'valor': pago.valor,
                  if (pago.valorRecibido != null) 'valorRecibido': pago.valorRecibido,
                })
            .toList(growable: false),
      );
      final future = _load();
      setState(() {
        _ventaActiva = updated;
        _mostrandoDetalleVenta = true;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = cuentaId;
        _future = future;
      });
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado para la cuenta.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _finalizarVenta(MeseroVentaModel venta) async {
    final ventaId = venta.ventaId;
    if (ventaId == null) return;
    final saldo = venta.saldoPendiente ?? 0;
    if (saldo > 0.009) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede finalizar. Aún hay saldo pendiente: ${CurrencyUtils.format(saldo)}')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar venta'),
        content: Text(
          'Se finalizará la venta #$ventaId, se conservarán las cuentas y pagos en el historial y la mesa quedará disponible para nuevos clientes.\n\nTotal: ${CurrencyUtils.format(venta.total)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Finalizar venta'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processing = true);
    try {
      await _dataSource.finalizarVenta(ventaId);
      final future = _load();
      setState(() {
        _ventaActiva = null;
        _mostrandoDetalleVenta = false;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = null;
        _future = future;
      });
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta finalizada y mesa liberada correctamente.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _eliminarCuentaVacia(MeseroVentaModel venta, MeseroCuentaModel cuenta) async {
    final cuentaId = cuenta.cuentaId;
    if (cuentaId == null) return;

    if (venta.cuentas.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe quedar al menos una cuenta en la venta.')),
      );
      return;
    }

    if (!_cuentaEstaVacia(cuenta)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo se pueden eliminar cuentas sin productos, sin pagos y sin propina.')),
      );
      return;
    }

    final nombreCuenta = _cuentaNombreVisible(cuenta);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta vacía'),
        content: Text(
          'Se eliminará $nombreCuenta.\n\n'
          'Esta acción solo está permitida porque la cuenta no tiene productos, pagos ni propina registrada.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processing = true);
    try {
      final updated = await _dataSource.eliminarCuenta(cuentaId);
      final selected = updated.cuentas.any((item) => item.cuentaId == _cuentaSeleccionadaId)
          ? _cuentaSeleccionadaId
          : (updated.cuentas.isNotEmpty ? updated.cuentas.first.cuentaId : null);
      final future = _load();
      setState(() {
        _ventaActiva = updated;
        _mostrandoDetalleVenta = true;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = selected;
        _future = future;
      });
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nombreCuenta eliminada correctamente.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _eliminarProductoCuenta(MeseroCuentaModel cuenta, MeseroDetalleProductoModel producto) async {
    final cuentaId = cuenta.cuentaId;
    final detalleId = producto.detalleId;
    if (cuentaId == null || detalleId == null) return;

    if (producto.pagado == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto ya fue pagado y no se puede eliminar.')),
      );
      return;
    }

    final nombre = producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto no pagado'),
        content: Text(
          'Se eliminará de ${_cuentaEtiquetaVisible(cuenta)} el producto:\n\n'
          '$nombre\n'
          'Cantidad: ${_formatCantidadGeneral(producto.cantidad)}\n'
          'Total: ${CurrencyUtils.format(producto.subtotal)}\n\n'
          'Solo se permite eliminar productos que todavía no han sido cubiertos por un pago.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processing = true);
    try {
      final updated = await _dataSource.eliminarProductoCuenta(cuentaId: cuentaId, detalleId: detalleId);
      final future = _load();
      setState(() {
        _ventaActiva = updated;
        _mostrandoDetalleVenta = true;
        _cuentaSeleccionadaId = cuentaId;
        _future = future;
      });
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nombre eliminado de la cuenta.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _moverProductoCuenta(MeseroVentaModel venta, MeseroCuentaModel cuentaOrigen, MeseroDetalleProductoModel producto) async {
    final cuentaOrigenId = cuentaOrigen.cuentaId;
    final detalleId = producto.detalleId;
    final ventaId = venta.ventaId;
    if (cuentaOrigenId == null || detalleId == null || ventaId == null) return;

    if (producto.pagado == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto ya fue pagado y no se puede mover a otra cuenta.')),
      );
      return;
    }

    final result = await showDialog<_MoverProductoCuentaResult>(
      context: context,
      builder: (context) => _MoverProductoCuentaDialog(
        venta: venta,
        cuentaOrigen: cuentaOrigen,
        producto: producto,
      ),
    );
    if (result == null) return;

    setState(() => _processing = true);
    try {
      var ventaTrabajo = venta;
      int? cuentaDestinoId = result.cuentaDestinoId;
      int? numeroCuentaDestino;
      String? descripcionCuentaDestino;

      if (result.crearNuevaCuenta) {
        final idsAntes = ventaTrabajo.cuentas.map((cuenta) => cuenta.cuentaId).whereType<int>().toSet();
        final maxNumeroAntes = ventaTrabajo.cuentas.fold<int>(0, (max, cuenta) {
          final numero = cuenta.numero ?? 0;
          return numero > max ? numero : max;
        });
        final numeroCuentaNueva = maxNumeroAntes + 1;
        final totalCuentasDeseado = ventaTrabajo.cuentas.length + 1;
        final descripciones = <int, String>{
          for (final cuenta in ventaTrabajo.cuentas)
            if (cuenta.numero != null) (cuenta.numero!): (cuenta.descripcion ?? '').trim(),
          numeroCuentaNueva: (result.descripcionNuevaCuenta ?? '').trim(),
        };

        ventaTrabajo = await _dataSource.cambiarNumeroCuentas(
          ventaId: ventaId,
          numeroCuentas: totalCuentasDeseado,
          descripcionesCuentas: descripciones,
        );

        MeseroCuentaModel? cuentaNueva;
        for (final cuenta in ventaTrabajo.cuentas) {
          if (cuenta.cuentaId != null && !idsAntes.contains(cuenta.cuentaId)) {
            cuentaNueva = cuenta;
            break;
          }
          if (cuenta.numero == numeroCuentaNueva) {
            cuentaNueva = cuenta;
          }
        }
        cuentaDestinoId = cuentaNueva?.cuentaId;
        numeroCuentaDestino = cuentaNueva?.numero;
        descripcionCuentaDestino = cuentaNueva?.descripcion;
      } else {
        for (final cuenta in ventaTrabajo.cuentas) {
          if (cuenta.cuentaId == cuentaDestinoId) {
            numeroCuentaDestino = cuenta.numero;
            descripcionCuentaDestino = cuenta.descripcion;
            break;
          }
        }
      }

      if (cuentaDestinoId == null) {
        throw Exception('No fue posible identificar la cuenta destino.');
      }

      final updated = await _dataSource.moverProductoCuenta(
        cuentaOrigenId: cuentaOrigenId,
        detalleId: detalleId,
        cuentaDestinoId: cuentaDestinoId,
      );
      final future = _load();
      setState(() {
        _ventaActiva = updated;
        _mostrandoDetalleVenta = true;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = cuentaDestinoId;
        _future = future;
      });
      await future;
      if (!mounted) return;
      final nombre = producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nombre fue pasado a ${descripcionCuentaDestino?.trim().isNotEmpty == true ? descripcionCuentaDestino!.trim() : 'la cuenta destino'}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _seleccionarCantidadYAgregarProducto(int cuentaId, MeseroProductoModel producto) async {
    final cantidad = await showDialog<double>(
      context: context,
      builder: (context) => _CantidadProductoDialog(producto: producto),
    );

    if (cantidad == null || cantidad <= 0) return;
    await _agregarProducto(cuentaId, producto, cantidad: cantidad);
  }

  Future<void> _agregarProducto(int cuentaId, MeseroProductoModel producto, {double cantidad = 1}) async {
    if (producto.prodId == null) return;
    setState(() => _processing = true);
    try {
      final venta = await _dataSource.agregarProducto(
        cuentaId: cuentaId,
        productoId: producto.prodId!,
        precioId: producto.precId,
        cantidad: cantidad,
      );
      final future = _load();
      final volverACuenta = _irACuentaDespuesAgregarProducto;
      if (volverACuenta) {
        _productoFiltroController.clear();
      }
      setState(() {
        _ventaActiva = venta;
        _mostrandoDetalleVenta = true;
        _cuentaSeleccionadaId = cuentaId;
        if (volverACuenta) {
          _productoFiltro = '';
          _tipoProductoFiltro = null;
          _marcaProductoFiltro = null;
          _mostrandoPestanaAgregarProductos = false;
        }
        _future = future;
      });
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_formatCantidadGeneral(cantidad)} x ${producto.nombre ?? 'Producto ${producto.prodId}'} agregado a la cuenta.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.mode, required this.isCajero});
  final MeseroPageMode mode;
  final bool isCajero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final data = switch (mode) {
      MeseroPageMode.mesas => (
          isCajero ? 'Caja y operación de mesas' : 'Operación de mesas',
          isCajero
              ? 'Selecciona mesas, abre ventas, divide cuentas, agrega productos y crea mesas para tu sucursal.'
              : 'Selecciona una mesa, abre la venta, divide cuentas y agrega productos.'
        ),
      MeseroPageMode.productos => ('Productos disponibles', 'Busca productos por nombre, tipo de producto, marca, código o precio.'),
      MeseroPageMode.resumen => ('Resumen por mesa', 'Total pendiente de cada mesa y ventas abiertas de la sucursal.'),
      MeseroPageMode.historial => ('Historial de ventas', 'Ventas registradas por mesa con su descripción operativa.'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: palette.mainGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: palette.secondary.withOpacity(0.22), blurRadius: 30, offset: const Offset(0, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.$1, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: palette.onTitle, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(data.$2, style: TextStyle(color: palette.onTitle.withOpacity(0.76), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CrearMesaFloatingButton extends StatelessWidget {
  const _CrearMesaFloatingButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Agregar mesa',
      child: FloatingActionButton.small(
        heroTag: 'crear-mesa-cajero',
        onPressed: enabled ? onPressed : null,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: const [
            Icon(Icons.table_bar_rounded, size: 22),
            Positioned(
              right: -6,
              top: -6,
              child: Icon(Icons.add_circle_rounded, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}


class _MesasOperacionResumen extends ConsumerWidget {
  const _MesasOperacionResumen({required this.mesas});

  final List<MeseroMesaResumenModel> mesas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final abiertas = mesas.where((mesa) => mesa.ventaId != null).length;
    final inactivas = mesas.where((mesa) => (mesa.estadoMesa ?? '').toUpperCase() == 'INACTIVA').length;
    final disponibles = mesas.length - abiertas - inactivas;
    final total = mesas.fold<double>(0, (sum, mesa) => sum + (mesa.totalPendiente ?? 0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _SmallInfoPill(icon: Icons.table_bar_rounded, text: '${mesas.length} mesas'),
          _SmallInfoPill(icon: Icons.event_available_rounded, text: '$disponibles disponibles'),
          _SmallInfoPill(icon: Icons.receipt_long_rounded, text: '$abiertas abiertas'),
          if (inactivas > 0) _SmallInfoPill(icon: Icons.visibility_off_rounded, text: '$inactivas inactivas'),
          _SmallInfoPill(icon: Icons.payments_rounded, text: CurrencyUtils.format(total)),
        ],
      ),
    );
  }
}

class _MesaCard extends StatelessWidget {
  const _MesaCard({
    required this.mesa,
    required this.onTap,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    this.onDelete,
  });

  final MeseroMesaResumenModel mesa;
  final VoidCallback? onTap;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final abierta = mesa.ventaId != null;
    final descripcion = (mesa.mesaDescripcion ?? '').trim();
    final estadoMesa = (mesa.estadoMesa ?? '').trim();
    final inactiva = estadoMesa.toUpperCase() == 'INACTIVA';
    final statusText = inactiva ? 'Inactiva' : abierta ? 'Ocupada' : 'Libre';
    final actionText = inactiva
        ? 'Fuera de servicio'
        : abierta
            ? 'Continuar venta'
            : 'Abrir venta';
    final statusColor = inactiva
        ? AppColors.textSecondary
        : abierta
            ? AppColors.secondaryDark
            : AppColors.success;
    final accentColor = inactiva
        ? AppColors.textSecondary
        : abierta
            ? AppColors.secondaryDark
            : AppColors.success;
    final softColor = inactiva
        ? AppColors.border.withOpacity(0.60)
        : abierta
            ? AppColors.secondary.withOpacity(0.13)
            : AppColors.successSoft;

    return LayoutBuilder(
      builder: (context, constraints) {
        final veryTight = constraints.maxHeight < 148 || constraints.maxWidth < 245;
        final compact = constraints.maxWidth < 300 || constraints.maxHeight < 170;
        final padding = veryTight ? 6.0 : (compact ? 7.0 : 10.0);
        final tableBoxSize = veryTight ? 30.0 : (compact ? 36.0 : 44.0);
        final radius = compact ? 20.0 : 24.0;
        final showDescription = descripcion.isNotEmpty && !compact && !veryTight && constraints.maxHeight >= 170;
        final showMetrics = !veryTight && constraints.maxHeight >= 142;
        final showActions = !veryTight || constraints.maxWidth >= 235;
        final cuentas = mesa.numeroCuentas ?? 0;
        final pendiente = mesa.totalPendiente ?? 0;

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onTap,
            child: Opacity(
              opacity: inactiva ? 0.70 : 1,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: accentColor.withOpacity(abierta ? 0.28 : 0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(abierta ? 0.13 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: veryTight ? 4 : 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor.withOpacity(0.95), accentColor.withOpacity(0.35)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padding, padding, padding, veryTight ? 6 : padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _MesaNumberPhotoBadge(
                                  mesaNumero: mesa.mesaNumero,
                                  mesaFoto: mesa.mesaFoto,
                                  size: tableBoxSize,
                                  radius: veryTight ? 12 : 15,
                                  accentColor: accentColor,
                                  backgroundColor: softColor,
                                  textColor: AppColors.textPrimary,
                                  compact: compact,
                                  veryTight: veryTight,
                                ),
                                SizedBox(width: veryTight ? 6 : 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Mesa ${mesa.mesaNumero ?? '-'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              fontSize: veryTight ? 13.5 : (compact ? 15 : 18),
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: _MesaStatusBadge(label: statusText, compact: true),
                                      ),
                                    ],
                                  ),
                                ),
                                if (showActions && (canEdit || canDelete))
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (canEdit)
                                        _MesaIconAction(
                                          tooltip: 'Editar mesa',
                                          icon: Icons.edit_rounded,
                                          onPressed: onEdit,
                                          compact: compact,
                                        ),
                                      if (canDelete)
                                        _MesaIconAction(
                                          tooltip: 'Eliminar o inactivar mesa',
                                          icon: Icons.delete_outline_rounded,
                                          onPressed: onDelete ?? onEdit,
                                          color: AppColors.danger,
                                          compact: compact,
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                            if (showDescription) ...[
                              const SizedBox(height: 7),
                              Text(
                                descripcion,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                              ),
                            ],
                            if (showMetrics) ...[
                              SizedBox(height: compact ? 7 : 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MesaCardMetricBox(
                                      label: 'Cuentas',
                                      value: '$cuentas',
                                      icon: Icons.group_rounded,
                                      compact: compact,
                                    ),
                                  ),
                                  SizedBox(width: compact ? 6 : 8),
                                  Expanded(
                                    flex: 2,
                                    child: _MesaCardMetricBox(
                                      label: 'Pendiente',
                                      value: CurrencyUtils.format(pendiente),
                                      icon: Icons.payments_rounded,
                                      compact: compact,
                                      emphasize: pendiente > 0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: veryTight ? 6 : (compact ? 8 : 10)),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: veryTight ? 5 : (compact ? 6 : 7)),
                              decoration: BoxDecoration(
                                color: inactiva ? AppColors.border.withOpacity(0.55) : accentColor.withOpacity(0.11),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: accentColor.withOpacity(0.16)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    abierta ? Icons.point_of_sale_rounded : Icons.add_business_rounded,
                                    size: veryTight ? 12 : (compact ? 14 : 15),
                                    color: inactiva ? AppColors.textSecondary : accentColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      actionText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: inactiva ? AppColors.textSecondary : accentColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: veryTight ? 10 : (compact ? 11 : 12.2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _MesaNumberPhotoBadge extends StatelessWidget {
  const _MesaNumberPhotoBadge({
    required this.mesaNumero,
    required this.mesaFoto,
    required this.size,
    required this.radius,
    required this.accentColor,
    required this.backgroundColor,
    required this.textColor,
    required this.compact,
    required this.veryTight,
  });

  final int? mesaNumero;
  final String? mesaFoto;
  final double size;
  final double radius;
  final Color accentColor;
  final Color backgroundColor;
  final Color textColor;
  final bool compact;
  final bool veryTight;

  @override
  Widget build(BuildContext context) {
    final photo = (mesaFoto ?? '').trim();
    final number = '${mesaNumero ?? '-'}';
    final numberSize = veryTight ? 12.0 : (compact ? 14.0 : 16.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accentColor.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 7)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isNotEmpty
          ? Stack(
              fit: StackFit.expand,
              children: [
                _BarlyticsImage(value: photo, width: size, height: size),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.50), Colors.black.withOpacity(0.16)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        number,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: size <= 36 ? numberSize + 1 : numberSize + 3,
                          letterSpacing: 0.1,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [backgroundColor, Colors.white.withOpacity(0.82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_restaurant_rounded, size: veryTight ? 12 : (compact ? 14 : 16), color: accentColor),
                      const SizedBox(height: 1),
                      Text(
                        number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: numberSize),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _MesaIconAction extends StatelessWidget {
  const _MesaIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.compact,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 32.0;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        iconSize: compact ? 16 : 18,
        color: color ?? AppColors.textSecondary,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

class _MesaCardMetricBox extends StatelessWidget {
  const _MesaCardMetricBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.compact,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool compact;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? AppColors.secondaryDark : AppColors.textPrimary;
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 36 : 46),
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 9, vertical: compact ? 5 : 8),
      decoration: BoxDecoration(
        color: emphasize ? AppColors.secondary.withOpacity(0.09) : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: emphasize ? AppColors.secondary.withOpacity(0.18) : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: compact ? 13 : 16, color: emphasize ? AppColors.secondaryDark : AppColors.textSecondary),
          SizedBox(width: compact ? 5 : 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: compact ? 9 : 10, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: compact ? 10.8 : 12.2, color: color, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMesaMetric extends StatelessWidget {
  const _MiniMesaMetric({required this.icon, required this.text, this.compact = false});

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.80), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 12 : 14, color: AppColors.secondaryDark),
            SizedBox(width: compact ? 4 : 5),
            Text(text, style: TextStyle(fontSize: compact ? 10.8 : 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        ),
      );
}

class _MesaStatusBadge extends ConsumerWidget {
  const _MesaStatusBadge({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 96 : 132),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.72 : 0.90),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w800, color: palette.textSecondary),
      ),
    );
  }
}

class _ResumenMesaTile extends ConsumerWidget {
  const _ResumenMesaTile({required this.mesa, required this.onTap});
  final MeseroMesaResumenModel mesa;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final descripcion = (mesa.mesaDescripcion ?? '').trim();
    final abierta = mesa.ventaId != null;
    final inactiva = (mesa.estadoMesa ?? '').toUpperCase() == 'INACTIVA';
    final status = inactiva ? 'Inactiva' : abierta ? 'Ocupada' : 'Libre';
    final accent = inactiva
        ? palette.textSecondary
        : abierta
            ? palette.secondary
            : AppColors.success;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.88 : 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withOpacity(0.22)),
            boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 22, offset: const Offset(0, 12))],
          ),
          child: Row(
            children: [
              _MesaNumberPhotoBadge(
                mesaNumero: mesa.mesaNumero,
                mesaFoto: mesa.mesaFoto,
                size: 48,
                radius: 18,
                accentColor: accent,
                backgroundColor: accent.withOpacity(0.18),
                textColor: palette.textPrimary,
                compact: false,
                veryTight: false,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Mesa ${mesa.mesaNumero ?? '-'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ),
                        _ResumenStatusChip(label: status, color: accent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ResumenMiniMetric(icon: Icons.group_rounded, text: '${mesa.numeroCuentas ?? 0} cuentas', palette: palette),
                        if (descripcion.isNotEmpty) _ResumenMiniMetric(icon: Icons.notes_rounded, text: descripcion, palette: palette),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Pendiente',
                      style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyUtils.format(mesa.totalPendiente),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryBanner extends ConsumerWidget {
  const _SummaryBanner({
    required this.total,
    required this.totalMesas,
    required this.mesasAbiertas,
    required this.mesasLibres,
  });

  final double total;
  final int totalMesas;
  final int mesasAbiertas;
  final int mesasLibres;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.titleBackground.withOpacity(palette.darkBackground ? 0.86 : 0.92), palette.secondary.withOpacity(0.82), palette.accent.withOpacity(0.66)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 34, offset: const Offset(0, 18))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ResumenBannerMetric(icon: Icons.table_bar_rounded, label: 'Mesas', value: '$totalMesas'),
              _ResumenBannerMetric(icon: Icons.point_of_sale_rounded, label: 'Abiertas', value: '$mesasAbiertas'),
              _ResumenBannerMetric(icon: Icons.event_available_rounded, label: 'Libres', value: '$mesasLibres'),
              _ResumenBannerMetric(icon: Icons.payments_rounded, label: 'Pendiente', value: CurrencyUtils.format(total)),
            ],
          );

          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                    child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resumen vendedor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21)),
                        SizedBox(height: 4),
                        Text('Mesas, productos y saldos visibles para operar ventas.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ResumenFeaturePill(icon: Icons.add_shopping_cart_rounded, text: 'Agregar productos'),
                  _ResumenFeaturePill(icon: Icons.receipt_long_rounded, text: 'Ver cuentas'),
                  _ResumenFeaturePill(icon: Icons.payments_rounded, text: 'Controlar saldos'),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 18), metrics],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: intro),
              const SizedBox(width: 18),
              SizedBox(width: 420, child: metrics),
            ],
          );
        },
      ),
    );
  }
}

class _ResumenBannerMetric extends StatelessWidget {
  const _ResumenBannerMetric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 198,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ResumenFeaturePill extends StatelessWidget {
  const _ResumenFeaturePill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.18))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      );
}

class _ResumenMiniMetric extends StatelessWidget {
  const _ResumenMiniMetric({required this.icon, required this.text, required this.palette});

  final IconData icon;
  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: palette.secondary.withOpacity(palette.darkBackground ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.secondary.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: palette.secondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class _ResumenStatusChip extends StatelessWidget {
  const _ResumenStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.20))),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
      );
}

class _VentaInfoPanel extends StatelessWidget {
  const _VentaInfoPanel({
    required this.venta,
    this.onModificarDivision,
    this.onPagarCuenta,
    this.onFinalizarVenta,
    this.onLimpiarVentaSinConsumos,
  });

  final MeseroVentaModel venta;
  final VoidCallback? onModificarDivision;
  final VoidCallback? onPagarCuenta;
  final VoidCallback? onFinalizarVenta;
  final VoidCallback? onLimpiarVentaSinConsumos;

  @override
  Widget build(BuildContext context) {
    final descripcion = (venta.mesaDescripcion ?? '').trim();
    final cuentas = venta.cuentas.length;
    final productos = venta.cuentas.fold<int>(0, (sum, cuenta) => sum + cuenta.productos.length);
    final saldo = venta.saldoPendiente ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.12), AppColors.secondary.withOpacity(0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mesa ${venta.mesaNumero ?? '-'} · Venta #${venta.ventaId ?? '-'}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                descripcion.isEmpty ? 'Sin descripción registrada para esta venta.' : descripcion,
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SmallInfoPill(icon: Icons.receipt_long_rounded, text: '$cuentas cuentas'),
              _SmallInfoPill(icon: Icons.shopping_bag_rounded, text: '$productos productos'),
              _TotalPill(total: venta.total),
              _SmallInfoPill(icon: Icons.account_balance_wallet_rounded, text: 'Pagado ${CurrencyUtils.format(venta.totalPagado)}'),
              _SmallInfoPill(icon: Icons.pending_actions_rounded, text: 'Saldo ${CurrencyUtils.format(saldo)}'),
              if (onModificarDivision != null)
                FilledButton.tonalIcon(
                  onPressed: onModificarDivision,
                  icon: const Icon(Icons.groups_2_rounded),
                  label: const Text('Modificar cuentas'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 16), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: title), const SizedBox(width: 16), Flexible(child: actions)],
          );
        },
      ),
    );
  }
}

class _SmallInfoPill extends ConsumerWidget {
  const _SmallInfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.82 : 0.90),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: palette.secondary),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary)),
        ],
      ),
    );
  }
}

class _CuentaSelectorCard extends StatelessWidget {
  const _CuentaSelectorCard({required this.cuenta, required this.selected, required this.onTap});

  final MeseroCuentaModel cuenta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final descripcion = (cuenta.descripcion ?? '').trim();
    return Material(
      color: selected ? AppColors.secondary.withOpacity(0.10) : AppColors.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.secondaryDark : AppColors.border, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? AppColors.secondaryDark : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cuentaNombreVisible(cuenta),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                descripcion.isEmpty ? 'Sin descripción' : descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: descripcion.isEmpty ? AppColors.textSecondary.withOpacity(0.75) : AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallInfoPill(icon: Icons.shopping_bag_rounded, text: '${cuenta.productos.length} productos'),
                  _SmallInfoPill(icon: Icons.payments_rounded, text: CurrencyUtils.format(cuenta.total)),
                  _SmallInfoPill(
                    icon: cuenta.pagada == true ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    text: cuenta.pagada == true ? 'Pagada' : 'Saldo ${CurrencyUtils.format(cuenta.saldoPendiente)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CuentasTabMenu extends StatelessWidget {
  const _CuentasTabMenu({
    required this.cuentas,
    required this.selectedCuentaId,
    required this.onSelected,
    this.onDeleteEmptyAccount,
  });

  final List<MeseroCuentaModel> cuentas;
  final int? selectedCuentaId;
  final ValueChanged<MeseroCuentaModel> onSelected;
  final ValueChanged<MeseroCuentaModel>? onDeleteEmptyAccount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final gap = compact ? 6.0 : 8.0;
        final horizontalPadding = compact ? 6.0 : 8.0;
        final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
        final maxColumns = compact
            ? (availableWidth < 330 ? 2 : (availableWidth < 520 ? 3 : 4))
            : (availableWidth < 760 ? 4 : (availableWidth < 1100 ? 5 : 6));
        final columns = cuentas.isEmpty ? 1 : (cuentas.length < maxColumns ? cuentas.length : maxColumns);

        final barDecoration = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 22 : 24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        );

        final rows = <Widget>[];
        for (var start = 0; start < cuentas.length; start += columns) {
          final rowAccounts = cuentas.skip(start).take(columns).toList(growable: false);
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < rowAccounts.length; index++) ...[
                  Expanded(
                    child: _CuentaSelectorTab(
                      cuenta: rowAccounts[index],
                      selected: rowAccounts[index].cuentaId == selectedCuentaId,
                      compact: compact,
                      canDelete: cuentas.length > 1 && _cuentaEstaVacia(rowAccounts[index]) && onDeleteEmptyAccount != null,
                      onDelete: onDeleteEmptyAccount == null ? null : () => onDeleteEmptyAccount!(rowAccounts[index]),
                      onTap: () => onSelected(rowAccounts[index]),
                    ),
                  ),
                  if (index != rowAccounts.length - 1) SizedBox(width: gap),
                ],
              ],
            ),
          );
          if (start + columns < cuentas.length) {
            rows.add(SizedBox(height: gap));
          }
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: compact ? 6 : 8),
          decoration: barDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        );
      },
    );
  }
}

class _CuentaSelectorTab extends StatelessWidget {
  const _CuentaSelectorTab({
    required this.cuenta,
    required this.selected,
    required this.onTap,
    this.onDelete,
    this.canDelete = false,
    this.compact = false,
  });

  final MeseroCuentaModel cuenta;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool canDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final saldo = cuenta.saldoPendiente ?? 0;
    final pagada = cuenta.pagada == true;
    final colorActivo = AppColors.secondaryDark;
    final colorInactivo = AppColors.textSecondary;
    final colorEstado = pagada ? AppColors.success : AppColors.secondaryDark;
    final icon = pagada ? Icons.check_circle_rounded : Icons.receipt_long_rounded;
    final estado = pagada ? 'Pagada' : CurrencyUtils.format(saldo);

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Stack(
            children: [
              AnimatedContainer(
                width: double.infinity,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                constraints: BoxConstraints(minHeight: compact ? 76 : 82),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 10,
                  vertical: compact ? 7 : 9,
                ).copyWith(right: canDelete ? (compact ? 24 : 28) : null),
                decoration: BoxDecoration(
                  color: selected ? colorActivo.withOpacity(0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? colorActivo.withOpacity(0.36) : Colors.transparent,
                    width: selected ? 1.3 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selected ? (compact ? 30 : 38) : 18,
                      height: 4,
                      decoration: BoxDecoration(
                        color: selected ? colorActivo : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 8),
                    Icon(
                      icon,
                      size: compact ? 21 : 23,
                      color: selected ? colorActivo : colorInactivo,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cuentaNombreVisible(cuenta),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? colorActivo : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 11 : 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      estado,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? colorActivo : colorEstado,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 10.5 : 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (canDelete && onDelete != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Tooltip(
                    message: 'Eliminar cuenta vacía',
                    child: InkResponse(
                      radius: 18,
                      onTap: onDelete,
                      child: Container(
                        width: compact ? 24 : 26,
                        height: compact ? 24 : 26,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.danger.withOpacity(0.24)),
                        ),
                        child: Icon(Icons.close_rounded, size: compact ? 15 : 16, color: AppColors.danger),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalPill extends StatelessWidget {
  const _TotalPill({required this.total});
  final num? total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
        child: Text(CurrencyUtils.format(total), style: const TextStyle(color: AppColors.secondaryDark, fontWeight: FontWeight.w900)),
      );
}

class _CuentaDetalle extends StatelessWidget {
  const _CuentaDetalle({
    required this.cuenta,
    this.onEliminarProducto,
    this.onMoverProducto,
    this.onPagarCuenta,
    this.onFinalizarVenta,
    this.onLimpiarVentaSinConsumos,
  });

  final MeseroCuentaModel cuenta;
  final ValueChanged<MeseroDetalleProductoModel>? onEliminarProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onMoverProducto;
  final VoidCallback? onPagarCuenta;
  final VoidCallback? onFinalizarVenta;
  final VoidCallback? onLimpiarVentaSinConsumos;

  @override
  Widget build(BuildContext context) {
    final nombreCuenta = _cuentaNombreVisible(cuenta);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CuentaDetalleHeader(nombreCuenta: nombreCuenta, total: cuenta.total),
          const SizedBox(height: 16),
          _CuentaSectionCard(
            icon: Icons.restaurant_menu_rounded,
            title: 'Productos solicitados',
            description: 'Consumo de esta cuenta y totales debajo de la tabla.',
            child: _buildProductosCuenta(),
          ),
          const SizedBox(height: 14),
          _CuentaSectionCard(
            icon: Icons.receipt_long_rounded,
            title: 'Pagos registrados',
            description: 'Pagos aplicados a esta cuenta.',
            child: _buildPagosRegistrados(context),
          ),
          const SizedBox(height: 14),
          _CuentaSectionCard(
            icon: Icons.point_of_sale_rounded,
            title: 'Acciones de caja',
            description: 'Cobrar, finalizar o liberar la mesa.',
            child: _CuentaDetalleAccionesPago(
              cuenta: cuenta,
              onPagarCuenta: onPagarCuenta,
              onFinalizarVenta: onFinalizarVenta,
              onLimpiarVentaSinConsumos: onLimpiarVentaSinConsumos,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductosCuenta() {
    if (cuenta.productos.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          return Column(
            children: [
              const _CuentaEmptySection(
                icon: Icons.local_bar_outlined,
                message: 'Esta cuenta todavía no tiene productos asignados.',
              ),
              const SizedBox(height: 10),
              _CuentaTotalesBajoTabla(cuenta: cuenta, compact: compact),
            ],
          );
        },
      );
    }

    return _CuentaProductosTabla(
      cuenta: cuenta,
      productos: cuenta.productos,
      onEliminarProducto: onEliminarProducto,
      onMoverProducto: onMoverProducto,
    );
  }

  Widget _buildPagosRegistrados(BuildContext context) {
    if (cuenta.pagos.isEmpty) {
      return const _CuentaEmptySection(
        icon: Icons.payments_outlined,
        message: 'Esta cuenta todavía no tiene pagos registrados.',
      );
    }

    return Column(
      children: cuenta.pagos.map((pago) => _CuentaPagoRegistradoTile(pago: pago)).toList(growable: false),
    );
  }
}

class _CuentaDetalleHeader extends StatelessWidget {
  const _CuentaDetalleHeader({required this.nombreCuenta, required this.total});

  final String nombreCuenta;
  final num? total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.12), AppColors.secondary.withOpacity(0.10), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final title = Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: const Icon(Icons.person_pin_circle_rounded, color: AppColors.secondaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cuenta seleccionada',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nombreCuenta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          );

          final totalBox = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                const Text('Total cuenta', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(CurrencyUtils.format(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          );

          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), totalBox]);
          }

          return Row(children: [Expanded(child: title), const SizedBox(width: 16), totalBox]);
        },
      ),
    );
  }
}

class _CuentaSectionCard extends StatelessWidget {
  const _CuentaSectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: AppColors.secondaryDark, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CuentaEmptySection extends StatelessWidget {
  const _CuentaEmptySection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _CuentaPagoRegistradoTile extends StatelessWidget {
  const _CuentaPagoRegistradoTile({required this.pago});

  final MeseroPagoModel pago;

  @override
  Widget build(BuildContext context) {
    final tieneRecibido = pago.valorRecibido != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.successSoft.withOpacity(0.85), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.payments_rounded, color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pago.medioPagoNombre ?? 'Medio ${pago.medioPagoId ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  tieneRecibido
                      ? 'Recibido: ${CurrencyUtils.format(pago.valorRecibido)} · Vueltas: ${CurrencyUtils.format(pago.cambio ?? 0)}'
                      : 'Pago aplicado a la cuenta',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(CurrencyUtils.format(pago.valor), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ],
      ),
    );
  }
}


class _CuentaProductosTabla extends ConsumerWidget {
  const _CuentaProductosTabla({
    required this.cuenta,
    required this.productos,
    this.onEliminarProducto,
    this.onMoverProducto,
  });

  final MeseroCuentaModel cuenta;
  final List<MeseroDetalleProductoModel> productos;
  final ValueChanged<MeseroDetalleProductoModel>? onEliminarProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onMoverProducto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            if (compact) {
              return Column(
                children: [
                  ...productos.map(
                    (producto) => _CuentaProductoMobileRow(
                      producto: producto,
                      palette: palette,
                      onEliminarProducto: onEliminarProducto,
                      onMoverProducto: onMoverProducto,
                    ),
                  ),
                  _CuentaTotalesBajoTabla(cuenta: cuenta, compact: true),
                ],
              );
            }

            final tableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 860 ? constraints.maxWidth : 860.0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    _buildHeader(palette),
                    ...productos.map((producto) => _buildRow(producto, palette)),
                    _CuentaTotalesBajoTabla(cuenta: cuenta),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette palette) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(palette.darkBackground ? 0.16 : 0.08),
        border: Border(bottom: BorderSide(color: palette.cardBorder)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 58, child: _CuentaProductoHeaderCell('Foto')),
          Expanded(flex: 5, child: _CuentaProductoHeaderCell('Producto')),
          SizedBox(width: 12),
          SizedBox(width: 82, child: _CuentaProductoHeaderCell('Cant.', alignEnd: true)),
          SizedBox(width: 14),
          SizedBox(width: 126, child: _CuentaProductoHeaderCell('Unitario', alignEnd: true)),
          SizedBox(width: 14),
          SizedBox(width: 132, child: _CuentaProductoHeaderCell('Total', alignEnd: true)),
          SizedBox(width: 18),
          SizedBox(width: 124, child: _CuentaProductoHeaderCell('Estado')),
          SizedBox(width: 14),
          SizedBox(width: 104, child: _CuentaProductoHeaderCell('Acciones', alignEnd: true)),
        ],
      ),
    );
  }

  Widget _buildRow(MeseroDetalleProductoModel producto, AppPalette palette) {
    final pagado = producto.pagado == true;
    final puedeEliminar = !pagado && onEliminarProducto != null;
    final puedeMover = !pagado && onMoverProducto != null;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Row(
        children: [
          SizedBox(width: 58, child: _ProductImageThumb(value: producto.productoFoto, size: 42)),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Tooltip(
                  message: pagado ? 'Producto ya pagado' : 'Producto pendiente de pago',
                  child: Icon(
                    pagado ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 18,
                    color: pagado ? AppColors.textSecondary : AppColors.secondaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 82, child: _CuentaProductoValueCell(_formatCantidadGeneral(producto.cantidad), alignEnd: true)),
          const SizedBox(width: 14),
          SizedBox(width: 126, child: _CuentaProductoValueCell(CurrencyUtils.format(producto.valorUnitario), alignEnd: true)),
          const SizedBox(width: 14),
          SizedBox(width: 132, child: _CuentaProductoValueCell(CurrencyUtils.format(producto.subtotal), alignEnd: true, strong: true)),
          const SizedBox(width: 18),
          SizedBox(
            width: 124,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _EstadoPagoChip(pagado: pagado),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 104,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                  padding: EdgeInsets.zero,
                  iconSize: 19,
                  tooltip: pagado ? 'No se puede mover porque ya fue pagado' : 'Pasar producto a otra cuenta',
                  onPressed: puedeMover ? () => onMoverProducto!(producto) : null,
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                  padding: EdgeInsets.zero,
                  iconSize: 19,
                  tooltip: pagado ? 'No se puede eliminar porque ya fue pagado' : 'Eliminar producto no pagado',
                  onPressed: puedeEliminar ? () => onEliminarProducto!(producto) : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CuentaTotalesBajoTabla extends StatelessWidget {
  const _CuentaTotalesBajoTabla({required this.cuenta, this.compact = false});

  final MeseroCuentaModel cuenta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final saldo = cuenta.saldoPendiente ?? 0;
    final items = [
      _CuentaResumenDato(
        icon: Icons.restaurant_menu_rounded,
        label: 'Productos',
        value: CurrencyUtils.format(cuenta.subtotalProductos),
      ),
      _CuentaResumenDato(
        icon: Icons.volunteer_activism_rounded,
        label: 'Propina',
        value: CurrencyUtils.format(cuenta.propina),
      ),
      _CuentaResumenDato(
        icon: Icons.payments_rounded,
        label: 'Pagado',
        value: CurrencyUtils.format(cuenta.totalPagado),
        highlighted: true,
      ),
      _CuentaResumenDato(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Saldo',
        value: CurrencyUtils.format(cuenta.saldoPendiente),
        danger: saldo > 0.009,
      ),
      _CuentaResumenDato(
        icon: Icons.receipt_long_rounded,
        label: 'Total',
        value: CurrencyUtils.format(cuenta.total),
        strong: true,
      ),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.summarize_rounded, color: AppColors.secondaryDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Totales de la cuenta',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth.isFinite ? constraints.maxWidth : 680.0;
              final columns = compact ? 2 : available >= 900 ? 5 : available >= 700 ? 3 : 2;
              final spacing = compact ? 8.0 : 10.0;
              final itemWidth = (available - (spacing * (columns - 1))) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: items
                    .map(
                      (item) => SizedBox(
                        width: itemWidth,
                        child: item,
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CuentaResumenDato extends StatelessWidget {
  const _CuentaResumenDato({
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
    this.strong = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;
  final bool strong;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = danger
        ? AppColors.danger
        : strong || highlighted
            ? AppColors.secondaryDark
            : AppColors.textSecondary;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: danger
              ? AppColors.danger.withOpacity(0.24)
              : highlighted || strong
                  ? AppColors.secondary.withOpacity(0.24)
                  : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: strong ? 15 : 14,
                    fontWeight: FontWeight.w900,
                    color: danger ? AppColors.danger : strong || highlighted ? AppColors.secondaryDark : AppColors.textPrimary,
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

class _CuentaProductoMobileRow extends StatelessWidget {
  const _CuentaProductoMobileRow({
    required this.producto,
    required this.palette,
    this.onEliminarProducto,
    this.onMoverProducto,
  });

  final MeseroDetalleProductoModel producto;
  final AppPalette palette;
  final ValueChanged<MeseroDetalleProductoModel>? onEliminarProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onMoverProducto;

  @override
  Widget build(BuildContext context) {
    final pagado = producto.pagado == true;
    final puedeEliminar = !pagado && onEliminarProducto != null;
    final puedeMover = !pagado && onMoverProducto != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                pagado ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 19,
                color: pagado ? AppColors.textSecondary : AppColors.secondaryDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              _EstadoPagoChip(pagado: pagado),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MobileMiniMetric(label: 'Cant.', value: _formatCantidadGeneral(producto.cantidad))),
              const SizedBox(width: 8),
              Expanded(child: _MobileMiniMetric(label: 'Unitario', value: CurrencyUtils.format(producto.valorUnitario), alignEnd: true)),
              const SizedBox(width: 8),
              Expanded(child: _MobileMiniMetric(label: 'Total', value: CurrencyUtils.format(producto.subtotal), alignEnd: true)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: puedeMover ? () => onMoverProducto!(producto) : null,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Mover'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: puedeEliminar ? () => onEliminarProducto!(producto) : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EstadoPagoChip extends StatelessWidget {
  const _EstadoPagoChip({required this.pagado});

  final bool pagado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: pagado ? AppColors.success.withOpacity(0.12) : AppColors.warning.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pagado ? AppColors.success.withOpacity(0.28) : AppColors.warning.withOpacity(0.32)),
      ),
      child: Text(
        pagado ? 'Pagado' : 'Pendiente',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: pagado ? AppColors.success : AppColors.warning,
        ),
      ),
    );
  }
}

class _CuentaProductoHeaderCell extends StatelessWidget {
  const _CuentaProductoHeaderCell(this.text, {this.alignEnd = false});

  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary),
      ),
    );
  }
}

class _CuentaProductoValueCell extends StatelessWidget {
  const _CuentaProductoValueCell(this.text, {this.alignEnd = false, this.strong = false});

  final String text;
  final bool alignEnd;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          color: strong ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CuentaDetalleAccionesPago extends StatelessWidget {
  const _CuentaDetalleAccionesPago({
    required this.cuenta,
    this.onPagarCuenta,
    this.onFinalizarVenta,
    this.onLimpiarVentaSinConsumos,
  });

  final MeseroCuentaModel cuenta;
  final VoidCallback? onPagarCuenta;
  final VoidCallback? onFinalizarVenta;
  final VoidCallback? onLimpiarVentaSinConsumos;

  @override
  Widget build(BuildContext context) {
    final saldo = cuenta.saldoPendiente ?? 0;
    final acciones = <Widget>[
      _CuentaActionButton(
        icon: Icons.payments_rounded,
        title: 'Pagar cuenta',
        subtitle: saldo > 0.009 ? CurrencyUtils.format(saldo) : 'Nuevo pago',
        colors: const [AppColors.secondaryDark, AppColors.secondary],
        onTap: onPagarCuenta,
        compact: true,
      ),
      _CuentaActionButton(
        icon: Icons.check_circle_rounded,
        title: 'Finalizar venta',
        subtitle: onFinalizarVenta == null ? 'Pendiente' : 'Cerrar venta',
        colors: const [AppColors.success, AppColors.primary],
        onTap: onFinalizarVenta,
        compact: true,
      ),
      if (onLimpiarVentaSinConsumos != null)
        _CuentaActionButton(
          icon: Icons.event_available_rounded,
          title: 'Liberar mesa',
          subtitle: 'Sin consumos',
          colors: const [AppColors.warning, AppColors.danger],
          onTap: onLimpiarVentaSinConsumos,
          compact: true,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final usarColumna = constraints.maxWidth < 520;
        if (usarColumna) {
          return Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < acciones.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    acciones[i],
                  ],
                ],
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: acciones.map((accion) => SizedBox(width: 190, child: accion)).toList(growable: false),
          ),
        );
      },
    );
  }
}

class _CuentaActionButton extends StatelessWidget {
  const _CuentaActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final gradientColors = enabled ? colors : [AppColors.textSecondary.withOpacity(0.38), AppColors.textSecondary.withOpacity(0.26)];
    final radius = compact ? 15.0 : 20.0;
    final iconSize = compact ? 29.0 : 42.0;
    final contentPadding = compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10) : const EdgeInsets.all(16);
    final titleFontSize = compact ? 13.0 : 15.0;
    final subtitleFontSize = compact ? 10.2 : 12.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(
          padding: contentPadding,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: enabled
                ? [BoxShadow(color: colors.first.withOpacity(0.18), blurRadius: compact ? 12 : 20, offset: Offset(0, compact ? 6 : 10))]
                : const [],
          ),
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(color: Colors.white.withOpacity(enabled ? 0.22 : 0.14), borderRadius: BorderRadius.circular(compact ? 10 : 14)),
                child: Icon(icon, color: Colors.white, size: compact ? 18 : 24),
              ),
              SizedBox(width: compact ? 9 : 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: titleFontSize),
                    ),
                    SizedBox(height: compact ? 2 : 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.86), fontWeight: FontWeight.w700, fontSize: subtitleFontSize),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 5 : 8),
              Icon(enabled ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded, color: Colors.white, size: compact ? 18 : 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductosCatalogoTabla extends ConsumerWidget {
  const _ProductosCatalogoTabla({required this.productos});

  final List<MeseroProductoModel> productos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            if (compact) {
              return Column(
                children: productos.map((producto) => _ProductoCatalogoMobileRow(producto: producto)).toList(growable: false),
              );
            }

            final tableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 860 ? constraints.maxWidth : 860.0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    _buildHeader(palette),
                    ...productos.map((producto) => _ProductoCatalogoTableRow(producto: producto)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette palette) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(palette.darkBackground ? 0.16 : 0.08),
        border: Border(bottom: BorderSide(color: palette.cardBorder)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 4, child: _CuentaProductoHeaderCell('Producto')),
          SizedBox(width: 150, child: _CuentaProductoHeaderCell('Tipo')),
          SizedBox(width: 150, child: _CuentaProductoHeaderCell('Marca')),
          SizedBox(width: 136, child: _CuentaProductoHeaderCell('Precio', alignEnd: true)),
        ],
      ),
    );
  }
}

class _ProductoCatalogoTableRow extends ConsumerWidget {
  const _ProductoCatalogoTableRow({required this.producto});

  final MeseroProductoModel producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final tipo = (producto.tipoProductoNombre ?? '').trim().isNotEmpty
        ? producto.tipoProductoNombre!.trim()
        : (producto.tipoProductoId == null ? 'Sin tipo' : 'Tipo ${producto.tipoProductoId}');
    final marca = (producto.marcaNombre ?? '').trim().isNotEmpty
        ? producto.marcaNombre!.trim()
        : (producto.marcaId == null ? 'Sin marca' : 'Marca ${producto.marcaId}');
    final descripcion = (producto.descripcion ?? '').trim();

    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                _ProductImageThumb(value: producto.foto, size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (descripcion.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 150, child: _CuentaProductoValueCell(tipo)),
          SizedBox(width: 150, child: _CuentaProductoValueCell(marca)),
          SizedBox(width: 136, child: _CuentaProductoValueCell(CurrencyUtils.format(producto.precioVenta), alignEnd: true, strong: true)),
        ],
      ),
    );
  }
}

class _ProductoCatalogoMobileRow extends ConsumerWidget {
  const _ProductoCatalogoMobileRow({required this.producto});

  final MeseroProductoModel producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final tipo = (producto.tipoProductoNombre ?? '').trim().isNotEmpty
        ? producto.tipoProductoNombre!.trim()
        : (producto.tipoProductoId == null ? 'Sin tipo' : 'Tipo ${producto.tipoProductoId}');
    final marca = (producto.marcaNombre ?? '').trim().isNotEmpty
        ? producto.marcaNombre!.trim()
        : (producto.marcaId == null ? 'Sin marca' : 'Marca ${producto.marcaId}');
    final descripcion = (producto.descripcion ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImageThumb(value: producto.foto, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _ProductoTag(icon: Icons.category_rounded, text: tipo),
                    _ProductoTag(icon: Icons.local_offer_rounded, text: marca),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(CurrencyUtils.format(producto.precioVenta), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  const _ProductoCard({required this.producto, this.actionLabel, this.onAction});

  final MeseroProductoModel producto;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tipo = (producto.tipoProductoNombre ?? '').trim().isNotEmpty
        ? producto.tipoProductoNombre!.trim()
        : (producto.tipoProductoId == null ? 'Sin tipo' : 'Tipo ${producto.tipoProductoId}');
    final marca = (producto.marcaNombre ?? '').trim().isNotEmpty
        ? producto.marcaNombre!.trim()
        : (producto.marcaId == null ? 'Sin marca' : 'Marca ${producto.marcaId}');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ProductoTag(icon: Icons.category_rounded, text: tipo),
                _ProductoTag(icon: Icons.local_offer_rounded, text: marca),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              producto.descripcion ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(CurrencyUtils.format(producto.precioVenta), style: const TextStyle(fontWeight: FontWeight.w900))),
                if (actionLabel != null)
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(actionLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class _IrACuentaDespuesAgregarSwitch extends StatelessWidget {
  const _IrACuentaDespuesAgregarSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: value ? AppColors.secondary.withOpacity(0.10) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: value ? AppColors.secondary.withOpacity(0.35) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: value ? AppColors.secondary.withOpacity(0.18) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: value ? AppColors.secondary.withOpacity(0.28) : AppColors.border),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: value ? AppColors.secondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ir a cuenta al agregar',
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Después de seleccionar la cantidad, volverá al detalle de la cuenta.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _AgregarProductosList extends StatelessWidget {
  const _AgregarProductosList({
    required this.productos,
    required this.processing,
    required this.cantidadEnVenta,
    required this.cantidadEnCuenta,
    required this.onAgregar,
  });

  final List<MeseroProductoModel> productos;
  final bool processing;
  final double Function(MeseroProductoModel producto) cantidadEnVenta;
  final double Function(MeseroProductoModel producto) cantidadEnCuenta;
  final ValueChanged<MeseroProductoModel>? onAgregar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            if (compact) {
              return Column(
                children: productos.asMap().entries.map((entry) {
                  final producto = entry.value;
                  return _AgregarProductoMobileRow(
                    producto: producto,
                    posicion: entry.key + 1,
                    cantidadVenta: cantidadEnVenta(producto),
                    cantidadCuenta: cantidadEnCuenta(producto),
                    onAgregar: processing || onAgregar == null ? null : () => onAgregar!(producto),
                  );
                }).toList(growable: false),
              );
            }

            final tableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 920 ? constraints.maxWidth : 920.0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    _buildHeader(),
                    ...productos.asMap().entries.map((entry) {
                      final producto = entry.value;
                      return _AgregarProductoTableRow(
                        producto: producto,
                        posicion: entry.key + 1,
                        cantidadVenta: cantidadEnVenta(producto),
                        cantidadCuenta: cantidadEnCuenta(producto),
                        onAgregar: processing || onAgregar == null ? null : () => onAgregar!(producto),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 54, child: _CuentaProductoHeaderCell('#')),
          SizedBox(width: 58, child: _CuentaProductoHeaderCell('Foto')),
          Expanded(flex: 4, child: _CuentaProductoHeaderCell('Producto')),
          SizedBox(width: 116, child: _CuentaProductoHeaderCell('Precio', alignEnd: true)),
          SizedBox(width: 120, child: _CuentaProductoHeaderCell('Pedido venta', alignEnd: true)),
          SizedBox(width: 120, child: _CuentaProductoHeaderCell('En cuenta', alignEnd: true)),
          SizedBox(width: 128, child: _CuentaProductoHeaderCell('Acción', alignEnd: true)),
        ],
      ),
    );
  }
}

class _AgregarProductoTableRow extends StatelessWidget {
  const _AgregarProductoTableRow({
    required this.producto,
    required this.posicion,
    required this.cantidadVenta,
    required this.cantidadCuenta,
    required this.onAgregar,
  });

  final MeseroProductoModel producto;
  final int posicion;
  final double cantidadVenta;
  final double cantidadCuenta;
  final VoidCallback? onAgregar;

  @override
  Widget build(BuildContext context) {
    final tipo = (producto.tipoProductoNombre ?? '').trim().isNotEmpty
        ? producto.tipoProductoNombre!.trim()
        : (producto.tipoProductoId == null ? 'Sin tipo' : 'Tipo ${producto.tipoProductoId}');
    final marca = (producto.marcaNombre ?? '').trim().isNotEmpty
        ? producto.marcaNombre!.trim()
        : (producto.marcaId == null ? 'Sin marca' : 'Marca ${producto.marcaId}');
    final descripcion = (producto.descripcion ?? '').trim();
    final yaPedido = cantidadVenta > 0.009;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onAgregar,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: yaPedido ? AppColors.secondary.withOpacity(0.14) : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: yaPedido ? AppColors.secondary.withOpacity(0.32) : AppColors.border),
                    ),
                    child: Text('#$posicion', style: TextStyle(color: yaPedido ? AppColors.secondaryDark : AppColors.textSecondary, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
              ),
              SizedBox(width: 58, child: _ProductImageThumb(value: producto.foto, size: 42)),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ProductoTag(icon: Icons.category_rounded, text: tipo),
                        _ProductoTag(icon: Icons.local_offer_rounded, text: marca),
                        if (descripcion.isNotEmpty)
                          _PedidoTag(
                            icon: Icons.notes_rounded,
                            text: descripcion.length > 36 ? '${descripcion.substring(0, 36)}...' : descripcion,
                            color: AppColors.surfaceAlt,
                            borderColor: AppColors.border,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 116, child: _CuentaProductoValueCell(CurrencyUtils.format(producto.precioVenta), alignEnd: true, strong: true)),
              SizedBox(width: 120, child: _CuentaProductoValueCell(_formatCantidadGeneral(cantidadVenta), alignEnd: true)),
              SizedBox(width: 120, child: _CuentaProductoValueCell(_formatCantidadGeneral(cantidadCuenta), alignEnd: true)),
              SizedBox(
                width: 128,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onAgregar,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgregarProductoMobileRow extends StatelessWidget {
  const _AgregarProductoMobileRow({
    required this.producto,
    required this.posicion,
    required this.cantidadVenta,
    required this.cantidadCuenta,
    required this.onAgregar,
  });

  final MeseroProductoModel producto;
  final int posicion;
  final double cantidadVenta;
  final double cantidadCuenta;
  final VoidCallback? onAgregar;

  @override
  Widget build(BuildContext context) {
    final tipo = (producto.tipoProductoNombre ?? '').trim().isNotEmpty
        ? producto.tipoProductoNombre!.trim()
        : (producto.tipoProductoId == null ? 'Sin tipo' : 'Tipo ${producto.tipoProductoId}');
    final marca = (producto.marcaNombre ?? '').trim().isNotEmpty
        ? producto.marcaNombre!.trim()
        : (producto.marcaId == null ? 'Sin marca' : 'Marca ${producto.marcaId}');

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onAgregar,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cantidadVenta > 0.009 ? AppColors.secondary.withOpacity(0.14) : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cantidadVenta > 0.009 ? AppColors.secondary.withOpacity(0.32) : AppColors.border),
                    ),
                    child: Text('#$posicion', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.secondaryDark)),
                  ),
                  const SizedBox(width: 8),
                  _ProductImageThumb(value: producto.foto, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _ProductoTag(icon: Icons.category_rounded, text: tipo),
                            _ProductoTag(icon: Icons.local_offer_rounded, text: marca),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _MobileMiniMetric(label: 'Precio', value: CurrencyUtils.format(producto.precioVenta))),
                  Expanded(child: _MobileMiniMetric(label: 'Pedido', value: _formatCantidadGeneral(cantidadVenta), alignEnd: true)),
                  Expanded(child: _MobileMiniMetric(label: 'Cuenta', value: _formatCantidadGeneral(cantidadCuenta), alignEnd: true)),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onAgregar,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar cantidad'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileMiniMetric extends StatelessWidget {
  const _MobileMiniMetric({required this.label, required this.value, this.alignEnd = false});

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
      ],
    );
  }
}

class _PedidoTag extends StatelessWidget {
  const _PedidoTag({required this.icon, required this.text, required this.color, required this.borderColor});

  final IconData icon;
  final String text;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.secondaryDark),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _ProductoTag extends StatelessWidget {
  const _ProductoTag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.secondaryDark),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          ],
        ),
      );
}


String _formatCantidadGeneral(num? value) {
  if (value == null) return '0';
  final number = value.toDouble();
  if (number % 1 == 0) return number.toInt().toString();
  return number.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

double _detalleProductoSubtotal(MeseroDetalleProductoModel producto) {
  final subtotal = producto.subtotal;
  if (subtotal != null) return subtotal;
  return (producto.cantidad ?? 0) * (producto.valorUnitario ?? 0);
}

List<_FacturaProductoAgrupado> _agruparProductosFactura(Iterable<MeseroDetalleProductoModel> productos) {
  final Map<String, _FacturaProductoAgrupado> agrupados = {};

  for (final producto in productos) {
    final nombre = (producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}').trim();
    final precioUnitario = producto.valorUnitario ?? 0;
    final key = '${producto.productoId ?? nombre}|$nombre|${precioUnitario.toStringAsFixed(2)}';
    final cantidad = producto.cantidad ?? 0;
    final subtotal = _detalleProductoSubtotal(producto);

    final actual = agrupados[key];
    if (actual == null) {
      agrupados[key] = _FacturaProductoAgrupado(
        productoId: producto.productoId,
        nombre: nombre,
        cantidad: cantidad.toDouble(),
        precioUnitario: precioUnitario,
        total: subtotal,
      );
    } else {
      agrupados[key] = actual.copyWith(
        cantidad: actual.cantidad + cantidad.toDouble(),
        total: actual.total + subtotal,
      );
    }
  }

  final values = agrupados.values.toList(growable: false);
  values.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
  return values;
}

class _DetalleHistorialVentaPage extends StatelessWidget {
  const _DetalleHistorialVentaPage({required this.venta});

  final MeseroVentaModel venta;

  @override
  Widget build(BuildContext context) {
    final descripcion = (venta.mesaDescripcion ?? '').trim();
    final productos = _agruparProductosFactura(venta.cuentas.expand((cuenta) => cuenta.productos));
    final pagos = venta.cuentas.expand((cuenta) => cuenta.pagos.map((pago) => (cuenta: cuenta, pago: pago))).toList(growable: false);
    final totalProductos = venta.cuentas.fold<double>(0, (sum, cuenta) => sum + (cuenta.subtotalProductos ?? cuenta.productos.fold<double>(0, (acc, producto) => acc + _detalleProductoSubtotal(producto))));
    final totalPropina = venta.propina ?? venta.cuentas.fold<double>(0, (sum, cuenta) => sum + (cuenta.propina ?? 0));
    final totalCambio = pagos.fold<double>(0, (sum, item) => sum + (item.pago.cambio ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle venta #${venta.ventaId ?? '-'}'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, descripcion, pagos.length),
                  const SizedBox(height: 16),
                  _buildResumen(context, totalProductos, totalPropina, totalCambio, pagos.length),
                  const SizedBox(height: 16),
                  _buildProductosVendidos(context, productos),
                  const SizedBox(height: 16),
                  _buildPagos(context, pagos),
                  const SizedBox(height: 16),
                  _buildCuentas(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String descripcion, int pagosRegistrados) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalle de venta',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          descripcion.isEmpty ? 'Venta registrada sin descripción de mesa.' : descripcion,
          style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
        ),
      ],
    );
    final details = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SmallInfoPill(icon: Icons.table_restaurant_rounded, text: 'Mesa ${venta.mesaNumero ?? venta.mesaId ?? '-'}'),
        _SmallInfoPill(icon: Icons.confirmation_number_rounded, text: 'Venta #${venta.ventaId ?? '-'}'),
        _SmallInfoPill(icon: Icons.call_split_rounded, text: '${venta.cuentas.length} cuentas'),
        _SmallInfoPill(icon: Icons.payments_rounded, text: '$pagosRegistrados pagos'),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        gradient: AppColors.softTechGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.9))),
      ),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), details])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.90), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.secondaryDark),
                ),
                const SizedBox(width: 14),
                Expanded(child: title),
                const SizedBox(width: 12),
                Flexible(child: Align(alignment: Alignment.topRight, child: details)),
              ],
            ),
    );
  }

  Widget _buildResumen(BuildContext context, double totalProductos, double totalPropina, double totalCambio, int pagosRegistrados) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text('Resumen de la venta', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          _detalleLinea('Fecha', (venta.fecha ?? '').trim().isEmpty ? '-' : venta.fecha!),
          _detalleLinea('Estado', venta.estado ?? '-'),
          _detalleLinea('Cuentas / cuotas', venta.cuentas.length.toString()),
          _detalleLinea('Pagos registrados', pagosRegistrados.toString()),
          const Divider(height: 18),
          _detalleLinea('Subtotal productos', CurrencyUtils.format(totalProductos)),
          _detalleLinea('Propina', CurrencyUtils.format(totalPropina)),
          _detalleLinea('Total venta', CurrencyUtils.format(venta.total), destacado: true),
          _detalleLinea('Total pagado', CurrencyUtils.format(venta.totalPagado)),
          if (totalCambio > 0) _detalleLinea('Vueltas entregadas', CurrencyUtils.format(totalCambio)),
          _detalleLinea('Saldo pendiente', CurrencyUtils.format(venta.saldoPendiente), destacado: true, danger: (venta.saldoPendiente ?? 0) > 0.009),
        ],
      ),
    );
  }

  Widget _buildProductosVendidos(BuildContext context, List<_FacturaProductoAgrupado> productos) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text('Lo vendido', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          if (productos.isEmpty)
            const Text('Esta venta no tiene productos registrados.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          else if (compact)
            Column(children: productos.map(_productoMovil).toList(growable: false))
          else
            _productosTabla(productos),
        ],
      ),
    );
  }

  Widget _productosTabla(List<_FacturaProductoAgrupado> productos) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
          child: const Row(
            children: [
              SizedBox(width: 82, child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
              Expanded(flex: 4, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
              Expanded(flex: 2, child: Text('Precio', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
              SizedBox(width: 18),
              Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...productos.map((producto) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: AppColors.background.withOpacity(0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border.withOpacity(0.75))),
              child: Row(
                children: [
                  SizedBox(width: 82, child: Text(_formatCantidadGeneral(producto.cantidad), style: const TextStyle(fontWeight: FontWeight.w900))),
                  Expanded(flex: 4, child: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Expanded(flex: 2, child: Text(CurrencyUtils.format(producto.precioUnitario), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: Text(CurrencyUtils.format(producto.total), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
                ],
              ),
            )),
      ],
    );
  }

  Widget _productoMovil(_FacturaProductoAgrupado producto) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background.withOpacity(0.65), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniDato('Cantidad', _formatCantidadGeneral(producto.cantidad))),
              Expanded(child: _miniDato('Precio', CurrencyUtils.format(producto.precioUnitario))),
              Expanded(child: _miniDato('Total', CurrencyUtils.format(producto.total), alignEnd: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagos(BuildContext context, List<({MeseroCuentaModel cuenta, MeseroPagoModel pago})> pagos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text('Cómo se pagó', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          if (pagos.isEmpty)
            const Text('No hay pagos registrados para esta venta.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          else
            Column(
              children: pagos.map((item) {
                final pago = item.pago;
                final cuenta = item.cuenta;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.background.withOpacity(0.65), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pago.medioPagoNombre ?? 'Medio ${pago.medioPagoId ?? '-'}',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(CurrencyUtils.format(pago.valor), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SmallInfoPill(icon: Icons.receipt_long_rounded, text: _cuentaNombreVisible(cuenta)),
                          if ((pago.fecha ?? '').trim().isNotEmpty) _SmallInfoPill(icon: Icons.event_rounded, text: pago.fecha!),
                          if ((pago.valorRecibido ?? 0) > 0) _SmallInfoPill(icon: Icons.input_rounded, text: 'Recibido ${CurrencyUtils.format(pago.valorRecibido)}'),
                          if ((pago.cambio ?? 0) > 0) _SmallInfoPill(icon: Icons.reply_rounded, text: 'Vueltas ${CurrencyUtils.format(pago.cambio)}'),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildCuentas(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.call_split_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text('Cuentas / cuotas de la venta', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          ...venta.cuentas.map((cuenta) {
            final descripcion = (cuenta.descripcion ?? '').trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => _HistorialCuentaDetallePage(venta: venta, cuenta: cuenta),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _cuentaEtiquetaVisible(cuenta),
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryDark),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SmallInfoPill(icon: Icons.shopping_bag_rounded, text: '${cuenta.productos.length} productos'),
                          _SmallInfoPill(icon: Icons.payments_rounded, text: 'Total ${CurrencyUtils.format(cuenta.total)}'),
                          _SmallInfoPill(icon: Icons.account_balance_wallet_rounded, text: 'Pagado ${CurrencyUtils.format(cuenta.totalPagado)}'),
                          _SmallInfoPill(
                            icon: cuenta.pagada == true ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                            text: cuenta.pagada == true ? 'Pagada' : 'Saldo ${CurrencyUtils.format(cuenta.saldoPendiente)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _miniDato(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _detalleLinea(String label, String value, {bool destacado = false, bool danger = false}) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: danger ? AppColors.danger : AppColors.textSecondary, fontWeight: destacado ? FontWeight.w900 : FontWeight.w700))),
          Text(value, style: TextStyle(color: color, fontWeight: destacado ? FontWeight.w900 : FontWeight.w800, fontSize: destacado ? 16 : 14)),
        ],
      ),
    );
  }
}

class _HistorialCuentaDetallePage extends StatelessWidget {
  const _HistorialCuentaDetallePage({required this.venta, required this.cuenta});

  final MeseroVentaModel venta;
  final MeseroCuentaModel cuenta;

  @override
  Widget build(BuildContext context) {
    final descripcion = (cuenta.descripcion ?? '').trim();
    final productos = _agruparProductosFactura(cuenta.productos);
    final cambioTotal = cuenta.pagos.fold<double>(0, (sum, pago) => sum + (pago.cambio ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(_cuentaNombreVisible(cuenta)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.softTechGradient,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de cuenta pagada',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descripcion.isEmpty ? 'Cuenta sin descripción.' : descripcion,
                      style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SmallInfoPill(icon: Icons.table_restaurant_rounded, text: 'Mesa ${venta.mesaNumero ?? venta.mesaId ?? '-'}'),
                        _SmallInfoPill(icon: Icons.confirmation_number_rounded, text: 'Venta #${venta.ventaId ?? '-'}'),
                        _SmallInfoPill(icon: Icons.receipt_long_rounded, text: _cuentaNombreVisible(cuenta)),
                        _SmallInfoPill(
                          icon: cuenta.pagada == true ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                          text: cuenta.pagada == true ? 'Pagada' : 'Saldo ${CurrencyUtils.format(cuenta.saldoPendiente)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildResumenCuenta(context, cambioTotal),
              const SizedBox(height: 16),
              _buildProductosCuenta(context, productos),
              const SizedBox(height: 16),
              _buildPagosCuenta(context, cambioTotal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumenCuenta(BuildContext context, double cambioTotal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text('Resumen de la cuenta', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          _lineaResumen('Subtotal productos', CurrencyUtils.format(cuenta.subtotalProductos)),
          _lineaResumen('Propina', CurrencyUtils.format(cuenta.propina)),
          _lineaResumen('Total cuenta', CurrencyUtils.format(cuenta.total), destacado: true),
          _lineaResumen('Total pagado', CurrencyUtils.format(cuenta.totalPagado)),
          if (cambioTotal > 0) _lineaResumen('Vueltas entregadas', CurrencyUtils.format(cambioTotal)),
          _lineaResumen('Saldo pendiente', CurrencyUtils.format(cuenta.saldoPendiente), destacado: true, danger: (cuenta.saldoPendiente ?? 0) > 0.009),
        ],
      ),
    );
  }

  Widget _buildProductosCuenta(BuildContext context, List<_FacturaProductoAgrupado> productos) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text('Productos de esta cuenta', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          if (productos.isEmpty)
            const Text('Esta cuenta no tiene productos registrados.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          else if (compact)
            Column(children: productos.map(_productoMovil).toList(growable: false))
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                  child: const Row(
                    children: [
                      SizedBox(width: 82, child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
                      Expanded(flex: 4, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
                      Expanded(flex: 2, child: Text('Precio', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
                      SizedBox(width: 18),
                      Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ...productos.map((producto) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.background.withOpacity(0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border.withOpacity(0.75))),
                      child: Row(
                        children: [
                          SizedBox(width: 82, child: Text(_formatCantidadGeneral(producto.cantidad), style: const TextStyle(fontWeight: FontWeight.w900))),
                          Expanded(flex: 4, child: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w800))),
                          Expanded(flex: 2, child: Text(CurrencyUtils.format(producto.precioUnitario), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                          const SizedBox(width: 18),
                          Expanded(flex: 2, child: Text(CurrencyUtils.format(producto.total), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
                        ],
                      ),
                    )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _productoMovil(_FacturaProductoAgrupado producto) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background.withOpacity(0.65), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniDato('Cantidad', _formatCantidadGeneral(producto.cantidad))),
              Expanded(child: _miniDato('Precio', CurrencyUtils.format(producto.precioUnitario))),
              Expanded(child: _miniDato('Total', CurrencyUtils.format(producto.total), alignEnd: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagosCuenta(BuildContext context, double cambioTotal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text('Pagos de esta cuenta', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          if (cuenta.pagos.isEmpty)
            const Text('No hay pagos registrados para esta cuenta.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          else
            ...cuenta.pagos.map((pago) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.background.withOpacity(0.65), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(pago.medioPagoNombre ?? 'Medio ${pago.medioPagoId ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w900))),
                          Text(CurrencyUtils.format(pago.valor), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if ((pago.fecha ?? '').trim().isNotEmpty) _SmallInfoPill(icon: Icons.event_rounded, text: pago.fecha!),
                          if ((pago.valorRecibido ?? 0) > 0) _SmallInfoPill(icon: Icons.input_rounded, text: 'Recibido ${CurrencyUtils.format(pago.valorRecibido)}'),
                          if ((pago.cambio ?? 0) > 0) _SmallInfoPill(icon: Icons.reply_rounded, text: 'Vueltas ${CurrencyUtils.format(pago.cambio)}'),
                        ],
                      ),
                    ],
                  ),
                )),
          if (cambioTotal > 0) ...[
            const SizedBox(height: 8),
            _lineaResumen('Total vueltas', CurrencyUtils.format(cambioTotal), destacado: true),
          ],
        ],
      ),
    );
  }

  Widget _miniDato(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _lineaResumen(String label, String value, {bool destacado = false, bool danger = false}) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: danger ? AppColors.danger : AppColors.textSecondary, fontWeight: destacado ? FontWeight.w900 : FontWeight.w700))),
          Text(value, style: TextStyle(color: color, fontWeight: destacado ? FontWeight.w900 : FontWeight.w800, fontSize: destacado ? 16 : 14)),
        ],
      ),
    );
  }
}

class _HistorialMesaSection extends StatelessWidget {
  const _HistorialMesaSection({required this.mesa, required this.ventas, required this.onVerDetalle});

  final String mesa;
  final List<MeseroVentaModel> ventas;
  final ValueChanged<MeseroVentaModel> onVerDetalle;

  @override
  Widget build(BuildContext context) {
    final total = ventas.fold<double>(0, (sum, venta) => sum + (venta.total ?? 0));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(mesa, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              ),
              _SmallInfoPill(icon: Icons.receipt_long_rounded, text: '${ventas.length} ventas'),
              const SizedBox(width: 8),
              _TotalPill(total: total),
            ],
          ),
          const SizedBox(height: 12),
          ...ventas.map(
            (venta) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.point_of_sale_rounded, color: AppColors.secondaryDark),
                title: Text('Venta #${venta.ventaId ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text([
                  if ((venta.fecha ?? '').trim().isNotEmpty) venta.fecha!,
                  'Estado: ${venta.estado ?? '-'}',
                  '${venta.cuentas.length} cuentas',
                ].join(' · ')),
                trailing: Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(CurrencyUtils.format(venta.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                    OutlinedButton.icon(
                      onPressed: () => onVerDetalle(venta),
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Ver detalle'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


bool _esMedioPagoEfectivo(MeseroMedioPagoModel? medio) {
  if (medio == null) return false;
  String normalize(String? value) {
    final text = (value ?? '').toLowerCase().trim();
    return text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  final nombre = normalize(medio.nombre);
  final descripcion = normalize(medio.descripcion);
  return nombre.contains('efectivo') || descripcion.contains('efectivo') || nombre.contains('cash') || descripcion.contains('cash');
}

MeseroMedioPagoModel? _medioPagoById(List<MeseroMedioPagoModel> mediosPago, int? medioPagoId) {
  if (medioPagoId == null) return null;
  for (final medio in mediosPago) {
    if (medio.medioPagoId == medioPagoId) return medio;
  }
  return null;
}

int? _defaultMedioPagoId(List<MeseroMedioPagoModel> mediosPago) {
  for (final medio in mediosPago) {
    if (_esMedioPagoEfectivo(medio) && medio.medioPagoId != null) return medio.medioPagoId;
  }
  return mediosPago.isNotEmpty ? mediosPago.first.medioPagoId : null;
}

class _PagoFormRowData {
  _PagoFormRowData({required this.mediosPago, int? medioPagoId, double? valor, double? valorRecibido})
      : medioPagoId = medioPagoId ?? _defaultMedioPagoId(mediosPago),
        valorController = TextEditingController(text: valor == null || valor <= 0 ? '' : _formatCurrencyInputAmount(valor)),
        valorRecibidoController = TextEditingController(
          text: valorRecibido == null || valorRecibido <= 0
              ? (valor == null || valor <= 0 ? '' : _formatCurrencyInputAmount(valor))
              : _formatCurrencyInputAmount(valorRecibido),
        );

  final List<MeseroMedioPagoModel> mediosPago;
  int? medioPagoId;
  final TextEditingController valorController;
  final TextEditingController valorRecibidoController;

  MeseroMedioPagoModel? get medioPago => _medioPagoById(mediosPago, medioPagoId);

  bool get esEfectivo => _esMedioPagoEfectivo(medioPago);

  void dispose() {
    valorController.dispose();
    valorRecibidoController.dispose();
  }
}

class _PagoCuentaFormResult {
  const _PagoCuentaFormResult({
    required this.medioPagoId,
    required this.valor,
    this.valorRecibido,
    this.cambio,
  });

  final int medioPagoId;
  final double valor;
  final double? valorRecibido;
  final double? cambio;
}

class _PagarCuentaResult {
  const _PagarCuentaResult({required this.propina, required this.pagos});
  final double propina;
  final List<_PagoCuentaFormResult> pagos;
}

class _FacturaProductoAgrupado {
  const _FacturaProductoAgrupado({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    this.productoId,
  });

  final int? productoId;
  final String nombre;
  final double cantidad;
  final double precioUnitario;
  final double total;

  _FacturaProductoAgrupado copyWith({double? cantidad, double? total}) => _FacturaProductoAgrupado(
        productoId: productoId,
        nombre: nombre,
        cantidad: cantidad ?? this.cantidad,
        precioUnitario: precioUnitario,
        total: total ?? this.total,
      );
}

class _PagarCuentaDialog extends StatefulWidget {
  const _PagarCuentaDialog({required this.venta, required this.cuenta, required this.mediosPago, this.mostrarComoPagina = false});

  final MeseroVentaModel venta;
  final MeseroCuentaModel cuenta;
  final List<MeseroMedioPagoModel> mediosPago;
  final bool mostrarComoPagina;

  @override
  State<_PagarCuentaDialog> createState() => _PagarCuentaDialogState();
}

class _PagarCuentaDialogState extends State<_PagarCuentaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _propinaController;
  late final List<_PagoFormRowData> _pagos;
  late double _ultimaPropinaSincronizada;

  @override
  void initState() {
    super.initState();
    final propina = widget.cuenta.propina ?? 0;
    _ultimaPropinaSincronizada = propina.toDouble();
    _propinaController = TextEditingController(text: propina <= 0 ? '' : _formatCurrencyInputAmount(propina.toDouble()));
    final saldoNuevo = _totalPendienteInicial();
    _pagos = [
      _PagoFormRowData(
        mediosPago: widget.mediosPago,
        valor: saldoNuevo > 0 ? saldoNuevo : null,
      ),
    ];
  }

  @override
  void dispose() {
    _propinaController.dispose();
    for (final pago in _pagos) {
      pago.dispose();
    }
    super.dispose();
  }

  double _parse(String value) => _parseCurrencyInput(value);

  double get _propina => _parse(_propinaController.text);

  List<MeseroDetalleProductoModel> get _productosPendientes =>
      widget.cuenta.productos.where((producto) => producto.pagado != true).toList(growable: false);

  List<MeseroDetalleProductoModel> get _productosPagados =>
      widget.cuenta.productos.where((producto) => producto.pagado == true).toList(growable: false);

  double get _subtotalProductos =>
      _productosPendientes.fold<double>(0, (sum, producto) => sum + _detalleSubtotal(producto));

  double get _subtotalProductosPagados =>
      _productosPagados.fold<double>(0, (sum, producto) => sum + _detalleSubtotal(producto));

  double get _propinaPagadaEstimada {
    final totalPagado = widget.cuenta.totalPagado ?? 0;
    final pagadoSinProductos = (totalPagado - _subtotalProductosPagados).clamp(0, double.infinity).toDouble();
    final propinaActual = widget.cuenta.propina ?? 0;
    return pagadoSinProductos.clamp(0, propinaActual).toDouble();
  }

  double get _propinaPendiente => (_propina - _propinaPagadaEstimada).clamp(0, double.infinity).toDouble();

  double get _totalYaPagado => widget.cuenta.totalPagado ?? 0;

  double get _totalPendienteOriginal => widget.cuenta.saldoPendiente ??
      ((widget.cuenta.total ?? 0) - (widget.cuenta.totalPagado ?? 0)).clamp(0, double.infinity).toDouble();

  List<_FacturaProductoAgrupado> get _productosAgrupadosFactura => _agruparProductosFactura(_productosPendientes);

  double get _totalCuenta {
    final nuevoSaldoCalculado = _subtotalProductos + _propinaPendiente;
    if (nuevoSaldoCalculado > 0) return nuevoSaldoCalculado;
    return _totalPendienteOriginal > 0 ? _totalPendienteOriginal : 0;
  }

  double get _totalPagos => _pagos.fold<double>(0, (sum, pago) => sum + _parse(pago.valorController.text));

  double get _totalRecibido => _pagos.where((pago) => pago.esEfectivo).fold<double>(0, (sum, pago) => sum + _parse(pago.valorRecibidoController.text));

  double get _totalCambio => _pagos.where((pago) => pago.esEfectivo).fold<double>(0, (sum, pago) => sum + _cambioPago(pago));

  double get _saldo => (_totalCuenta - _totalPagos).clamp(0, double.infinity).toDouble();

  bool get _hayEfectivoConValorRecibidoInvalido => _pagos.any((pago) {
        if (!pago.esEfectivo) return false;
        return _parse(pago.valorRecibidoController.text) + 0.009 < _parse(pago.valorController.text);
      });

  double _totalPendienteInicial() => _totalCuenta;

  double _detalleSubtotal(MeseroDetalleProductoModel producto) => _detalleProductoSubtotal(producto);

  double _cambioPago(_PagoFormRowData pago) {
    if (!pago.esEfectivo) return 0;
    final recibido = _parse(pago.valorRecibidoController.text);
    final valor = _parse(pago.valorController.text);
    return (recibido - valor).clamp(0, double.infinity).toDouble();
  }

  double _totalPagosExcluyendo(_PagoFormRowData pagoActual) {
    return _pagos.where((pago) => !identical(pago, pagoActual)).fold<double>(0, (sum, pago) => sum + _parse(pago.valorController.text));
  }

  double _saldoPendienteParaPago(_PagoFormRowData pago) {
    return (_totalCuenta - _totalPagosExcluyendo(pago)).clamp(0, double.infinity).toDouble();
  }

  String _formatInputAmount(double value) => _formatCurrencyInputAmount(value);

  bool _sameAmount(double a, double b) => (a - b).abs() <= 0.009;

  void _sincronizarPagosPorCambioPropina() {
    final nuevaPropina = _propina;
    final diferencia = nuevaPropina - _ultimaPropinaSincronizada;
    if (_sameAmount(diferencia, 0)) {
      _ultimaPropinaSincronizada = nuevaPropina;
      return;
    }

    _ultimaPropinaSincronizada = nuevaPropina;
    if (_pagos.isEmpty) return;

    if (diferencia > 0) {
      _incrementarUltimoPago(diferencia);
    } else {
      _disminuirPagosDesdeElUltimo(diferencia.abs());
    }
  }

  void _incrementarUltimoPago(double diferencia) {
    final pago = _pagos.lastWhere(
      (item) => _parse(item.valorController.text) > 0,
      orElse: () => _pagos.last,
    );
    final valorActual = _parse(pago.valorController.text);
    final recibidoActual = _parse(pago.valorRecibidoController.text);
    final estabaRecibidoAutomatico = pago.esEfectivo &&
        (pago.valorRecibidoController.text.trim().isEmpty || recibidoActual <= 0 || _sameAmount(recibidoActual, valorActual));
    final nuevoValor = valorActual + diferencia;

    pago.valorController.text = _formatInputAmount(nuevoValor);
    if (pago.esEfectivo && (estabaRecibidoAutomatico || recibidoActual + 0.009 < nuevoValor)) {
      pago.valorRecibidoController.text = _formatInputAmount(nuevoValor);
    }
  }

  void _disminuirPagosDesdeElUltimo(double diferencia) {
    var pendientePorDescontar = diferencia;

    for (final pago in _pagos.reversed) {
      if (pendientePorDescontar <= 0.009) break;

      final valorActual = _parse(pago.valorController.text);
      if (valorActual <= 0) continue;

      final recibidoActual = _parse(pago.valorRecibidoController.text);
      final estabaRecibidoAutomatico = pago.esEfectivo &&
          (pago.valorRecibidoController.text.trim().isEmpty || recibidoActual <= 0 || _sameAmount(recibidoActual, valorActual));
      final descuento = valorActual < pendientePorDescontar ? valorActual : pendientePorDescontar;
      final nuevoValor = valorActual - descuento;

      pago.valorController.text = _formatInputAmount(nuevoValor);
      if (pago.esEfectivo && estabaRecibidoAutomatico) {
        pago.valorRecibidoController.text = _formatInputAmount(nuevoValor);
      }

      pendientePorDescontar -= descuento;
    }
  }

  void _completarValorPagoConSaldoPendiente(_PagoFormRowData pago, {bool sobrescribir = false}) {
    final valorActual = _parse(pago.valorController.text);
    if (!sobrescribir && valorActual > 0) return;

    final saldoPendiente = _saldoPendienteParaPago(pago);
    if (saldoPendiente <= 0) return;

    pago.valorController.text = _formatInputAmount(saldoPendiente);
  }

  void _completarEfectivoConSaldoPendiente(_PagoFormRowData pago, {bool sobrescribirValor = false}) {
    if (!pago.esEfectivo) return;

    _completarValorPagoConSaldoPendiente(pago, sobrescribir: sobrescribirValor);

    if (pago.valorRecibidoController.text.trim().isEmpty) {
      pago.valorRecibidoController.text = pago.valorController.text;
    }
  }

  void _completarPagosEfectivoPendientes() {
    for (final pago in _pagos) {
      _completarEfectivoConSaldoPendiente(pago);
    }
  }

  String _formatCantidad(num? value) => _formatCantidadGeneral(value);

  void _agregarMedioPago() {
    final saldoPendiente = _saldo;
    setState(() {
      _pagos.add(_PagoFormRowData(
        mediosPago: widget.mediosPago,
        valor: saldoPendiente > 0 ? saldoPendiente : null,
      ));
    });
  }

  void _quitarMedioPago(int index) {
    if (_pagos.length == 1) return;
    final removed = _pagos.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  _PagarCuentaResult _crearResultadoPago() {
    return _PagarCuentaResult(
      propina: _propina,
      pagos: _pagos
          .where((pago) => pago.medioPagoId != null && _parse(pago.valorController.text) > 0)
          .map((pago) {
            final valor = _parse(pago.valorController.text);
            final recibido = pago.esEfectivo ? _parse(pago.valorRecibidoController.text) : null;
            return _PagoCuentaFormResult(
              medioPagoId: pago.medioPagoId!,
              valor: valor,
              valorRecibido: recibido,
              cambio: recibido == null ? null : (recibido - valor).clamp(0, double.infinity).toDouble(),
            );
          })
          .toList(growable: false),
    );
  }

  void _guardarPago() {
    _completarPagosEfectivoPendientes();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_totalPagos > _totalCuenta + 0.009) return;
    if (_hayEfectivoConValorRecibidoInvalido) return;
    Navigator.of(context).pop(_crearResultadoPago());
  }

  Widget _buildFormularioPago(
    BuildContext context, {
    required String descripcion,
    required bool incluirHeader,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          mainAxisSize: incluirHeader ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (incluirHeader) ...[
              _buildDialogHeader(descripcion),
              const SizedBox(height: 16),
            ],
            _buildProductosFactura(context),
            const SizedBox(height: 16),
            _buildPropinaFactura(),
            const SizedBox(height: 16),
            _buildMediosPagoFactura(context),
            const SizedBox(height: 16),
            _buildResumenPagoFinal(context),
            if (_totalPagos > _totalCuenta + 0.009)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'El valor aplicado no puede superar el nuevo saldo pendiente de la cuenta.',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800),
                ),
              ),
            if (_hayEfectivoConValorRecibidoInvalido)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'En efectivo, el valor recibido no puede ser menor al valor que se aplica.',
                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraAccionesPantalla() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.95))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, -6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _guardarPago,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar pago'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final descripcion = (widget.cuenta.descripcion ?? '').trim();

    if (widget.mostrarComoPagina) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Pagar cuenta'),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _buildFormularioPago(
                  context,
                  descripcion: descripcion,
                  incluirHeader: true,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                ),
              ),
              _buildBarraAccionesPantalla(),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      actionsPadding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: _buildDialogHeader(descripcion),
      content: SizedBox(
        width: 920,
        child: _buildFormularioPago(context, descripcion: descripcion, incluirHeader: false),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _guardarPago,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Guardar pago'),
        ),
      ],
    );
  }


  Widget _buildDialogHeader(String descripcion) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Factura de cobro',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          descripcion.isEmpty ? 'Registra el pago de la cuenta seleccionada.' : descripcion,
          style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
        ),
      ],
    );
    final details = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SmallInfoPill(icon: Icons.table_restaurant_rounded, text: 'Mesa ${widget.venta.mesaNumero ?? widget.venta.mesaId ?? '-'}'),
        _SmallInfoPill(icon: Icons.receipt_long_rounded, text: _cuentaEtiquetaVisible(widget.cuenta)),
        _SmallInfoPill(icon: Icons.confirmation_number_rounded, text: 'Venta #${widget.venta.ventaId ?? '-'}'),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        gradient: AppColors.softTechGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.9))),
      ),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), details])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.90), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.secondaryDark),
                ),
                const SizedBox(width: 14),
                Expanded(child: title),
                const SizedBox(width: 12),
                Flexible(child: Align(alignment: Alignment.topRight, child: details)),
              ],
            ),
    );
  }

  Widget _buildProductosFactura(BuildContext context) {
    final productos = _productosAgrupadosFactura;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text('Productos nuevos por cobrar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              Text(CurrencyUtils.format(_subtotalProductos), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.secondaryDark)),
            ],
          ),
          const SizedBox(height: 12),
          if (productos.isEmpty)
            const Text('No hay productos nuevos pendientes por cobrar en esta cuenta.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          else if (MediaQuery.sizeOf(context).width < 760)
            _buildProductosMovil(productos)
          else
            _buildProductosTabla(productos),
        ],
      ),
    );
  }

  Widget _buildProductosTabla(List<_FacturaProductoAgrupado> productos) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
          child: const Row(
            children: [
              SizedBox(width: 82, child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
              Expanded(flex: 4, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
              Expanded(flex: 2, child: Text('Precio', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
              SizedBox(width: 18),
              Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...productos.map((producto) {
          final nombre = producto.nombre;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: AppColors.background.withOpacity(0.55), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border.withOpacity(0.75))),
            child: Row(
              children: [
                SizedBox(width: 82, child: Text(_formatCantidad(producto.cantidad), style: const TextStyle(fontWeight: FontWeight.w900))),
                Expanded(flex: 4, child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text(CurrencyUtils.format(producto.precioUnitario), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: Text(CurrencyUtils.format(producto.total), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProductosMovil(List<_FacturaProductoAgrupado> productos) {
    return Column(
      children: productos.map((producto) {
        final nombre = producto.nombre;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.background.withOpacity(0.65), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _miniDatoFactura('Cantidad', _formatCantidad(producto.cantidad))),
                  Expanded(child: _miniDatoFactura('Precio', CurrencyUtils.format(producto.precioUnitario))),
                  Expanded(child: _miniDatoFactura('Total', CurrencyUtils.format(producto.total), alignEnd: true)),
                ],
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _miniDatoFactura(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildPropinaFactura() {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Propina de la cuenta', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        SizedBox(height: 4),
        Text('Solo se cobra la propina nueva o el aumento pendiente. Lo ya pagado no se vuelve a cobrar.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
    final field = TextFormField(
      controller: _propinaController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _currencyInputFormatters,
      decoration: const InputDecoration(
        labelText: 'Valor propina',
        hintText: 'Ejemplo: 5.000',
        prefixIcon: Icon(Icons.volunteer_activism_rounded),
      ),
      onChanged: (_) => setState(_sincronizarPagosPorCambioPropina),
      validator: (value) => _parse(value ?? '') < 0 ? 'La propina no puede ser negativa' : null,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: compact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 12), field])
          : Row(children: [Expanded(child: text), const SizedBox(width: 16), SizedBox(width: 260, child: field)]),
    );
  }

  Widget _buildMediosPagoFactura(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Medios de pago', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              OutlinedButton.icon(
                onPressed: _agregarMedioPago,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar medio'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Registra cómo va a pagar el cliente. En efectivo se muestra con cuánto paga y las vueltas.',
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...List.generate(_pagos.length, _buildMedioPagoCard),
        ],
      ),
    );
  }

  Widget _buildMedioPagoCard(int index) {
    final pago = _pagos[index];
    final compact = MediaQuery.sizeOf(context).width < 860;
    final medioField = DropdownButtonFormField<int>(
      value: widget.mediosPago.any((medio) => medio.medioPagoId == pago.medioPagoId) ? pago.medioPagoId : null,
      decoration: const InputDecoration(
        labelText: 'Medio de pago',
        prefixIcon: Icon(Icons.payments_rounded),
      ),
      items: widget.mediosPago
          .where((medio) => medio.medioPagoId != null)
          .map((medio) => DropdownMenuItem<int>(
                value: medio.medioPagoId,
                child: Text(medio.nombre ?? 'Medio ${medio.medioPagoId}'),
              ))
          .toList(growable: false),
      onChanged: (value) => setState(() {
        pago.medioPagoId = value;
        if (pago.esEfectivo) {
          _completarEfectivoConSaldoPendiente(pago);
        } else {
          pago.valorRecibidoController.clear();
        }
      }),
      validator: (value) => value == null ? 'Selecciona un medio de pago' : null,
    );
    final valueField = TextFormField(
      controller: pago.valorController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _currencyInputFormatters,
      decoration: const InputDecoration(
        labelText: 'Valor que paga con este medio',
        hintText: 'Ejemplo: 25.000',
        prefixIcon: Icon(Icons.attach_money_rounded),
      ),
      onChanged: (_) => setState(() {
        if (pago.esEfectivo && pago.valorRecibidoController.text.trim().isEmpty) {
          pago.valorRecibidoController.text = pago.valorController.text;
        }
      }),
      validator: (value) => _parse(value ?? '') <= 0 ? 'Ingresa un valor mayor a cero' : null,
    );
    final receivedField = TextFormField(
      controller: pago.valorRecibidoController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _currencyInputFormatters,
      decoration: const InputDecoration(
        labelText: 'Con cuánto paga en efectivo',
        hintText: 'Ejemplo: 30.000',
        prefixIcon: Icon(Icons.payments_outlined),
      ),
      onChanged: (_) => setState(() {
        _completarValorPagoConSaldoPendiente(pago);
      }),
      validator: (value) {
        if (!pago.esEfectivo) return null;
        final recibido = _parse(value ?? '');
        final aplicado = _parse(pago.valorController.text);
        if (recibido <= 0) return 'Ingresa el valor recibido';
        if (recibido + 0.009 < aplicado) return 'No puede ser menor al valor aplicado';
        return null;
      },
    );
    final removeButton = IconButton.filledTonal(
      tooltip: 'Quitar medio de pago',
      onPressed: _pagos.length == 1 ? null : () => _quitarMedioPago(index),
      icon: const Icon(Icons.delete_outline_rounded),
    );
    final encabezado = Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Center(child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.secondaryDark))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text('Pago ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900))),
        removeButton,
      ],
    );
    final changeBox = _buildCambioBox(pago);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                encabezado,
                const SizedBox(height: 10),
                medioField,
                const SizedBox(height: 10),
                valueField,
                if (pago.esEfectivo) ...[
                  const SizedBox(height: 10),
                  receivedField,
                  const SizedBox(height: 10),
                  changeBox,
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                encabezado,
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: medioField),
                    const SizedBox(width: 10),
                    Expanded(child: valueField),
                    if (pago.esEfectivo) ...[
                      const SizedBox(width: 10),
                      Expanded(child: receivedField),
                    ],
                  ],
                ),
                if (pago.esEfectivo) ...[
                  const SizedBox(height: 10),
                  changeBox,
                ],
              ],
            ),
    );
  }

  Widget _buildCambioBox(_PagoFormRowData pago) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.successSoft.withOpacity(0.75), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.success.withOpacity(0.25))),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          const Expanded(child: Text('Vueltas a entregar', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
          Text(CurrencyUtils.format(_cambioPago(pago)), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildResumenPagoFinal(BuildContext context) {
    final completado = _saldo <= 0.009 && _totalPagos <= _totalCuenta + 0.009 && !_hayEfectivoConValorRecibidoInvalido;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completado ? AppColors.successSoft.withOpacity(0.65) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: completado ? AppColors.success.withOpacity(0.30) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(completado ? Icons.check_circle_rounded : Icons.calculate_rounded, color: completado ? AppColors.success : AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(child: Text('Resumen de pago', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
              Text(completado ? 'Listo para guardar' : 'Pendiente', style: TextStyle(fontWeight: FontWeight.w900, color: completado ? AppColors.success : AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          if (_totalYaPagado > 0) _resumenLinea('Ya pagado anteriormente', CurrencyUtils.format(_totalYaPagado)),
          _resumenLinea('Productos nuevos', CurrencyUtils.format(_subtotalProductos)),
          if (_propinaPagadaEstimada > 0) _resumenLinea('Propina ya pagada', CurrencyUtils.format(_propinaPagadaEstimada)),
          _resumenLinea('Propina pendiente', CurrencyUtils.format(_propinaPendiente)),
          const Divider(height: 18),
          _resumenLinea('Nuevo saldo por cobrar', CurrencyUtils.format(_totalCuenta), destacado: true),
          _resumenLinea('Pagos nuevos aplicados', CurrencyUtils.format(_totalPagos)),
          if (_totalRecibido > 0) _resumenLinea('Efectivo recibido', CurrencyUtils.format(_totalRecibido)),
          if (_totalCambio > 0) _resumenLinea('Vueltas efectivo', CurrencyUtils.format(_totalCambio), destacado: true),
          const Divider(height: 18),
          _resumenLinea('Saldo pendiente', CurrencyUtils.format(_saldo), destacado: true, danger: _saldo > 0.009),
        ],
      ),
    );
  }

  Widget _resumenLinea(String label, String value, {bool destacado = false, bool danger = false}) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: danger ? AppColors.danger : AppColors.textSecondary, fontWeight: destacado ? FontWeight.w900 : FontWeight.w700))),
          Text(value, style: TextStyle(color: color, fontWeight: destacado ? FontWeight.w900 : FontWeight.w800, fontSize: destacado ? 16 : 14)),
        ],
      ),
    );
  }
}


class _MoverProductoCuentaResult {
  const _MoverProductoCuentaResult._({this.cuentaDestinoId, this.descripcionNuevaCuenta, required this.crearNuevaCuenta});

  const _MoverProductoCuentaResult.existente(int cuentaDestinoId)
      : this._(cuentaDestinoId: cuentaDestinoId, crearNuevaCuenta: false);

  const _MoverProductoCuentaResult.nueva({String? descripcion})
      : this._(descripcionNuevaCuenta: descripcion, crearNuevaCuenta: true);

  final int? cuentaDestinoId;
  final String? descripcionNuevaCuenta;
  final bool crearNuevaCuenta;
}

class _MoverProductoCuentaDialog extends StatefulWidget {
  const _MoverProductoCuentaDialog({
    required this.venta,
    required this.cuentaOrigen,
    required this.producto,
  });

  final MeseroVentaModel venta;
  final MeseroCuentaModel cuentaOrigen;
  final MeseroDetalleProductoModel producto;

  @override
  State<_MoverProductoCuentaDialog> createState() => _MoverProductoCuentaDialogState();
}

class _MoverProductoCuentaDialogState extends State<_MoverProductoCuentaDialog> {
  final TextEditingController _descripcionNuevaCuentaController = TextEditingController();
  int? _cuentaDestinoId;
  bool _crearNuevaCuenta = false;

  List<MeseroCuentaModel> get _cuentasDestino => widget.venta.cuentas
      .where((cuenta) => cuenta.cuentaId != null && cuenta.cuentaId != widget.cuentaOrigen.cuentaId)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final cuentasDestino = _cuentasDestino;
    if (cuentasDestino.isEmpty) {
      _crearNuevaCuenta = true;
    } else {
      _cuentaDestinoId = cuentasDestino.first.cuentaId;
    }
  }

  @override
  void dispose() {
    _descripcionNuevaCuentaController.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_crearNuevaCuenta) {
      Navigator.of(context).pop(_MoverProductoCuentaResult.nueva(
        descripcion: _descripcionNuevaCuentaController.text.trim(),
      ));
      return;
    }

    final destinoId = _cuentaDestinoId;
    if (destinoId == null) return;
    Navigator.of(context).pop(_MoverProductoCuentaResult.existente(destinoId));
  }

  @override
  Widget build(BuildContext context) {
    final cuentasDestino = _cuentasDestino;
    final producto = widget.producto;
    final nombreProducto = producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}';
    final nuevaCuentaNumero = widget.venta.cuentas.fold<int>(0, (max, cuenta) {
          final numero = cuenta.numero ?? 0;
          return numero > max ? numero : max;
        }) +
        1;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Pasar producto a otra cuenta'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombreProducto, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SmallInfoPill(icon: Icons.receipt_long_rounded, text: 'Cuenta origen ${widget.cuentaOrigen.numero ?? '-'}'),
                        _SmallInfoPill(icon: Icons.shopping_bag_rounded, text: 'Cant. ${_formatCantidadGeneral(producto.cantidad)}'),
                        _SmallInfoPill(icon: Icons.payments_rounded, text: CurrencyUtils.format(producto.subtotal)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona la cuenta destino. Solo se pueden mover productos que todavía no están pagados.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (cuentasDestino.isNotEmpty) ...[
                ...cuentasDestino.map((cuenta) {
                  final descripcion = (cuenta.descripcion ?? '').trim();
                  return RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: cuenta.cuentaId!,
                    groupValue: _crearNuevaCuenta ? null : _cuentaDestinoId,
                    onChanged: (value) => setState(() {
                      _crearNuevaCuenta = false;
                      _cuentaDestinoId = value;
                    }),
                    title: Text(_cuentaEtiquetaVisible(cuenta)),
                    subtitle: Text('Total ${CurrencyUtils.format(cuenta.total)} · Saldo ${CurrencyUtils.format(cuenta.saldoPendiente)}'),
                  );
                }),
                const Divider(height: 18),
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warning.withOpacity(0.30)),
                  ),
                  child: const Text(
                    'No hay otra cuenta disponible en esta mesa. Crea una cuenta nueva para poder pasar el producto.',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                  ),
                ),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                value: true,
                groupValue: _crearNuevaCuenta,
                onChanged: (_) => setState(() => _crearNuevaCuenta = true),
                title: Text('Crear cuenta $nuevaCuentaNumero y pasar el producto'),
                subtitle: const Text('La cuenta se crea en la misma mesa y luego se mueve el producto.'),
              ),
              if (_crearNuevaCuenta) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _descripcionNuevaCuentaController,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Descripción de la nueva cuenta',
                    hintText: 'Ejemplo: Juan, mesa 4 invitado, cuenta adicional...',
                    counterText: '',
                    prefixIcon: const Icon(Icons.groups_2_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _crearNuevaCuenta || _cuentaDestinoId != null ? _confirmar : null,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Pasar producto'),
        ),
      ],
    );
  }
}

class _CantidadProductoDialog extends StatefulWidget {
  const _CantidadProductoDialog({required this.producto});

  final MeseroProductoModel producto;

  @override
  State<_CantidadProductoDialog> createState() => _CantidadProductoDialogState();
}

class _CantidadProductoDialogState extends State<_CantidadProductoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cantidadController;

  @override
  void initState() {
    super.initState();
    _cantidadController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  double _parseCantidad(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  void _sumar(double value) {
    final actual = _parseCantidad(_cantidadController.text);
    final nuevoValor = (actual <= 0 ? 0 : actual) + value;
    _cantidadController.text = _formatCantidadGeneral(nuevoValor);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final producto = widget.producto;
    final cantidad = _parseCantidad(_cantidadController.text);
    final precio = producto.precioVenta ?? 0;
    final total = cantidad * precio;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Cantidad del producto'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductImageThumb(value: producto.foto, size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(producto.nombre ?? 'Producto ${producto.prodId ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        const SizedBox(height: 6),
                        Text(
                          producto.descripcion ?? 'Sin descripción',
                          style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Expanded(child: _datoCantidadDialog('Precio unitario', CurrencyUtils.format(precio))),
                    Expanded(child: _datoCantidadDialog('Total', CurrencyUtils.format(total), alignEnd: true)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Restar uno',
                    onPressed: cantidad <= 1 ? null : () => _sumar(-1),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _cantidadController,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        hintText: 'Ejemplo: 3',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final parsed = _parseCantidad(value ?? '');
                        if (parsed <= 0) return 'Ingresa una cantidad mayor a cero';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: 'Sumar uno',
                    onPressed: () => _sumar(1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona la cantidad completa para no tener que agregar el mismo producto uno por uno.',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_parseCantidad(_cantidadController.text));
          },
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('Agregar'),
        ),
      ],
    );
  }

  Widget _datoCantidadDialog(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _MesaFormData {
  const _MesaFormData({required this.mesaNumero, this.descripcion, this.foto});
  final int mesaNumero;
  final String? descripcion;
  final String? foto;
}

class _MesaEditResult {
  const _MesaEditResult.update({required this.data, this.estado}) : eliminar = false;
  const _MesaEditResult.delete()
      : eliminar = true,
        data = null,
        estado = null;

  final bool eliminar;
  final _MesaFormData? data;
  final String? estado;
}

class _CrearMesaDialog extends StatefulWidget {
  const _CrearMesaDialog();

  @override
  State<_CrearMesaDialog> createState() => _CrearMesaDialogState();
}

class _CrearMesaDialogState extends State<_CrearMesaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mesaNumero = TextEditingController();
  final _descripcion = TextEditingController();
  final _foto = TextEditingController();

  @override
  void dispose() {
    _mesaNumero.dispose();
    _descripcion.dispose();
    _foto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = mediaWidth < 560 ? mediaWidth - 48 : 460.0;

    return AlertDialog(
      title: const Text('Agregar mesa'),
      content: SizedBox(
        width: dialogWidth > 280 ? dialogWidth : 280.0,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _mesaNumero,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de mesa',
                    hintText: 'Ejemplo: 12',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) return 'Ingresa un número de mesa válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcion,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción o recordatorio',
                    hintText: 'Ejemplo: mesa de cumpleaños, pareja de la ventana...',
                  ),
                  maxLength: 300,
                ),
                const SizedBox(height: 12),
                _LocalImagePickerField(controller: _foto, label: 'Foto de la mesa'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_MesaFormData(
              mesaNumero: int.parse(_mesaNumero.text.trim()),
              descripcion: _descripcion.text.trim(),
              foto: _foto.text.trim(),
            ));
          },
          child: const Text('Crear mesa'),
        ),
      ],
    );
  }
}

class _EditarMesaDialog extends StatefulWidget {
  const _EditarMesaDialog({required this.mesa, required this.isCajero});

  final MeseroMesaResumenModel mesa;
  final bool isCajero;

  @override
  State<_EditarMesaDialog> createState() => _EditarMesaDialogState();
}

class _EditarMesaDialogState extends State<_EditarMesaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mesaNumero;
  late final TextEditingController _descripcion;
  late final TextEditingController _foto;
  late String _estado;

  @override
  void initState() {
    super.initState();
    _mesaNumero = TextEditingController(text: widget.mesa.mesaNumero?.toString() ?? '');
    _descripcion = TextEditingController(text: widget.mesa.mesaDescripcion ?? '');
    _foto = TextEditingController(text: widget.mesa.mesaFoto ?? '');
    _estado = (widget.mesa.estadoMesa ?? 'DISPONIBLE').toUpperCase();
  }

  @override
  void dispose() {
    _mesaNumero.dispose();
    _descripcion.dispose();
    _foto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = mediaWidth < 560 ? mediaWidth - 48 : 460.0;

    return AlertDialog(
      title: Text('Editar mesa ${widget.mesa.mesaNumero ?? '-'}'),
      content: SizedBox(
        width: dialogWidth > 280 ? dialogWidth : 280.0,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _mesaNumero,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Número de mesa'),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) return 'Ingresa un número de mesa válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcion,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Descripción o recordatorio',
                    hintText: 'Agrega una nota que ayude al equipo operativo',
                  ),
                ),
                const SizedBox(height: 12),
                _LocalImagePickerField(controller: _foto, label: 'Foto de la mesa'),
                if (widget.isCajero) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _estado,
                    decoration: const InputDecoration(labelText: 'Estado de la mesa'),
                    items: const [
                      DropdownMenuItem(value: 'DISPONIBLE', child: Text('Disponible')),
                      DropdownMenuItem(value: 'OCUPADA', child: Text('Ocupada')),
                      DropdownMenuItem(value: 'INACTIVA', child: Text('Inactiva')),
                    ],
                    onChanged: (value) => setState(() => _estado = value ?? 'DISPONIBLE'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.isCajero)
          TextButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar o inactivar mesa'),
                  content: const Text('Si la mesa no tiene datos relacionados se eliminará. Si tiene histórico se marcará como inactiva.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continuar')),
                  ],
                ),
              );
              if (confirm == true && context.mounted) Navigator.of(context).pop(const _MesaEditResult.delete());
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_MesaEditResult.update(
              data: _MesaFormData(
                mesaNumero: int.parse(_mesaNumero.text.trim()),
                descripcion: _descripcion.text.trim(),
                foto: _foto.text.trim(),
              ),
              estado: widget.isCajero ? _estado : null,
            ));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}


class _LocalImagePickerField extends StatefulWidget {
  const _LocalImagePickerField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  State<_LocalImagePickerField> createState() => _LocalImagePickerFieldState();
}

class _LocalImagePickerFieldState extends State<_LocalImagePickerField> {
  Future<void> _pick() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;

    if (bytes.length > 3 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La imagen es demasiado pesada. Usa una foto menor a 3 MB.')),
      );
      return;
    }

    final ext = (file?.extension ?? 'png').toLowerCase();
    final mime = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/png';
    widget.controller.text = 'data:$mime;base64,${base64Encode(bytes)}';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_rounded, color: AppColors.secondaryDark),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w900))),
              OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.upload_file_rounded), label: const Text('Cargar')),
            ],
          ),
          const SizedBox(height: 10),
          if (value.isEmpty)
            const Text('Sin foto cargada', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final previewWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 420.0;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _BarlyticsImage(value: value, width: previewWidth, height: 116),
                );
              },
            ),
          if (value.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                widget.controller.clear();
                setState(() {});
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Quitar foto'),
            ),
        ],
      ),
    );
  }
}

class _BarlyticsImage extends StatelessWidget {
  const _BarlyticsImage({required this.value, required this.width, required this.height, this.radius = 0});

  final String value;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageValue = value.trim();
    final fallback = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(radius)),
      child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary),
    );
    if (imageValue.isEmpty) return fallback;
    if (imageValue.startsWith('data:image')) {
      final index = imageValue.indexOf(',');
      if (index > -1) {
        try {
          return Image.memory(base64Decode(imageValue.substring(index + 1)), width: width, height: height, fit: BoxFit.cover);
        } catch (_) {
          return fallback;
        }
      }
    }
    return Image.network(imageValue, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
  }
}

class _ProductImageThumb extends StatelessWidget {
  const _ProductImageThumb({required this.value, this.size = 44});

  final String? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = (value ?? '').trim();
    if (image.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: const Icon(Icons.local_bar_rounded, color: AppColors.textSecondary, size: 20),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(14), child: _BarlyticsImage(value: image, width: size, height: size));
  }
}

class _AjustarCuentasResult {
  const _AjustarCuentasResult({required this.numeroCuentas, required this.descripcionesCuentas});

  final int numeroCuentas;
  final Map<int, String> descripcionesCuentas;
}

class _AjustarCuentasDialog extends StatefulWidget {
  const _AjustarCuentasDialog({required this.cuentas});

  final List<MeseroCuentaModel> cuentas;

  @override
  State<_AjustarCuentasDialog> createState() => _AjustarCuentasDialogState();
}

class _AjustarCuentasDialogState extends State<_AjustarCuentasDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroCuentasController;
  final Map<int, TextEditingController> _descripcionControllers = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final actual = widget.cuentas.isEmpty ? 1 : widget.cuentas.length;
    _numeroCuentasController = TextEditingController(text: actual.toString());
    _syncDescriptionControllers(actual);
    for (final cuenta in widget.cuentas) {
      final numero = cuenta.numero;
      if (numero != null) {
        _descripcionControllers[numero]?.text = cuenta.descripcion ?? '';
      }
    }
  }

  @override
  void dispose() {
    _numeroCuentasController.dispose();
    for (final controller in _descripcionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _numeroCuentas => int.tryParse(_numeroCuentasController.text.trim()) ?? 1;

  void _syncDescriptionControllers(int total) {
    final safeTotal = total < 1 ? 1 : total;
    final expected = List<int>.generate(safeTotal, (index) => index + 1).toSet();

    final toRemove = _descripcionControllers.keys.where((key) => !expected.contains(key)).toList();
    for (final key in toRemove) {
      _descripcionControllers.remove(key)?.dispose();
    }

    for (final key in expected) {
      _descripcionControllers.putIfAbsent(key, () => TextEditingController());
    }
  }

  Map<int, String> _descripciones() {
    return _descripcionControllers.map((key, controller) => MapEntry(key, controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Modificar cuentas'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Indica en cuántas cuentas se dividirá la venta y agrega una descripción opcional para identificarlas.'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _numeroCuentasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número de cuentas',
                      hintText: 'Ejemplo: 6',
                      helperText: 'No hay límite fijo desde la aplicación.',
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null && parsed > 0) {
                        setState(() => _syncDescriptionControllers(parsed));
                      }
                    },
                    validator: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      if (parsed == null) return 'Ingresa un número de cuentas válido';
                      if (parsed < 1) return 'Debe existir al menos una cuenta';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Text('Descripción de cuentas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ...List<int>.generate(_numeroCuentas < 1 ? 1 : _numeroCuentas, (index) => index + 1).map(
                    (numero) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        controller: _descripcionControllers[numero],
                        maxLength: 300,
                        decoration: InputDecoration(
                          labelText: 'Cuenta $numero',
                          hintText: 'Ejemplo: Juan, pareja ventana, grupo cumpleaños...',
                          counterText: '',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              Navigator.of(context).pop(_AjustarCuentasResult(
                numeroCuentas: int.parse(_numeroCuentasController.text.trim()),
                descripcionesCuentas: _descripciones(),
              ));
            },
            child: const Text('Actualizar'),
          ),
        ],
      );
}

class _AbrirVentaDecision {
  const _AbrirVentaDecision({
    required this.dividir,
    required this.numeroCuentas,
    this.mesaDescripcion,
    this.descripcionesCuentas = const <int, String>{},
  });

  final bool dividir;
  final int numeroCuentas;
  final String? mesaDescripcion;
  final Map<int, String> descripcionesCuentas;
}

class _AbrirVentaDialog extends StatefulWidget {
  const _AbrirVentaDialog({required this.mesa});
  final MeseroMesaResumenModel mesa;

  @override
  State<_AbrirVentaDialog> createState() => _AbrirVentaDialogState();
}

class _AbrirVentaDialogState extends State<_AbrirVentaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numeroCuentasController = TextEditingController(text: '2');
  late final TextEditingController _mesaDescripcionController;
  final Map<int, TextEditingController> _descripcionControllers = <int, TextEditingController>{};
  bool _dividir = false;

  @override
  void initState() {
    super.initState();
    _mesaDescripcionController = TextEditingController(text: widget.mesa.mesaDescripcion ?? '');
    _syncDescriptionControllers(1);
  }

  @override
  void dispose() {
    _numeroCuentasController.dispose();
    _mesaDescripcionController.dispose();
    for (final controller in _descripcionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _numeroCuentas => int.tryParse(_numeroCuentasController.text.trim()) ?? 2;

  void _syncDescriptionControllers(int total) {
    final safeTotal = total < 1 ? 1 : total;
    final expected = List<int>.generate(safeTotal, (index) => index + 1).toSet();

    final toRemove = _descripcionControllers.keys.where((key) => !expected.contains(key)).toList();
    for (final key in toRemove) {
      _descripcionControllers.remove(key)?.dispose();
    }

    for (final key in expected) {
      _descripcionControllers.putIfAbsent(key, () => TextEditingController());
    }
  }

  Map<int, String> _descripciones() {
    return _descripcionControllers.map((key, controller) => MapEntry(key, controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final totalCuentas = _dividir ? (_numeroCuentas < 1 ? 1 : _numeroCuentas) : 1;
    _syncDescriptionControllers(totalCuentas);

    return AlertDialog(
      title: Text('Mesa ${widget.mesa.mesaNumero ?? '-'}'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.mesa.ventaId == null ? 'Se abrirá una nueva venta para esta mesa.' : 'La mesa ya tiene una venta abierta.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mesaDescripcionController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Descripción de la mesa / venta',
                    hintText: 'Ejemplo: cumpleaños, grupo de la ventana, mesa de Juan...',
                    helperText: 'Esta descripción queda registrada en la mesa al abrir la venta.',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dividir en cuentas'),
                  subtitle: const Text('Indica cuántas cuentas se van a registrar para esta mesa.'),
                  value: _dividir,
                  onChanged: (value) => setState(() {
                    _dividir = value;
                    _syncDescriptionControllers(value ? _numeroCuentas : 1);
                  }),
                ),
                if (_dividir)
                  TextFormField(
                    controller: _numeroCuentasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número de cuentas',
                      hintText: 'Ejemplo: 3',
                      helperText: 'Puedes registrar las cuentas que necesites.',
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null && parsed > 0) {
                        setState(() => _syncDescriptionControllers(parsed));
                      }
                    },
                    validator: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      if (parsed == null) return 'Ingresa un número de cuentas válido';
                      if (parsed < 1) return 'Debe existir al menos una cuenta';
                      return null;
                    },
                  ),
                const SizedBox(height: 18),
                Text('Descripción de cuentas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                ...List<int>.generate(totalCuentas, (index) => index + 1).map(
                  (numero) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextFormField(
                      controller: _descripcionControllers[numero],
                      maxLength: 300,
                      decoration: InputDecoration(
                        labelText: 'Cuenta $numero',
                        hintText: numero == 1 ? 'Ejemplo: Cuenta principal' : 'Ejemplo: persona o grupo que pagará esta cuenta',
                        counterText: '',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_dividir && !(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_AbrirVentaDecision(
              dividir: _dividir,
              numeroCuentas: _dividir ? _numeroCuentas : 1,
              mesaDescripcion: _mesaDescripcionController.text.trim(),
              descripcionesCuentas: _descripciones(),
            ));
          },
          child: Text(widget.mesa.ventaId == null ? 'Abrir venta' : 'Continuar'),
        ),
      ],
    );
  }
}
