import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/printing/network_ticket_dialog.dart';
import '../../../../core/branch/branch_scope_provider.dart';

import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../navigation/presentation/providers/active_role_provider.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';
import '../../../pagos/presentation/pages/pagos_list_page.dart';
import '../../data/datasources/mesero_remote_datasource.dart';
import '../../data/models/mesero_models.dart';
import '../providers/mesero_tab_provider.dart';


bool _ventaEsDirecta(MeseroVentaModel venta) =>
    (venta.tipoVenta ?? '').trim().toUpperCase() == 'DIRECTA' || venta.mesaId == null;

String _origenVentaVisible(MeseroVentaModel venta) =>
    _ventaEsDirecta(venta) ? 'Venta directa #${venta.ventaId ?? '-'}' : 'Mesa ${venta.mesaNumero ?? venta.mesaId ?? '-'}';

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

String _catalogoTipoProducto(MeseroProductoModel producto) {
  final nombre = (producto.tipoProductoNombre ?? '').trim();
  if (nombre.isNotEmpty) return nombre;
  final id = producto.tipoProductoId;
  return id == null ? 'Sin tipo' : 'Tipo $id';
}

String _catalogoMarcaProducto(MeseroProductoModel producto) {
  final nombre = (producto.marcaNombre ?? '').trim();
  if (nombre.isNotEmpty) return nombre;
  final id = producto.marcaId;
  return id == null ? 'Sin marca' : 'Marca $id';
}

String _catalogoDescripcionProducto(MeseroProductoModel producto) {
  var descripcion = (producto.descripcion ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (descripcion.isEmpty) return '';

  const marcadoresTecnicos = <String>[
    'producto migrado desde excel:',
    'imagen normalizada',
    'desde zip:',
  ];
  for (final marcador in marcadoresTecnicos) {
    final index = descripcion.toLowerCase().indexOf(marcador);
    if (index >= 0) descripcion = descripcion.substring(0, index).trim();
  }

  descripcion = descripcion.replaceAll(RegExp(r'[\s.,;:]+$'), '').trim();
  final nombre = (producto.nombre ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (descripcion.toLowerCase() == nombre.toLowerCase()) return '';
  return descripcion;
}

List<String> _personalizacionPedidoResumen(MeseroDetalleProductoModel producto) {
  final raw = (producto.personalizacion ?? '').trim();
  if (raw.isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const <String>[];
    final data = Map<String, dynamic>.from(decoded);
    final lines = <String>[];

    for (final item in (data['quitados'] as List? ?? const <dynamic>[])) {
      if (item is! Map) continue;
      final nombre = item['nombre']?.toString().trim();
      if (nombre != null && nombre.isNotEmpty) lines.add('Sin $nombre');
    }
    for (final item in (data['adiciones'] as List? ?? const <dynamic>[])) {
      if (item is! Map) continue;
      final nombre = item['nombre']?.toString().trim();
      if (nombre != null && nombre.isNotEmpty) lines.add('+ $nombre');
    }
    final observacion = data['observacion']?.toString().trim();
    if (observacion != null && observacion.isNotEmpty) {
      lines.add(observacion);
    }
    return lines;
  } catch (_) {
    return const <String>[];
  }
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

bool _visibleEnCatalogoMesa(
  MeseroProductoModel producto,
  Set<int> idsAdiciones,
) {
  final control = (producto.tipoControl ?? '').trim().toUpperCase();
  return control != 'INSUMO' ||
      (producto.prodId != null && idsAdiciones.contains(producto.prodId));
}

Set<int> _idsAdiciones(List<MeseroProductoModel> productos) =>
    productos.expand((producto) => producto.adiciones)
        .map((adicion) => adicion.prodId)
        .whereType<int>()
        .toSet();

class _CurrencyThousandsInputFormatter extends TextInputFormatter {
  const _CurrencyThousandsInputFormatter({
    required this.maxIntegerDigits,
    this.fractionDigits = 0,
  });

  final int maxIntegerDigits;
  final int fractionDigits;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.trim();
    if (raw.isEmpty) return newValue;

    final commaIndex = raw.indexOf(',');
    final dotIndex = raw.indexOf('.');
    final separatorIndex = commaIndex >= 0
        ? commaIndex
        : (fractionDigits > 0 && dotIndex >= 0 ? dotIndex : -1);
    final integerRaw = separatorIndex >= 0 ? raw.substring(0, separatorIndex) : raw;
    final integerDigits = integerRaw.replaceAll(RegExp(r'\D'), '');
    if (integerDigits.length > maxIntegerDigits) return oldValue;

    final formatted = _formatRawCurrencyText(raw);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatRawCurrencyText(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';

    // El punto se usa como separador de miles en la UI; la coma es el
    // separador decimal. Para campos enteros se eliminan ambos separadores.
    final commaIndex = fractionDigits > 0 ? raw.indexOf(',') : -1;
    final hasDecimal = commaIndex >= 0;
    final integerRaw = hasDecimal ? raw.substring(0, commaIndex) : raw;
    final decimalRaw = hasDecimal ? raw.substring(commaIndex + 1) : '';

    final integerDigits = integerRaw.replaceAll(RegExp(r'\D'), '');
    final decimalDigits = decimalRaw.replaceAll(RegExp(r'\D'), '');
    final formattedInteger = _formatIntegerWithThousands(integerDigits);

    if (!hasDecimal || fractionDigits == 0) return formattedInteger;
    if (formattedInteger.isEmpty && decimalDigits.isEmpty) return '';

    final decimals = decimalDigits.length > fractionDigits
        ? decimalDigits.substring(0, fractionDigits)
        : decimalDigits;
    return '$formattedInteger,$decimals';
  }
}

// Cierre de caja: NUMERIC(20,2) => 18 enteros + 2 decimales.
const List<TextInputFormatter> _currencyInputFormatters = [
  _CurrencyThousandsInputFormatter(maxIntegerDigits: 18, fractionDigits: 2),
];

// Pagos de cuenta: NUMERIC(20,0).
const List<TextInputFormatter> _wholeCurrencyInputFormatters = [
  _CurrencyThousandsInputFormatter(maxIntegerDigits: 20),
];

// Propina de venta: NUMERIC(10,0).
const List<TextInputFormatter> _tipCurrencyInputFormatters = [
  _CurrencyThousandsInputFormatter(maxIntegerDigits: 10),
];

class MeseroPage extends ConsumerStatefulWidget {
  const MeseroPage({super.key, this.initialMode});

  /// Pestaña de entrada para cada ruta operativa, incluida /mesero (Mesas).
  /// La selección interna sigue en Riverpod para evitar recargas innecesarias,
  /// pero volver a la ruta base no debe conservar Cierre de caja o Historial.
  final MeseroPageMode? initialMode;

  @override
  ConsumerState<MeseroPage> createState() => _MeseroPageState();
}

class _MeseroPageState extends ConsumerState<MeseroPage> {
  AppPalette get palette => ref.watch(selectedAppPaletteProvider);
  late MeseroRemoteDataSource _dataSource;
  late Future<void> _future;
  List<MeseroMesaResumenModel> _mesas = const [];
  List<MeseroProductoModel> _productos = const [];
  List<MeseroMedioPagoModel> _mediosPago = const [];
  List<MeseroVentaModel> _ventasDirectasAbiertas = const [];
  MeseroVentaModel? _ventaActiva;
  bool _mostrandoDetalleVenta = false;
  bool _mostrandoPestanaAgregarProductos = false;
  bool _irACuentaDespuesAgregarProducto = false;
  int? _cuentaSeleccionadaId;
  bool _processing = false;
  bool _cargaInicialCompletada = false;
  final Set<int> _detallesCantidadEnProceso = <int>{};
  final TextEditingController _productoFiltroController = TextEditingController();
  final TextEditingController _mesaBuscarController = TextEditingController();
  String _productoFiltro = '';
  String _mesaBuscar = '';
  String _mesaEstadoFiltro = 'todas';
  String? _tipoProductoFiltro;
  String? _marcaProductoFiltro;
  bool _productosVistaCuadricula = true;
  String _productosOrdenCatalogo = 'nombre';
  Future<List<MeseroVentaModel>>? _historialVentasFuture;
  List<MeseroVentaModel> _historialVentas = const [];
  DateTime? _historialDiaFiltro;
  final TextEditingController _historialBuscarController = TextEditingController();
  String _historialBuscar = '';
  String _historialEstado = 'todos';
  String _historialOrden = 'recientes';
  Future<CierreCajaResumenModel>? _cierreCajaFuture;
  DateTime? _cierreCajaFechaFiltro;
  final Map<String, double> _baseInicialCierrePorFecha = <String, double>{};

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _historialDiaFiltro = DateTime(today.year, today.month, today.day);
    _dataSource = MeseroRemoteDataSource(ref.read(apiClientProvider));
    _scheduleInitialMode(widget.initialMode);
    _future = _load();
  }

  void _scheduleInitialMode(MeseroPageMode? initialMode) {
    if (initialMode == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(meseroSelectedModeProvider.notifier);
      if (controller.state != initialMode) {
        controller.state = initialMode;
      }
    });
  }

  @override
  void dispose() {
    _productoFiltroController.dispose();
    _mesaBuscarController.dispose();
    _historialBuscarController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MeseroPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initialMode = widget.initialMode;
    if (oldWidget.initialMode != initialMode) {
      _scheduleInitialMode(initialMode);
    }
  }

  Future<void> _load() async {
    // Mesas es el dato crítico para pintar la operación. Catálogo, medios de
    // pago y ventas directas se cargan después sin bloquear la primera vista.
    _mesas = await _dataSource.listarMesas();
    _cargaInicialCompletada = true;
    unawaited(_loadSecondaryOperationData());
  }

  Future<void> _loadSecondaryOperationData() async {
    final productosFuture = _dataSource.listarProductos();
    final mediosFuture = _dataSource.listarMediosPago();
    final directasFuture = _dataSource.listarVentasDirectasAbiertas();

    try {
      final productos = await productosFuture;
      if (!mounted) return;
      setState(() => _productos = productos);
    } catch (_) {
      // La operación de mesas debe seguir disponible aunque falle el catálogo.
    }

    try {
      final medios = await mediosFuture;
      if (!mounted) return;
      setState(() => _mediosPago = medios);
    } catch (_) {
      // Los medios se reintentarán cuando una acción los vuelva a solicitar.
    }

    try {
      final directas = await directasFuture;
      if (!mounted) return;
      setState(() => _ventasDirectasAbiertas = directas);
    } catch (_) {
      // Una lista secundaria no debe bloquear la vista principal.
    }
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _reloadResumenOperativo() async {
    final operacionFuture = _load();
    final historialFuture = _cargarHistorialVentas();
    setState(() {
      _future = operacionFuture;
      _historialVentasFuture = historialFuture;
    });
    await Future.wait([operacionFuture, historialFuture]);
  }

  void _abrirProductoDesdeResumen(String nombreProducto) {
    _productoFiltroController.text = nombreProducto;
    setState(() {
      _productoFiltro = nombreProducto;
      _tipoProductoFiltro = null;
      _marcaProductoFiltro = null;
    });
    ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.productos;
  }

  Future<List<MeseroVentaModel>> _cargarHistorialVentas() async {
    final filtro = _historialDiaFiltro;
    final fecha = filtro == null ? null : _fechaIso(filtro);
    final ventas = await _dataSource.historialVentas(
      desde: fecha,
      hasta: fecha,
      pagina: 0,
      tamano: filtro == null ? 200 : 500,
    );
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

  String _fechaIso(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  DateTime get _fechaCierreActual {
    final today = DateTime.now();
    return _cierreCajaFechaFiltro ?? DateTime(today.year, today.month, today.day);
  }

  Future<CierreCajaResumenModel> _cargarCierreCaja() {
    return _dataSource.consultarCierreCaja(fecha: _fechaIso(_fechaCierreActual));
  }

  Future<void> _reloadCierreCaja() async {
    final future = _cargarCierreCaja();
    if (mounted) {
      setState(() {
        _cierreCajaFuture = future;
      });
    }
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


  List<MeseroMesaResumenModel> get _mesasFiltradas {
    final query = _mesaBuscar.trim().toLowerCase();
    final resultado = _mesas.where((mesa) {
      final estado = (mesa.estadoMesa ?? '').trim().toUpperCase();
      final inactiva = estado == 'INACTIVA';
      final ocupada = mesa.ventaId != null && !inactiva;
      final libre = !ocupada && !inactiva;

      final coincideEstado = switch (_mesaEstadoFiltro) {
        'ocupadas' => ocupada,
        'libres' => libre,
        _ => true,
      };
      if (!coincideEstado) return false;

      if (query.isEmpty) return true;
      final numero = (mesa.mesaNumero?.toString() ?? '').toLowerCase();
      final descripcion = (mesa.mesaDescripcion ?? '').toLowerCase();
      final estadoVisible = inactiva ? 'inactiva' : ocupada ? 'ocupada' : 'libre';
      return numero.contains(query) ||
          'mesa $numero'.contains(query) ||
          descripcion.contains(query) ||
          estadoVisible.contains(query);
    }).toList(growable: false);

    resultado.sort((a, b) => (a.mesaNumero ?? 0).compareTo(b.mesaNumero ?? 0));
    return resultado;
  }

  List<MeseroProductoModel> get _productosFiltrados {
    final idsAdiciones = _idsAdiciones(_productos);
    final query = _productoFiltro.trim().toLowerCase();
    final tipo = (_tipoProductoFiltro ?? '').trim().toLowerCase();
    final marca = (_marcaProductoFiltro ?? '').trim().toLowerCase();

    return _productos.where((producto) {
      if (!_visibleEnCatalogoMesa(producto, idsAdiciones)) return false;
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


  List<MeseroProductoModel> get _productosCatalogoOrdenados {
    final resultado = List<MeseroProductoModel>.of(_productosFiltrados);

    int compararNombre(MeseroProductoModel a, MeseroProductoModel b) {
      final nombreA = (a.nombre ?? '').trim().toLowerCase();
      final nombreB = (b.nombre ?? '').trim().toLowerCase();
      return nombreA.compareTo(nombreB);
    }

    int compararPrecio(MeseroProductoModel a, MeseroProductoModel b, {required bool descendente}) {
      final precioA = a.precioVenta;
      final precioB = b.precioVenta;
      if (precioA == null && precioB == null) return compararNombre(a, b);
      if (precioA == null) return 1;
      if (precioB == null) return -1;
      final comparacion = precioA.compareTo(precioB);
      if (comparacion == 0) return compararNombre(a, b);
      return descendente ? -comparacion : comparacion;
    }

    switch (_productosOrdenCatalogo) {
      case 'precioMenor':
        resultado.sort((a, b) => compararPrecio(a, b, descendente: false));
        break;
      case 'precioMayor':
        resultado.sort((a, b) => compararPrecio(a, b, descendente: true));
        break;
      case 'marca':
        resultado.sort((a, b) {
          final comparacion = _catalogoMarcaProducto(a).toLowerCase().compareTo(_catalogoMarcaProducto(b).toLowerCase());
          return comparacion == 0 ? compararNombre(a, b) : comparacion;
        });
        break;
      default:
        resultado.sort(compararNombre);
        break;
    }
    return resultado;
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

  MeseroVentaModel _preservarOrdenProductosVenta(
    MeseroVentaModel? ventaAnterior,
    MeseroVentaModel ventaActualizada,
  ) {
    if (ventaAnterior == null) return ventaActualizada;

    final cuentasActualizadas = <int, MeseroCuentaModel>{};
    final cuentasSinId = <MeseroCuentaModel>[];
    for (final cuenta in ventaActualizada.cuentas) {
      final cuentaId = cuenta.cuentaId;
      if (cuentaId == null) {
        cuentasSinId.add(cuenta);
      } else {
        cuentasActualizadas[cuentaId] = cuenta;
      }
    }

    final cuentasOrdenadas = <MeseroCuentaModel>[];
    for (final cuentaAnterior in ventaAnterior.cuentas) {
      final cuentaId = cuentaAnterior.cuentaId;
      if (cuentaId == null) continue;
      final cuentaActualizada = cuentasActualizadas.remove(cuentaId);
      if (cuentaActualizada == null) continue;

      final productosPorDetalle = <int, MeseroDetalleProductoModel>{};
      final productosSinDetalle = <MeseroDetalleProductoModel>[];
      for (final producto in cuentaActualizada.productos) {
        final detalleId = producto.detalleId;
        if (detalleId == null) {
          productosSinDetalle.add(producto);
        } else {
          productosPorDetalle[detalleId] = producto;
        }
      }

      final productosOrdenados = <MeseroDetalleProductoModel>[];
      for (final productoAnterior in cuentaAnterior.productos) {
        final detalleId = productoAnterior.detalleId;
        if (detalleId == null) continue;
        final productoActualizado = productosPorDetalle.remove(detalleId);
        if (productoActualizado != null) {
          productosOrdenados.add(productoActualizado);
        }
      }

      // Los productos nuevos se agregan al final, en el mismo orden entregado
      // por el backend. Los eliminados simplemente dejan de aparecer.
      for (final producto in cuentaActualizada.productos) {
        final detalleId = producto.detalleId;
        if (detalleId == null) {
          if (productosSinDetalle.contains(producto)) {
            productosOrdenados.add(producto);
            productosSinDetalle.remove(producto);
          }
        } else if (productosPorDetalle.remove(detalleId) != null) {
          productosOrdenados.add(producto);
        }
      }

      cuentasOrdenadas.add(
        MeseroCuentaModel(
          cuentaId: cuentaActualizada.cuentaId,
          numero: cuentaActualizada.numero,
          descripcion: cuentaActualizada.descripcion,
          total: cuentaActualizada.total,
          propina: cuentaActualizada.propina,
          subtotalProductos: cuentaActualizada.subtotalProductos,
          totalPagado: cuentaActualizada.totalPagado,
          saldoPendiente: cuentaActualizada.saldoPendiente,
          pagada: cuentaActualizada.pagada,
          estado: cuentaActualizada.estado,
          productos: productosOrdenados,
          pagos: cuentaActualizada.pagos,
        ),
      );
    }

    // Conserva al final cualquier cuenta nueva que no existía antes.
    for (final cuenta in ventaActualizada.cuentas) {
      final cuentaId = cuenta.cuentaId;
      if (cuentaId == null) continue;
      final pendiente = cuentasActualizadas.remove(cuentaId);
      if (pendiente != null) cuentasOrdenadas.add(pendiente);
    }
    cuentasOrdenadas.addAll(cuentasSinId);

    return MeseroVentaModel(
      ventaId: ventaActualizada.ventaId,
      mesaId: ventaActualizada.mesaId,
      mesaNumero: ventaActualizada.mesaNumero,
      sucursalId: ventaActualizada.sucursalId,
      tipoVenta: ventaActualizada.tipoVenta,
      mesaDescripcion: ventaActualizada.mesaDescripcion,
      mesaFoto: ventaActualizada.mesaFoto,
      fecha: ventaActualizada.fecha,
      estado: ventaActualizada.estado,
      total: ventaActualizada.total,
      propina: ventaActualizada.propina,
      totalPagado: ventaActualizada.totalPagado,
      saldoPendiente: ventaActualizada.saldoPendiente,
      pagada: ventaActualizada.pagada,
      cuentas: cuentasOrdenadas,
    );
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

  List<MeseroProductoModel> _productosOrdenadosPorPedido(List<MeseroProductoModel> productos, MeseroCuentaModel _) {
    // Conserva el orden recibido dentro del detalle de la cuenta. Cambiar una
    // cantidad no debe mover el producto ni hacer perder la posición de trabajo.
    return List<MeseroProductoModel>.from(productos);
  }

  bool _ventaCorrespondeAlDia(MeseroVentaModel venta, DateTime dia) {
    final raw = (venta.fecha ?? '').trim();
    if (raw.isEmpty) return venta.ventaId == _ventaActiva?.ventaId;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return false;
    final local = parsed.toLocal();
    return local.year == dia.year && local.month == dia.month && local.day == dia.day;
  }

  void _acumularProductosVenta(
    Map<int, double> acumulado,
    MeseroVentaModel venta,
  ) {
    for (final cuenta in venta.cuentas) {
      for (final detalle in cuenta.productos) {
        final productoId = detalle.productoId;
        final cantidad = (detalle.cantidad ?? 0).toDouble();
        if (productoId == null || cantidad <= 0) continue;
        acumulado[productoId] = (acumulado[productoId] ?? 0) + cantidad;
      }
    }
  }

  Future<Map<int, double>> _cargarProductosMasPedidosHoy() async {
    final hoy = DateTime.now();

    try {
      return await _dataSource.productosMasPedidosHoy(fecha: _fechaIso(hoy));
    } catch (_) {
      // Fallback operativo: si el agregado no está disponible, se conserva el
      // catálogo funcional y se contabiliza al menos la venta activa.
      final acumulado = <int, double>{};
      final ventaActiva = _ventaActiva;
      if (ventaActiva != null && _ventaCorrespondeAlDia(ventaActiva, hoy)) {
        _acumularProductosVenta(acumulado, ventaActiva);
      }
      return acumulado;
    }
  }

  List<MeseroProductoModel> _ordenarProductosPorPedidosHoy(
    List<MeseroProductoModel> productos,
    Map<int, double> cantidadesHoy,
  ) {
    final ordenOriginal = <int, int>{};
    for (var index = 0; index < productos.length; index++) {
      final productoId = productos[index].prodId;
      if (productoId != null) ordenOriginal[productoId] = index;
    }

    final resultado = List<MeseroProductoModel>.from(productos);
    resultado.sort((a, b) {
      final cantidadA = a.prodId == null ? 0.0 : (cantidadesHoy[a.prodId] ?? 0);
      final cantidadB = b.prodId == null ? 0.0 : (cantidadesHoy[b.prodId] ?? 0);
      final porCantidad = cantidadB.compareTo(cantidadA);
      if (porCantidad != 0) return porCantidad;

      final posicionA = a.prodId == null ? productos.length : (ordenOriginal[a.prodId] ?? productos.length);
      final posicionB = b.prodId == null ? productos.length : (ordenOriginal[b.prodId] ?? productos.length);
      return posicionA.compareTo(posicionB);
    });
    return resultado;
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
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
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
            ).compactFilter(),
            onChanged: (value) => setState(() => _productoFiltro = value),
          );

          final tipoField = DropdownButtonFormField<String>(
            value: tipos.contains(_tipoProductoFiltro) ? _tipoProductoFiltro : null,
            decoration: const InputDecoration(
              labelText: 'Tipo de producto',
              prefixIcon: Icon(Icons.category_rounded),
            ).compactFilter(),
            items: tipos.map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo))).toList(growable: false),
            onChanged: tipos.isEmpty ? null : (value) => setState(() => _tipoProductoFiltro = value),
          );

          final marcaField = DropdownButtonFormField<String>(
            value: marcas.contains(_marcaProductoFiltro) ? _marcaProductoFiltro : null,
            decoration: const InputDecoration(
              labelText: 'Marca',
              prefixIcon: Icon(Icons.local_offer_rounded),
            ).compactFilter(),
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
    final rawRoles = ref.watch(activeRolesProvider);
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
    final rawRoles = ref.watch(activeRolesProvider);
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

  Set<String> _authorizedMenuKeys() {
    return ref.watch(userMenuProvider).maybeWhen(
          data: (items) => items.map((item) => item.keyName).toSet(),
          orElse: () => const <String>{},
        );
  }

  bool _canManageTables() {
    return _isCajeroOperativo() ||
        _authorizedMenuKeys().contains('administrar_mesas');
  }

  bool _esVentaDirecta(MeseroVentaModel venta) =>
      (venta.tipoVenta ?? '').trim().toUpperCase() == 'DIRECTA' || venta.mesaId == null;

  bool _mesaInactiva(MeseroMesaResumenModel mesa) => (mesa.estadoMesa ?? '').toUpperCase() == 'INACTIVA';

  MeseroCuentaModel? _resolverCuentaSeleccionada(MeseroVentaModel venta) {
    for (final cuenta in venta.cuentas) {
      if (cuenta.cuentaId == _cuentaSeleccionadaId) {
        return cuenta;
      }
    }
    return venta.cuentas.isNotEmpty ? venta.cuentas.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final rawSelectedMode = ref.watch(meseroSelectedModeProvider);


    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_cargaInicialCompletada) {
          return const AppLoader(message: 'Cargando operación de mesas...');
        }
        if (snapshot.hasError) return AppErrorView(message: snapshot.error.toString(), onRetry: _reload);

        final isCajero = _isCajeroOperativo();
        final authorizedKeys = ref.watch(userMenuProvider).maybeWhen(
              data: (items) => items.map((item) => item.keyName).toSet(),
              orElse: () => const <String>{},
            );
        final canViewHistory =
            isCajero || authorizedKeys.contains('historial_ventas');
        final canCloseCash =
            isCajero || authorizedKeys.contains('cierre_caja');
        final selectedMode =
            (rawSelectedMode == MeseroPageMode.historial && !canViewHistory) ||
                    (rawSelectedMode == MeseroPageMode.cierreCaja && !canCloseCash)
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
          return content;
        }

        if (selectedMode == MeseroPageMode.mesas && isCajero && !_mostrandoDetalleVenta) {
          return Stack(
            fit: StackFit.expand,
            children: [
              content,
              Positioned(
                right: 20,
                bottom: 20,
                child: _CrearMesaFloatingButton(
                  enabled: !_processing,
                  onPressed: _crearMesa,
                ),
              ),
            ],
          );
        }

        return content;
      },
    );
  }

  Widget _buildScrollableContent(bool isCajero, MeseroPageMode selectedMode) {
    return CustomScrollView(
      key: PageStorageKey<String>('mesero-operational-scroll-${selectedMode.name}'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        if (selectedMode == MeseroPageMode.mesas) ...[
          if (_mostrandoDetalleVenta && _ventaActiva != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
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
            padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 600 ? 12 : 24, 0,
                MediaQuery.sizeOf(context).width < 600 ? 12 : 24, 0),
            sliver: SliverToBoxAdapter(child: _buildHistorialVentas()),
          )
        else if (selectedMode == MeseroPageMode.cierreCaja)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            sliver: SliverToBoxAdapter(child: _buildCierreCaja()),
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
    final hasMesas = _mesas.isNotEmpty;
    final mesasVisibles = _mesasFiltradas;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        sliver: SliverToBoxAdapter(child: _buildMesasCommandArea()),
      ),
      if (hasMesas) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          sliver: SliverToBoxAdapter(child: _buildMesaFilters()),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
      if (hasMesas && mesasVisibles.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.crossAxisExtent.isFinite
                  ? constraints.crossAxisExtent
                  : MediaQuery.sizeOf(context).width;
              final targetColumns = availableWidth >= 1360
                  ? 4
                  : availableWidth >= 980
                      ? 3
                      : availableWidth >= 620
                          ? 2
                          : 1;
              final crossAxisCount = mesasVisibles.length < targetColumns ? mesasVisibles.length : targetColumns;

              return SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final mesa = mesasVisibles[index];
                    final isCajero = _canManageTables();
                    final inactiva = _mesaInactiva(mesa);
                    return _MesaCard(
                      mesa: mesa,
                      canEdit: !inactiva || isCajero,
                      canDelete: isCajero,
                      onEdit: () => _editarMesa(mesa, isCajero: isCajero),
                      onDelete: isCajero ? () => _eliminarMesa(mesa) : null,
                      onPagar: inactiva || mesa.ventaId == null ? null : () => _pagarMesaDesdeTarjeta(mesa),
                      onTap: inactiva ? null : () => _abrirVenta(mesa),
                    );
                  },
                  childCount: mesasVisibles.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: crossAxisCount == 1 ? 194 : 208,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              );
            },
          ),
        )
      else if (hasMesas)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 110),
          sliver: SliverToBoxAdapter(
            child: AppEmptyView(
              message: _mesaBuscar.trim().isNotEmpty
                  ? 'No encontramos mesas que coincidan con “${_mesaBuscar.trim()}”.'
                  : 'No hay mesas en este estado.',
            ),
          ),
        )
      else ...[
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 110),
            child: AppEmptyView(message: 'No hay mesas asociadas. Puedes seguir vendiendo con Venta rápida.'),
          ),
        ),
      ],
    ];
  }

  Widget _buildMesasCommandArea() {
    final quickSale = _VentaDirectaActionCard(
      ventasAbiertas: _ventasDirectasAbiertas,
      enabled: !_processing,
      onPressed: _gestionarVentasDirectas,
      onVerAbiertas: _ventasDirectasAbiertas.isEmpty ? null : _mostrarVentasDirectasPendientes,
    );
    final summary = _MesasOperacionResumen(mesas: _mesas);

    if (_mesas.isEmpty) return quickSale;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1040) {
          return Column(
            children: [
              quickSale,
              const SizedBox(height: 10),
              summary,
            ],
          );
        }

        final availableWidth = constraints.maxWidth - 12;
        final quickSaleWidth = availableWidth * 5 / 12;
        final quickSaleUsesCompactLayout = quickSaleWidth < 620;
        final commandAreaHeight = quickSaleUsesCompactLayout ? 128.0 : 78.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: SizedBox(height: commandAreaHeight, child: quickSale),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 7,
              child: SizedBox(
                height: commandAreaHeight,
                child: Align(alignment: Alignment.topCenter, child: summary),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMesaFilters() {
    final ocupadas = _mesas.where((mesa) => mesa.ventaId != null && !_mesaInactiva(mesa)).length;
    final inactivas = _mesas.where(_mesaInactiva).length;
    final libres = (_mesas.length - ocupadas - inactivas).clamp(0, _mesas.length).toInt();

    Widget filtro(String value, String label, int count, IconData icon) {
      final selected = _mesaEstadoFiltro == value;
      return ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(icon, size: 16, color: selected ? Theme.of(context).colorScheme.onSecondary : palette.textSecondary),
        label: Text('$label $count'),
        labelStyle: TextStyle(
          color: selected ? Theme.of(context).colorScheme.onSecondary : palette.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
        selectedColor: palette.secondary,
        backgroundColor: palette.surface,
        side: BorderSide(color: selected ? palette.secondary : palette.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (_) => setState(() => _mesaEstadoFiltro = value),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final search = SizedBox(
          width: compact ? double.infinity : 220,
          height: 42,
          child: TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: _mesaBuscarController,
            onChanged: (value) => setState(() => _mesaBuscar = value),
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Buscar mesa...',
              prefixIcon: const Icon(Icons.search_rounded, size: 19),
              suffixIcon: _mesaBuscar.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        _mesaBuscarController.clear();
                        setState(() => _mesaBuscar = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: palette.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.secondary, width: 1.3)),
            ),
          ),
        );

        final chips = Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            filtro('todas', 'Todas', _mesas.length, Icons.grid_view_rounded),
            filtro('ocupadas', 'Ocupadas', ocupadas, Icons.receipt_long_rounded),
            filtro('libres', 'Libres', libres, Icons.event_available_rounded),
          ],
        );

        final addMesaButton = _canManageTables()
            ? FilledButton.icon(
                onPressed: _processing ? null : _crearMesa,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar mesa'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            : null;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chips,
              const SizedBox(height: 9),
              search,
              if (addMesaButton != null) ...[
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: addMesaButton),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: chips),
            const SizedBox(width: 12),
            search,
            if (addMesaButton != null) ...[
              const SizedBox(width: 8),
              addMesaButton,
            ],
          ],
        );
      },
    );
  }

  Widget _buildMesaGrid() {
    final mesasVisibles = _mesasFiltradas;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
        final isSingleColumn = availableWidth < 600;
        final targetColumns = availableWidth >= 1360
            ? 4
            : availableWidth >= 980
                ? 3
                : availableWidth >= 620
                    ? 2
                    : 1;
        final visibleColumns = mesasVisibles.isEmpty
            ? 1
            : mesasVisibles.length < targetColumns
                ? mesasVisibles.length
                : targetColumns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMesasCommandArea(),
            if (_mesas.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildMesaFilters(),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: mesasVisibles.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: visibleColumns,
                  mainAxisExtent: isSingleColumn ? 194 : 208,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final mesa = mesasVisibles[index];
                  final isCajero = _canManageTables();
                  final inactiva = _mesaInactiva(mesa);
                  return _MesaCard(
                    mesa: mesa,
                    canEdit: !inactiva || isCajero,
                    canDelete: isCajero,
                    onEdit: () => _editarMesa(mesa, isCajero: isCajero),
                    onDelete: isCajero ? () => _eliminarMesa(mesa) : null,
                    onPagar: inactiva || mesa.ventaId == null ? null : () => _pagarMesaDesdeTarjeta(mesa),
                    onTap: inactiva ? null : () => _abrirVenta(mesa),
                  );
                },
              ),
              if (mesasVisibles.isEmpty) ...[
                const SizedBox(height: 12),
                AppEmptyView(
                  message: _mesaBuscar.trim().isNotEmpty
                      ? 'No encontramos mesas que coincidan con “${_mesaBuscar.trim()}”.'
                      : 'No hay mesas en este estado.',
                ),
              ],
            ] else ...[
              const SizedBox(height: 12),
              const AppEmptyView(message: 'No hay mesas asociadas. Puedes seguir vendiendo con Venta rápida.'),
            ],
          ],
        );
      },
    );
  }

  Widget _buildResumenMesas() {
    if (_mesas.isEmpty) return const AppEmptyView(message: 'No hay mesas para resumir.');

    final mesasEnCurso = _mesas
        .where((mesa) => mesa.ventaId != null && !_mesaInactiva(mesa))
        .toList(growable: false)
      ..sort((a, b) {
        final porSaldo = (b.totalPendiente ?? 0).compareTo(a.totalPendiente ?? 0);
        if (porSaldo != 0) return porSaldo;
        return (a.mesaNumero ?? 0).compareTo(b.mesaNumero ?? 0);
      });
    final totalPendiente = mesasEnCurso.fold<double>(0, (sum, mesa) => sum + (mesa.totalPendiente ?? 0));
    final cuentasAbiertas = mesasEnCurso.fold<int>(0, (sum, mesa) => sum + (mesa.numeroCuentas ?? 0));
    final inactivas = _mesas.where(_mesaInactiva).length;
    final mesasLibres = (_mesas.length - mesasEnCurso.length - inactivas).clamp(0, _mesas.length).toInt();
    MeseroMesaResumenModel? mesaPrioritaria;
    for (final mesa in mesasEnCurso) {
      if ((mesa.totalPendiente ?? 0) > 0.009) {
        mesaPrioritaria = mesa;
        break;
      }
    }
    final mesasVisibles = mesasEnCurso.take(5).toList(growable: false);
    final prioridad = mesaPrioritaria;

    final header = _ResumenOperativoHeader(
      totalPendiente: totalPendiente,
      mesasEnCurso: mesasEnCurso.length,
      mesasLibres: mesasLibres,
      cuentasAbiertas: cuentasAbiertas,
      onActualizar: _reloadResumenOperativo,
      onVerMesas: () => ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.mesas,
      onVerProductos: () => ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.productos,
      onCobrarPrioridad: prioridad == null ? null : () => _pagarMesaDesdeTarjeta(prioridad),
    );

    final mesasCard = _ResumenSectionCard(
      icon: Icons.room_service_rounded,
      title: 'Atención en curso',
      subtitle: mesasEnCurso.isEmpty
          ? 'No hay mesas con ventas abiertas en este momento.'
          : 'Primero aparecen las mesas con mayor saldo pendiente.',
      trailing: mesasEnCurso.isEmpty
          ? null
          : _ResumenSectionBadge(label: '${mesasEnCurso.length} abiertas'),
      child: mesasEnCurso.isEmpty
          ? _ResumenEmptyState(
              icon: Icons.event_available_rounded,
              title: 'Salón al día',
              message: 'Todas las mesas están libres. Puedes iniciar una nueva venta desde Mesas.',
              actionLabel: 'Ir a mesas',
              onAction: () => ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.mesas,
            )
          : Column(
              children: [
                for (var index = 0; index < mesasVisibles.length; index++) ...[
                  _ResumenMesaOperativaRow(
                    mesa: mesasVisibles[index],
                    onAbrir: () => _abrirVenta(mesasVisibles[index]),
                    onCobrar: (mesasVisibles[index].totalPendiente ?? 0) > 0.009
                        ? () => _pagarMesaDesdeTarjeta(mesasVisibles[index])
                        : null,
                  ),
                  if (index != mesasVisibles.length - 1) const SizedBox(height: 10),
                ],
                if (mesasEnCurso.length > mesasVisibles.length) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.mesas,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text('Ver ${mesasEnCurso.length - mesasVisibles.length} mesas más'),
                    ),
                  ),
                ],
              ],
            ),
    );

    final actividadCard = _buildResumenActividadHoy();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            if (compact) {
              return Column(
                children: [
                  mesasCard,
                  const SizedBox(height: 16),
                  actividadCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: mesasCard),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: actividadCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildResumenActividadHoy() {
    _historialVentasFuture ??= _cargarHistorialVentas();

    return FutureBuilder<List<MeseroVentaModel>>(
      future: _historialVentasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ResumenSectionCard(
            icon: Icons.insights_rounded,
            title: 'Actividad de hoy',
            subtitle: 'Consultando ventas y productos registrados...',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: AppLoader(message: 'Preparando resumen del día...'),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ResumenSectionCard(
            icon: Icons.insights_rounded,
            title: 'Actividad de hoy',
            subtitle: 'No fue posible consultar el historial del día.',
            child: _ResumenEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Resumen temporalmente no disponible',
              message: snapshot.error.toString(),
              actionLabel: 'Reintentar',
              onAction: _reloadHistorialVentas,
            ),
          );
        }

        final hoy = _soloFecha(DateTime.now());
        final ventasHoy = (snapshot.data ?? _historialVentas).where((venta) {
          final fecha = _parseFechaVentaHistorial(venta.fecha);
          return fecha != null && _esMismoDia(fecha, hoy);
        }).toList(growable: false);

        double totalVendido = 0;
        double totalCobrado = 0;
        double totalPropinas = 0;
        int cuentasAtendidas = 0;
        final cantidadesPorProducto = <int, double>{};
        final totalesPorProducto = <int, double>{};
        final nombresPorProducto = <int, String>{};

        for (final venta in ventasHoy) {
          totalVendido += venta.total ?? 0;
          totalCobrado += venta.totalPagado ?? (venta.pagada == true ? (venta.total ?? 0) : 0);
          totalPropinas += venta.propina ?? 0;
          cuentasAtendidas += venta.cuentas.length;
          for (final cuenta in venta.cuentas) {
            for (final detalle in cuenta.productos) {
              final productoId = detalle.productoId;
              if (productoId == null) continue;
              cantidadesPorProducto[productoId] = (cantidadesPorProducto[productoId] ?? 0) + (detalle.cantidad ?? 0);
              totalesPorProducto[productoId] = (totalesPorProducto[productoId] ?? 0) + (detalle.subtotal ?? 0);
              nombresPorProducto[productoId] = detalle.productoNombre ?? 'Producto $productoId';
            }
          }
        }

        final productosOrdenados = cantidadesPorProducto.keys.toList(growable: false)
          ..sort((a, b) {
            final porCantidad = (cantidadesPorProducto[b] ?? 0).compareTo(cantidadesPorProducto[a] ?? 0);
            if (porCantidad != 0) return porCantidad;
            return (nombresPorProducto[a] ?? '').compareTo(nombresPorProducto[b] ?? '');
          });
        final topProductos = productosOrdenados.take(5).map((productoId) {
          return _ResumenProductoDia(
            nombre: nombresPorProducto[productoId] ?? 'Producto $productoId',
            cantidad: cantidadesPorProducto[productoId] ?? 0,
            total: totalesPorProducto[productoId] ?? 0,
          );
        }).toList(growable: false);

        return _ResumenActividadHoyCard(
          ventas: ventasHoy.length,
          cuentas: cuentasAtendidas,
          totalVendido: totalVendido,
          totalCobrado: totalCobrado,
          propinas: totalPropinas,
          productos: topProductos,
          onProductoTap: _abrirProductoDesdeResumen,
        );
      },
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
    unawaited(_reloadHistorialVentas());
  }

  void _filtrarHistorialHoy() {
    setState(() {
      _historialDiaFiltro = _soloFecha(DateTime.now());
    });
    unawaited(_reloadHistorialVentas());
  }

  void _limpiarFiltroHistorial() {
    setState(() {
      _historialDiaFiltro = null;
    });
    unawaited(_reloadHistorialVentas());
  }

  DateTime? _parseFechaHoraVentaHistorial(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final candidates = <String>[
      text,
      text.contains(' ') ? text.replaceFirst(' ', 'T') : text,
    ];
    for (final candidate in candidates) {
      final parsed = DateTime.tryParse(candidate);
      if (parsed != null) return parsed.toLocal();
    }

    final dmy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?').firstMatch(text);
    if (dmy != null) {
      final day = int.tryParse(dmy.group(1)!);
      final month = int.tryParse(dmy.group(2)!);
      final year = int.tryParse(dmy.group(3)!);
      final hour = int.tryParse(dmy.group(4) ?? '0') ?? 0;
      final minute = int.tryParse(dmy.group(5) ?? '0') ?? 0;
      final second = int.tryParse(dmy.group(6) ?? '0') ?? 0;
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }
    return null;
  }

  String _etiquetaDiaHistorial(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final day = _soloFecha(date);
    final today = _soloFecha(DateTime.now());
    if (_esMismoDia(day, today)) return 'Hoy';
    if (_esMismoDia(day, today.subtract(const Duration(days: 1)))) return 'Ayer';
    return _formatearDiaHistorial(day);
  }

  String _horaHistorial(MeseroVentaModel venta) {
    final date = _parseFechaHoraVentaHistorial(venta.fecha);
    if (date == null || (date.hour == 0 && date.minute == 0)) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _ventaHistorialPagada(MeseroVentaModel venta) {
    return venta.pagada == true || (venta.saldoPendiente ?? 0) <= 0.009;
  }

  String _normalizarTextoHistorial(String? value) {
    return (value ?? '')
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  bool _ventaCoincideBusquedaHistorial(MeseroVentaModel venta, String query) {
    if (query.isEmpty) return true;
    final values = <String>[
      venta.ventaId?.toString() ?? '',
      venta.mesaNumero?.toString() ?? '',
      venta.mesaDescripcion ?? '',
      venta.tipoVenta ?? '',
      _ventaEsDirecta(venta) ? 'venta directa mostrador sin mesa' : 'venta mesa',
      venta.estado ?? '',
      venta.fecha ?? '',
      ...venta.cuentas.expand((cuenta) sync* {
        yield _cuentaNombreVisible(cuenta);
        yield cuenta.descripcion ?? '';
        for (final producto in cuenta.productos) {
          yield producto.productoNombre ?? '';
        }
        for (final pago in cuenta.pagos) {
          yield pago.medioPagoNombre ?? '';
        }
      }),
    ];
    return values.any((value) => _normalizarTextoHistorial(value).contains(query));
  }

  List<MeseroVentaModel> _filtrarYOrdenarHistorial(List<MeseroVentaModel> ventas) {
    final query = _normalizarTextoHistorial(_historialBuscar);
    final filtroDia = _historialDiaFiltro;
    final filtered = ventas.where((venta) {
      if (filtroDia != null) {
        final fechaVenta = _parseFechaVentaHistorial(venta.fecha);
        if (fechaVenta == null || !_esMismoDia(fechaVenta, filtroDia)) return false;
      }
      if (_historialEstado == 'pagadas' && !_ventaHistorialPagada(venta)) return false;
      if (_historialEstado == 'pendientes' && _ventaHistorialPagada(venta)) return false;
      return _ventaCoincideBusquedaHistorial(venta, query);
    }).toList(growable: true);

    int compareDate(MeseroVentaModel a, MeseroVentaModel b) {
      final aDate = _parseFechaHoraVentaHistorial(a.fecha);
      final bDate = _parseFechaHoraVentaHistorial(b.fecha);
      if (aDate != null && bDate != null) return aDate.compareTo(bDate);
      if (aDate != null) return 1;
      if (bDate != null) return -1;
      return (a.ventaId ?? 0).compareTo(b.ventaId ?? 0);
    }

    filtered.sort((a, b) {
      switch (_historialOrden) {
        case 'antiguas':
          return compareDate(a, b);
        case 'mayor':
          return (b.total ?? 0).compareTo(a.total ?? 0);
        case 'menor':
          return (a.total ?? 0).compareTo(b.total ?? 0);
        case 'recientes':
        default:
          return compareDate(b, a);
      }
    });
    return filtered;
  }

  Widget _buildHistorialFiltrosPanel({required int totalVentas, required int ventasMostradas}) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final filtro = _historialDiaFiltro;
    final filtroActivo = filtro != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.secondary.withOpacity(0.14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final search = TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: _historialBuscarController,
            onChanged: (value) => setState(() => _historialBuscar = value),
            decoration: InputDecoration(
              labelText: 'Buscar en ventas',
              hintText: 'Venta, mesa, producto o medio de pago',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _historialBuscar.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        _historialBuscarController.clear();
                        setState(() => _historialBuscar = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ).compactFilter(),
          );

          final status = DropdownButtonFormField<String>(
            // El selector comparte fila con otros filtros en escritorio.
            // Sin isExpanded, el texto completo fuerza un RenderFlex overflow.
            isExpanded: true,
            value: _historialEstado,
            decoration: const InputDecoration(labelText: 'Estado', prefixIcon: Icon(Icons.verified_rounded)).compactFilter(),
            items: const [
              DropdownMenuItem(value: 'todos', child: Text('Todos los estados', maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'pagadas', child: Text('Pagadas', maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'pendientes', child: Text('Con saldo pendiente', maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) => setState(() => _historialEstado = value ?? 'todos'),
          );

          final order = DropdownButtonFormField<String>(
            isExpanded: true,
            value: _historialOrden,
            decoration: const InputDecoration(labelText: 'Ordenar', prefixIcon: Icon(Icons.swap_vert_rounded)).compactFilter(),
            items: const [
              DropdownMenuItem(value: 'recientes', child: Text('Más recientes', maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'antiguas', child: Text('Más antiguas', maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'mayor', child: Text('Mayor total', maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'menor', child: Text('Menor total', maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) => setState(() => _historialOrden = value ?? 'recientes'),
          );

          final filters = compact
              ? Column(
                  children: [
                    search,
                    const SizedBox(height: 10),
                    if (constraints.maxWidth < 520) ...[
                      status,
                      const SizedBox(height: 10),
                      order,
                    ] else
                      Row(children: [Expanded(child: status), const SizedBox(width: 10), Expanded(child: order)]),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 5, child: search),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: status),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: order),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              filters,
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _SmallInfoPill(icon: Icons.receipt_long_rounded, text: '$ventasMostradas de $totalVentas ventas'),
                  OutlinedButton.icon(
                    onPressed: _seleccionarDiaHistorial,
                    icon: const Icon(Icons.event_rounded),
                    label: Text(filtroActivo ? _formatearDiaHistorial(filtro) : 'Seleccionar día'),
                  ),
                  TextButton.icon(onPressed: _filtrarHistorialHoy, icon: const Icon(Icons.today_rounded), label: const Text('Hoy')),
                  if (filtroActivo)
                    TextButton.icon(onPressed: _limpiarFiltroHistorial, icon: const Icon(Icons.date_range_rounded), label: const Text('Todos los días')),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistorialVentas() {
    final palette = ref.watch(selectedAppPaletteProvider);
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
          return AppErrorView(message: snapshot.error.toString(), onRetry: _reloadHistorialVentas);
        }

        final ventas = snapshot.data ?? _historialVentas;
        // Mantener visibles los controles de fecha incluso si el día no tiene ventas.
        // Así se puede salir del estado vacío seleccionando otro día.
        final ventasFiltradas = _filtrarYOrdenarHistorial(ventas);
        final totalVendido = ventasFiltradas.fold<double>(0, (sum, venta) => sum + (venta.total ?? 0));
        final totalPagado = ventasFiltradas.fold<double>(0, (sum, venta) => sum + (venta.totalPagado ?? (venta.pagada == true ? (venta.total ?? 0) : 0)));
        final saldoPendiente = ventasFiltradas.fold<double>(0, (sum, venta) => sum + (venta.saldoPendiente ?? 0));
        final propinas = ventasFiltradas.fold<double>(0, (sum, venta) => sum + (venta.propina ?? 0));
        final double ticketPromedio = ventasFiltradas.isEmpty ? 0.0 : (totalVendido / ventasFiltradas.length).toDouble();

        final grupos = <String, ({DateTime? fecha, List<MeseroVentaModel> ventas})>{};
        for (final venta in ventasFiltradas) {
          final date = _parseFechaHoraVentaHistorial(venta.fecha);
          final day = date == null ? null : _soloFecha(date);
          final key = day == null ? 'sin-fecha' : '${day.year}-${day.month}-${day.day}';
          final current = grupos[key];
          if (current == null) {
            grupos[key] = (fecha: day, ventas: <MeseroVentaModel>[venta]);
          } else {
            current.ventas.add(venta);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Historial de ventas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Consulta rápidamente qué se vendió, cuánto se cobró y cómo se pagó.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton.filledTonal(tooltip: 'Actualizar historial', onPressed: _reloadHistorialVentas, icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
            const SizedBox(height: 14),
            _HistorialResumenOperacion(
              ventas: ventasFiltradas.length,
              totalVendido: totalVendido,
              totalPagado: totalPagado,
              saldoPendiente: saldoPendiente,
              propinas: propinas,
              ticketPromedio: ticketPromedio,
            ),
            const SizedBox(height: 14),
            _buildHistorialFiltrosPanel(totalVentas: ventas.length, ventasMostradas: ventasFiltradas.length),
            const SizedBox(height: 18),
            if (ventasFiltradas.isEmpty)
              const AppEmptyView(message: 'No hay ventas que coincidan con los filtros seleccionados.')
            else
              ...grupos.values.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _HistorialDiaSection(
                    titulo: _etiquetaDiaHistorial(group.fecha),
                    fecha: group.fecha == null ? '' : _formatearDiaHistorial(group.fecha!),
                    ventas: group.ventas,
                    horaVenta: _horaHistorial,
                    onVerDetalle: _mostrarDetalleHistorialVenta,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarDetalleHistorialVenta(MeseroVentaModel venta, {String? comprobanteInicial}) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: false,
        builder: (_) => _DetalleHistorialVentaPage(venta: venta, imprimirAlAbrir: comprobanteInicial == 'imprimir', enviarCorreoAlAbrir: comprobanteInicial == 'correo'),
      ),
    );
    if (mounted) {
      await _reloadHistorialVentas();
    }
  }

  Widget _buildProductoCatalogoToolbar({required int resultados}) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final tipos = _tiposProductoDisponibles;
    final marcas = _marcasProductoDisponibles;
    final hayFiltros = _productoFiltro.trim().isNotEmpty ||
        (_tipoProductoFiltro ?? '').trim().isNotEmpty ||
        (_marcaProductoFiltro ?? '').trim().isNotEmpty;

    void limpiarFiltros() {
      _productoFiltroController.clear();
      setState(() {
        _productoFiltro = '';
        _tipoProductoFiltro = null;
        _marcaProductoFiltro = null;
      });
    }

    final searchField = TextField(
      maxLength: 120,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      controller: _productoFiltroController,
      decoration: InputDecoration(
        labelText: 'Buscar productos',
        hintText: 'Nombre, marca, categoría, código o precio',
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
      ).compactFilter(),
      onChanged: (value) => setState(() => _productoFiltro = value),
    );

    final marcaField = DropdownButtonFormField<String>(
      value: marcas.contains(_marcaProductoFiltro) ? _marcaProductoFiltro : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Marca',
        prefixIcon: Icon(Icons.local_offer_outlined),
      ).compactFilter(),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Todas las marcas')),
        ...marcas.map(
          (marca) => DropdownMenuItem(
            value: marca,
            child: Text(marca, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: marcas.isEmpty
          ? null
          : (value) => setState(() => _marcaProductoFiltro = value),
    );

    final ordenField = DropdownButtonFormField<String>(
      value: _productosOrdenCatalogo,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Orden',
        prefixIcon: Icon(Icons.sort_rounded),
      ).compactFilter(),
      items: const [
        DropdownMenuItem(value: 'nombre', child: Text('Nombre A–Z')),
        DropdownMenuItem(value: 'precioMenor', child: Text('Menor precio')),
        DropdownMenuItem(value: 'precioMayor', child: Text('Mayor precio')),
        DropdownMenuItem(value: 'marca', child: Text('Marca')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _productosOrdenCatalogo = value);
      },
    );

    final categories = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CatalogoCategoryChip(
            label: 'Todos',
            icon: Icons.apps_rounded,
            selected: (_tipoProductoFiltro ?? '').trim().isEmpty,
            onSelected: () => setState(() => _tipoProductoFiltro = null),
          ),
          for (final tipo in tipos) ...[
            const SizedBox(width: 7),
            _CatalogoCategoryChip(
              label: tipo,
              icon: Icons.category_outlined,
              selected: _tipoProductoFiltro == tipo,
              onSelected: () => setState(
                () => _tipoProductoFiltro = _tipoProductoFiltro == tipo ? null : tipo,
              ),
            ),
          ],
        ],
      ),
    );

    final resultBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(palette.radius(999)),
        border: Border.all(color: palette.secondary.withOpacity(0.20)),
      ),
      child: Text(
        '$resultados ${resultados == 1 ? 'producto' : 'productos'}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: palette.secondary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );

    final viewToggle = _CatalogoViewToggle(
      gridSelected: _productosVistaCuadricula,
      onGrid: () => setState(() => _productosVistaCuadricula = true),
      onList: () => setState(() => _productosVistaCuadricula = false),
    );

    return Container(
      width: double.infinity,
      padding: palette.panelPadding(14),
      decoration: palette.panelDecoration(
        baseRadius: 22,
        tint: palette.secondary,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;
          final tablet = constraints.maxWidth < 1050;

          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 10),
                Row(
                  children: [
                    resultBadge,
                    const Spacer(),
                    viewToggle,
                    if (hayFiltros) ...[
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Quitar filtros',
                        onPressed: limpiarFiltros,
                        icon: const Icon(Icons.filter_alt_off_rounded),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Categorías',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                categories,
                const SizedBox(height: 11),
                marcaField,
                const SizedBox(height: 10),
                ordenField,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(flex: tablet ? 5 : 7, child: searchField),
                  const SizedBox(width: 10),
                  SizedBox(width: tablet ? 190 : 220, child: marcaField),
                  const SizedBox(width: 10),
                  SizedBox(width: tablet ? 180 : 205, child: ordenField),
                  const SizedBox(width: 10),
                  resultBadge,
                  const SizedBox(width: 8),
                  viewToggle,
                  if (hayFiltros) ...[
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: 'Quitar filtros',
                      onPressed: limpiarFiltros,
                      icon: const Icon(Icons.filter_alt_off_rounded),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 18, color: palette.secondary),
                  const SizedBox(width: 7),
                  Text(
                    'Categorías',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: categories),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductosStandalone() {
    final productos = _productosCatalogoOrdenados;
    final precios = _productos.map((producto) => producto.precioVenta).whereType<double>().where((precio) => precio > 0).toList(growable: false);
    double? precioDesde;
    if (precios.isNotEmpty) {
      precioDesde = precios.first;
      for (final precio in precios.skip(1)) {
        if (precio < precioDesde!) precioDesde = precio;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProductosCatalogoResumen(
          total: _productos.length,
          visibles: productos.length,
          tipos: _tiposProductoDisponibles.length,
          marcas: _marcasProductoDisponibles.length,
          precioDesde: precioDesde,
        ),
        const SizedBox(height: 16),
        _buildProductoCatalogoToolbar(resultados: productos.length),
        const SizedBox(height: 16),
        if (_productos.isEmpty)
          const AppEmptyView(message: 'No hay productos con precio vigente para tu sucursal.')
        else if (productos.isEmpty)
          _CatalogoEmptyState(
            onClear: () {
              _productoFiltroController.clear();
              setState(() {
                _productoFiltro = '';
                _tipoProductoFiltro = null;
                _marcaProductoFiltro = null;
              });
            },
          )
        else
          _ProductosCatalogoTabla(
            productos: productos,
            vistaCuadricula: _productosVistaCuadricula,
            onOpen: _mostrarDetalleProductoCatalogo,
          ),
      ],
    );
  }

  Future<void> _mostrarDetalleProductoCatalogo(MeseroProductoModel producto) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.66),
      builder: (_) => _ProductoCatalogoDetalleSheet(producto: producto),
    );
  }

  Widget _buildPantallaDetalleVenta(MeseroVentaModel venta) {
    final descripcion = (venta.mesaDescripcion ?? '').trim();
    final ventaDirecta = _esVentaDirecta(venta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Volver a ventas',
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
                    ventaDirecta ? 'Venta directa #${venta.ventaId ?? '-'}' : 'Venta de mesa ${venta.mesaNumero ?? '-'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ventaDirecta ? 'Agrega productos y cobra en el mismo flujo POS, sin ocupar una mesa.' : (descripcion.isEmpty ? 'Selecciona la cuenta y agrega los productos pedidos.' : descripcion),
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
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
    final ventaDirecta = _esVentaDirecta(venta);
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
                    '${ventaDirecta ? 'Venta directa #${venta.ventaId ?? '-'}' : 'Mesa ${venta.mesaNumero ?? '-'}'} · ${_cuentaEtiquetaVisible(cuenta)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                  ),
                  if (descripcionVenta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      descripcionVenta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
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

  Future<void> _reimprimirComandaCocina(MeseroVentaModel venta, MeseroCuentaModel cuenta) async {
    final sucursalId = venta.sucursalId;
    final cuentaId = cuenta.cuentaId;
    if (sucursalId == null || cuentaId == null || _processing) return;
    setState(() => _processing = true);
    try {
      final response = await ref.read(apiClientProvider).get<List<dynamic>>(
        '/api/v1/comandas',
        (json) => json is List ? json : <dynamic>[],
        queryParameters: {'sucursalId': sucursalId},
      );
      final detalles = (response.data ?? <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['cuentaId'] == cuentaId && item['fechaEnvio'] != null)
          .toList();
      if (!mounted) return;
      if (detalles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta cuenta todavía no tiene comandas enviadas.')),
        );
        return;
      }
      final ticket = StringBuffer()
        ..writeln('REIMPRESION COMANDA')
        ..writeln('--------------------------------')
        ..writeln(_ventaEsDirecta(venta) ? 'VENTA DIRECTA' : 'MESA ${venta.mesaNumero ?? "-"}')
        ..writeln(_cuentaNombreVisible(cuenta))
        ..writeln('Venta #${venta.ventaId ?? "-"}')
        ..writeln('--------------------------------');
      for (final item in detalles) {
        ticket.writeln('${item['cantidad'] ?? 0} x ${item['productoNombre'] ?? 'Producto'}');
        final nota = (item['personalizacion'] ?? '').toString().trim();
        if (nota.isNotEmpty) ticket.writeln('  ${nota.replaceAll(RegExp(r'[\\r\\n]+'), ' ')}');
      }
      final printed = await printTicketOverLan(
        context,
        sucursalId,
        ticket.toString(),
        autoPrintIfConfigured: true,
        station: 'cocina',
      );
      if (mounted && printed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comanda reimpresa correctamente.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible reimprimir la comanda: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _enviarComandaCocina(MeseroVentaModel venta, MeseroCuentaModel cuenta) async {
    final sucursalId = venta.sucursalId;
    final cuentaId = cuenta.cuentaId;
    if (sucursalId == null || cuentaId == null || _processing) return;
    setState(() => _processing = true);
    try {
      final response = await ref.read(apiClientProvider).post<List<dynamic>>(
        '/api/v1/comandas/cuenta/$cuentaId/enviar',
        null,
        (json) => json is List ? json : <dynamic>[],
        queryParameters: {'sucursalId': sucursalId},
      );
      final detalles = (response.data ?? <dynamic>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      if (detalles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay productos nuevos pendientes de enviar a cocina.')),
        );
        return;
      }
      final ticket = StringBuffer()
        ..writeln('COMANDA - COCINA')
        ..writeln('--------------------------------')
        ..writeln(_ventaEsDirecta(venta) ? 'VENTA DIRECTA' : 'MESA ${venta.mesaNumero ?? "-"}')
        ..writeln(_cuentaNombreVisible(cuenta))
        ..writeln('Venta #${venta.ventaId ?? "-"}')
        ..writeln('Hora: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}')
        ..writeln('--------------------------------');
      for (final detalle in detalles) {
        ticket.writeln('${detalle['cantidad'] ?? 0} x ${detalle['productoNombre'] ?? 'Producto'}');
        final observacion = (detalle['personalizacion'] ?? '').toString().trim();
        if (observacion.isNotEmpty) ticket.writeln('  ${observacion.replaceAll(RegExp(r'[\\r\\n]+'), ' ')}');
      }
      ticket
        ..writeln('--------------------------------')
        ..writeln('PEDIDO NUEVO');
      final enviadoImpresora = await printTicketOverLan(
        context,
        sucursalId,
        ticket.toString(),
        autoPrintIfConfigured: true,
        station: 'cocina',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enviadoImpresora
            ? 'Comanda enviada e impresa correctamente.'
            : 'Comanda registrada. Pendiente de imprimir: utiliza la opción de reimpresión.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible enviar la comanda: $error')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
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
          onFinalizarVenta: _processing || venta.ventaId == null || (venta.saldoPendiente ?? 0) > 0.009
              ? null
              : () => _finalizarVenta(venta),
          onLimpiarVentaSinConsumos: _processing || venta.ventaId == null || !_ventaSinProductos(venta)
              ? null
              : () => _limpiarVentaSinConsumos(venta),
        ),
        if (venta.ventaId != null && (venta.totalPagado ?? 0) > 0.009) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              tooltip: 'Opciones de comprobante',
              enabled: !_processing,
              onSelected: (opcion) => _mostrarDetalleHistorialVenta(venta, comprobanteInicial: opcion),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'imprimir',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.print_outlined),
                    title: Text('Imprimir ticket'),
                  ),
                ),
                PopupMenuItem(
                  value: 'correo',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.email_outlined),
                    title: Text('Enviar por correo'),
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 18, color: palette.secondary),
                    const SizedBox(width: 7),
                    Text('Comprobante', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 3),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: palette.secondary),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
                Color.lerp(palette.surface, palette.secondary, 0.05)?.withOpacity(palette.darkBackground ? 0.96 : 0.99) ?? palette.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.secondary.withOpacity(0.14)),
            boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.22), blurRadius: 28, offset: const Offset(0, 14))],
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary),
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
              Text(
                'Selecciona una cuenta para ver su consumo, sus pagos y las acciones de cobro.',
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
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
              if (cuentaSeleccionada != null && cuentaSeleccionada.cuentaId != null && cuentaSeleccionada.productos.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _processing ? null : () => _enviarComandaCocina(venta, cuentaSeleccionada!),
                    icon: const Icon(Icons.soup_kitchen_rounded),
                    label: const Text('Enviar comanda a cocina'),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _processing ? null : () => _reimprimirComandaCocina(venta, cuentaSeleccionada!),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Reimprimir comanda'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (cuentaSeleccionada != null)
                _CuentaDetalle(
                  cuenta: cuentaSeleccionada,
                  onAgregarProductos: _processing || cuentaSeleccionada.cuentaId == null
                      ? null
                      : () => _abrirPestanaAgregarProductos(cuentaSeleccionada!),
                  onIncrementarProducto: (producto) => _ajustarCantidadProductoCuenta(cuentaSeleccionada!, producto, 1),
                  onDisminuirProducto: (producto) => _ajustarCantidadProductoCuenta(cuentaSeleccionada!, producto, -1),
                  onSumarCantidadProducto: (producto) => _mostrarSumarCantidadProducto(cuentaSeleccionada!, producto),
                  productoActualizando: (producto) {
                    final detalleId = producto.detalleId;
                    return detalleId != null && _detallesCantidadEnProceso.contains(detalleId);
                  },
                  onEliminarProducto: _processing ? null : (producto) => _eliminarProductoCuenta(cuentaSeleccionada!, producto),
                  onMoverProducto: _processing ? null : (producto) => _moverProductoCuenta(venta, cuentaSeleccionada!, producto),
                  onPagarCuenta: cuentaSeleccionada.cuentaId == null || _processing
                      ? null
                      : () => _pagarCuenta(venta, cuentaSeleccionada!),
                  onEliminarPago: _processing
                      ? null
                      : (pago) => _eliminarPagoRegistrado(cuentaSeleccionada!, pago),
                  onFinalizarVenta: _processing || venta.ventaId == null || (venta.saldoPendiente ?? 0) > 0.009
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
        color: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.secondary.withOpacity(0.12)),
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
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
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
        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.985),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.20), blurRadius: 24, offset: const Offset(0, 12))],
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
                      'Los productos conservan su posición mientras ajustas las cantidades.',
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
    final cuentaId = cuenta.cuentaId;
    if (cuentaId == null) {
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
        return;
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
      _cuentaSeleccionadaId = cuentaId;
      _mostrandoPestanaAgregarProductos = false;
    });

    await _mostrarPanelAgregarProductos(cuenta);
  }

  Future<void> _mostrarPanelAgregarProductos(MeseroCuentaModel cuenta) async {
    final cantidadesPedidasHoy = await _cargarProductosMasPedidosHoy();
    if (!mounted) return;

    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 760;
    final productosOrdenados = _ordenarProductosPorPedidosHoy(
      _productos,
      cantidadesPedidasHoy,
    );

    final panel = _AgregarProductosOverlayPanel(
      cuenta: cuenta,
      productos: productosOrdenados,
      cantidadesPedidasHoy: cantidadesPedidasHoy,
      onConfirmar: (cantidades) => _agregarProductosDesdePanel(cuenta, cantidades),
    );

    if (mobile) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.48),
        builder: (sheetContext) => FractionallySizedBox(
          heightFactor: 0.94,
          child: panel,
        ),
      );
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar productos',
      barrierColor: Colors.black.withOpacity(0.42),
      transitionDuration: const Duration(milliseconds: 230),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final width = MediaQuery.sizeOf(dialogContext).width;
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: width >= 1350 ? 680 : 610,
              height: double.infinity,
              child: panel,
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  Future<bool> _agregarProductosDesdePanel(
    MeseroCuentaModel cuenta,
    Map<int, double> cantidades, {
    bool mantenerVistaMesas = false,
    bool mostrarMensaje = true,
  }) async {
    final cuentaId = cuenta.cuentaId;
    if (cuentaId == null || cantidades.isEmpty) return false;

    MeseroVentaModel? ventaActualizada;
    var unidadesAgregadas = 0.0;
    var productosAgregados = 0;

    try {
      for (final entry in cantidades.entries) {
        if (entry.value <= 0) continue;
        MeseroProductoModel? producto;
        for (final item in _productos) {
          if (item.prodId == entry.key) {
            producto = item;
            break;
          }
        }
        final productoSeleccionado = producto;
        if (productoSeleccionado == null || productoSeleccionado.prodId == null) continue;

        final prepared =
            (productoSeleccionado.tipoControl ?? '').trim().toUpperCase() ==
                'PREPARADO';
        _PedidoProductoDecision? decision;
        if (prepared) {
          if (!mounted) return false;
          decision = await showDialog<_PedidoProductoDecision>(
            context: context,
            builder: (dialogContext) => _PersonalizarProductoDialog(
              producto: productoSeleccionado,
              initialQuantity: entry.value,
            ),
          );
          if (decision == null) {
            continue;
          }
        }

        final cantidad = decision?.cantidad ?? entry.value;
        ventaActualizada = await _dataSource.agregarProducto(
          cuentaId: cuentaId,
          productoId: productoSeleccionado.prodId!,
          precioId: productoSeleccionado.precId,
          cantidad: cantidad,
          ingredientesExcluidos:
              decision?.ingredientesExcluidos ?? const <int>[],
          adiciones: decision?.adiciones ?? const <int>[],
          observacion: decision?.observacion,
        );
        unidadesAgregadas += cantidad;
        productosAgregados++;
      }

      if (ventaActualizada == null || !mounted) return false;
      final updated = ventaActualizada;
      setState(() {
        _ventaActiva = updated;
        _mostrandoDetalleVenta = !mantenerVistaMesas;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = cuentaId;
        _mesas = _mesas.map((mesa) {
          final corresponde = (updated.mesaId != null && mesa.mesaId == updated.mesaId) ||
              (updated.ventaId != null && mesa.ventaId == updated.ventaId);
          if (!corresponde) return mesa;
          return MeseroMesaResumenModel(
            mesaId: mesa.mesaId ?? updated.mesaId,
            mesaNumero: mesa.mesaNumero ?? updated.mesaNumero,
            sucursalId: mesa.sucursalId ?? updated.sucursalId,
            estadoMesa: mesa.estadoMesa,
            mesaDescripcion: updated.mesaDescripcion ?? mesa.mesaDescripcion,
            mesaFoto: updated.mesaFoto ?? mesa.mesaFoto,
            ventaId: updated.ventaId ?? mesa.ventaId,
            estadoVenta: updated.estado ?? mesa.estadoVenta,
            totalPendiente: updated.saldoPendiente,
            numeroCuentas: updated.cuentas.length,
          );
        }).toList(growable: false);
        if (_esVentaDirecta(updated)) {
          _ventasDirectasAbiertas = <MeseroVentaModel>[
            updated,
            ..._ventasDirectasAbiertas.where((venta) => venta.ventaId != updated.ventaId),
          ];
        }
      });

      if (mostrarMensaje) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_formatCantidadGeneral(unidadesAgregadas)} unidades agregadas en $productosAgregados '
              '${productosAgregados == 1 ? 'producto' : 'productos'} a ${_cuentaNombreVisible(cuenta)}.',
            ),
          ),
        );
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      return false;
    }
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

  Future<void> _gestionarVentasDirectas() async {
    if (_processing) return;

    MeseroVentaModel? venta;
    if (_ventasDirectasAbiertas.isNotEmpty) {
      final abiertas = List<MeseroVentaModel>.from(_ventasDirectasAbiertas)
        ..sort((a, b) => (b.ventaId ?? 0).compareTo(a.ventaId ?? 0));
      final ventaId = abiertas.first.ventaId;
      if (ventaId != null) {
        venta = await _retomarVentaDirecta(ventaId, mostrarDetalle: false);
      }
    } else {
      venta = await _abrirVentaDirecta(mostrarDetalle: false);
    }

    if (!mounted || venta == null) return;
    await _mostrarVentaDirectaRapida(venta);
  }

  Future<void> _mostrarVentasDirectasPendientes() async {
    if (_processing || _ventasDirectasAbiertas.isEmpty) return;
    final seleccion = await showModalBottomSheet<Object>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VentasDirectasAbiertasSheet(ventas: _ventasDirectasAbiertas),
    );
    if (!mounted || seleccion == null) return;

    MeseroVentaModel? venta;
    if (seleccion == _NuevaVentaDirectaAction.instance) {
      venta = await _abrirVentaDirecta(mostrarDetalle: false);
    } else if (seleccion is _EliminarVentaDirectaAction) {
      await _cancelarVentaDirecta(seleccion.venta);
      return;
    } else if (seleccion is MeseroVentaModel && seleccion.ventaId != null) {
      venta = await _retomarVentaDirecta(seleccion.ventaId!, mostrarDetalle: false);
    }

    if (!mounted || venta == null) return;
    await _mostrarVentaDirectaRapida(venta);
  }

  Future<void> _cancelarVentaDirecta(MeseroVentaModel venta) async {
    final ventaId = venta.ventaId;
    if (ventaId == null || _processing) return;

    final pagosRegistrados = venta.cuentas.fold<int>(0, (sum, cuenta) => sum + cuenta.pagos.length);
    if (pagosRegistrados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta venta ya tiene pagos registrados. Elimina o corrige los pagos antes de cancelar la venta.')),
      );
      return;
    }

    final productos = venta.cuentas.fold<int>(0, (sum, cuenta) => sum + cuenta.productos.length);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar venta directa'),
        content: Text(
          'Se eliminará la Venta directa #$ventaId${productos > 0 ? ' y sus $productos productos pendientes' : ''}.\n\n'
          'Esta acción solo está disponible porque la venta sigue abierta y no tiene pagos registrados.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Volver')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar venta'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await _dataSource.cancelarVentaDirecta(ventaId);
      final future = _load();
      setState(() {
        if (_ventaActiva?.ventaId == ventaId) {
          _ventaActiva = null;
          _mostrandoDetalleVenta = false;
          _mostrandoPestanaAgregarProductos = false;
          _cuentaSeleccionadaId = null;
        }
        _future = future;
      });
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Venta directa #$ventaId eliminada correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<MeseroVentaModel?> _abrirVentaDirecta({bool mostrarDetalle = true}) async {
    setState(() => _processing = true);
    try {
      final venta = await _dataSource.abrirVentaDirecta();
      if (!mounted) return null;
      final future = _load();
      ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.mesas;
      setState(() {
        _ventaActiva = venta;
        _mostrandoDetalleVenta = mostrarDetalle;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = venta.cuentas.isNotEmpty ? venta.cuentas.first.cuentaId : null;
        _future = future;
      });
      // Abrir el panel inmediatamente tras crear y validar la cuenta.
      // Una caída temporal al recargar mesas NO debe ocultar una venta
      // directa ya persistida ni forzar al usuario a crear otra.
      unawaited(future.catchError((Object error, StackTrace stackTrace) {
        debugPrint('No se pudo actualizar el listado de mesas tras abrir venta directa: $error');
      }));
      return venta;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      return null;
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<MeseroVentaModel?> _retomarVentaDirecta(int ventaId, {bool mostrarDetalle = true}) async {
    setState(() => _processing = true);
    try {
      final venta = await _dataSource.consultarVenta(ventaId);
      if (!mounted) return null;
      ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.mesas;
      setState(() {
        _ventaActiva = venta;
        _mostrandoDetalleVenta = mostrarDetalle;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = venta.cuentas.isNotEmpty ? venta.cuentas.first.cuentaId : null;
      });
      return venta;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      return null;
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _mostrarVentaDirectaRapida(MeseroVentaModel venta) async {
    if (_productos.isEmpty) {
      setState(() => _processing = true);
      try {
        final productos = await _dataSource.listarProductos();
        if (!mounted) return;
        setState(() => _productos = productos);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
        return;
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    }

    final ventaId = venta.ventaId;
    if (ventaId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La venta directa no tiene identificador.')),
      );
      return;
    }

    // En una venta recién creada, no descartar el panel por usar una
    // respuesta antigua sin la primera cuenta. Consultar la venta persistida.
    MeseroVentaModel listaParaAbrir = venta;
    if (!cuentaDirectaLista(listaParaAbrir)) {
      try {
        listaParaAbrir = await _dataSource.consultarVenta(ventaId);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo consultar la cuenta de la venta #$ventaId: $error')),
        );
        return;
      }
    }
    if (!cuentaDirectaLista(listaParaAbrir)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'La venta #$ventaId sigue abierta, pero no tiene una cuenta disponible. '
          'Puedes retomarla desde ventas directas pendientes.',
        )),
      );
      return;
    }
    if (!mounted) return;
    final cuenta = listaParaAbrir.cuentas.firstWhere((c) => c.cuentaId != null);
    setState(() {
      _ventaActiva = listaParaAbrir;
      _cuentaSeleccionadaId = cuenta.cuentaId;
    });

    final cantidadesPedidasHoy = await _cargarProductosMasPedidosHoy();
    if (!mounted) return;
    final productosOrdenados = _ordenarProductosPorPedidosHoy(_productos, cantidadesPedidasHoy);

    final cuentaDirecta = cuenta!;
    final panel = _AgregarProductosOverlayPanel(
      cuenta: cuentaDirecta,
      productos: productosOrdenados,
      cantidadesPedidasHoy: cantidadesPedidasHoy,
      ventaDirectaRapida: true,
      ventaId: ventaId,
      onConfirmar: (cantidades) => _agregarProductosDesdePanel(
        cuentaDirecta,
        cantidades,
        mantenerVistaMesas: true,
      ),
      onConfirmarRapido: (cantidades, cobrar) => _procesarVentaDirectaRapida(
        cuentaDirecta,
        cantidades,
        cobrar,
      ),
      onActualizarProductoExistente: (producto, cantidad) =>
          _actualizarProductoVentaDirectaRapida(cuentaDirecta, producto, cantidad),
      onEliminarProductoExistente: (producto) =>
          _eliminarProductoVentaDirectaRapida(cuentaDirecta, producto),
    );

    final size = MediaQuery.sizeOf(context);
    if (size.width < 760) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.48),
        builder: (sheetContext) => FractionallySizedBox(heightFactor: 0.96, child: panel),
      );
    } else {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Cerrar venta directa',
        barrierColor: Colors.black.withOpacity(0.42),
        transitionDuration: const Duration(milliseconds: 230),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final width = MediaQuery.sizeOf(dialogContext).width;
          return SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: width >= 1450 ? 760 : (width >= 1100 ? 700 : 640),
                height: double.infinity,
                child: panel,
              ),
            ),
          );
        },
        transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );
    }

    if (!mounted) return;
    final actual = _ventaActiva;
    if (actual?.ventaId == ventaId && _ventaSinProductos(actual!)) {
      try {
        await _dataSource.limpiarVentaSinConsumos(ventaId);
        final future = _load();
        setState(() {
          _ventaActiva = null;
          _mostrandoDetalleVenta = false;
          _cuentaSeleccionadaId = null;
          _future = future;
        });
        await future;
      } catch (_) {
        // Si la venta cambió mientras se cerraba el diálogo, se conserva para no perder información.
      }
    }
  }

  Future<bool> _procesarVentaDirectaRapida(
    MeseroCuentaModel cuenta,
    Map<int, double> cantidades,
    bool cobrar,
  ) async {
    var agregados = false;
    if (cantidades.isNotEmpty) {
      agregados = await _agregarProductosDesdePanel(
        cuenta,
        cantidades,
        mantenerVistaMesas: true,
        mostrarMensaje: !cobrar,
      );
      if (!agregados) return false;
    }

    if (!cobrar) return agregados;

    final venta = _ventaActiva;
    if (venta == null) return false;
    MeseroCuentaModel? cuentaActual;
    for (final item in venta.cuentas) {
      if (item.cuentaId == cuenta.cuentaId) {
        cuentaActual = item;
        break;
      }
    }
    cuentaActual ??= venta.cuentas.isNotEmpty ? venta.cuentas.first : null;
    if (cuentaActual == null || cuentaActual.productos.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto antes de cobrar.')),
      );
      return false;
    }

    final pagada = await _pagarCuenta(
      venta,
      cuentaActual,
      mantenerVistaMesas: true,
      finalizarDirectaAlPagar: true,
    );

    // Si ya se agregaron productos, se cierra el selector aunque el usuario
    // haya cancelado el cobro para evitar agregarlos dos veces al reintentar.
    return pagada || agregados;
  }

  Future<MeseroVentaModel?> _actualizarProductoVentaDirectaRapida(
    MeseroCuentaModel cuenta,
    MeseroDetalleProductoModel producto,
    double cantidad,
  ) async {
    final cuentaId = cuenta.cuentaId;
    final detalleId = producto.detalleId;
    if (cuentaId == null || detalleId == null || producto.pagado == true) return null;

    try {
      final response = await _dataSource.actualizarCantidadProductoCuenta(
        cuentaId: cuentaId,
        detalleId: detalleId,
        cantidad: cantidad.clamp(0, 9999).toDouble(),
      );
      if (!mounted) return response;
      final updated = _preservarOrdenProductosVenta(_ventaActiva, response);
      setState(() {
        _ventaActiva = updated;
        _cuentaSeleccionadaId = cuentaId;
        _ventasDirectasAbiertas = <MeseroVentaModel>[
          updated,
          ..._ventasDirectasAbiertas.where((venta) => venta.ventaId != updated.ventaId),
        ];
      });
      return updated;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return null;
    }
  }

  Future<MeseroVentaModel?> _eliminarProductoVentaDirectaRapida(
    MeseroCuentaModel cuenta,
    MeseroDetalleProductoModel producto,
  ) async {
    final cuentaId = cuenta.cuentaId;
    final detalleId = producto.detalleId;
    if (cuentaId == null || detalleId == null || producto.pagado == true) return null;

    try {
      final response = await _dataSource.eliminarProductoCuenta(
        cuentaId: cuentaId,
        detalleId: detalleId,
      );
      if (!mounted) return response;
      final updated = _preservarOrdenProductosVenta(_ventaActiva, response);
      setState(() {
        _ventaActiva = updated;
        _cuentaSeleccionadaId = cuentaId;
        _ventasDirectasAbiertas = <MeseroVentaModel>[
          updated,
          ..._ventasDirectasAbiertas.where((venta) => venta.ventaId != updated.ventaId),
        ];
      });
      return updated;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return null;
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
      ref.read(meseroSelectedModeProvider.notifier).state = MeseroPageMode.mesas;
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


  Future<void> _pagarMesaDesdeTarjeta(MeseroMesaResumenModel mesa) async {
    final ventaId = mesa.ventaId;
    if (ventaId == null) return;

    setState(() => _processing = true);
    try {
      final venta = await _dataSource.consultarVenta(ventaId);
      if (!mounted) return;

      final cuentasPendientes = venta.cuentas.where((cuenta) {
        final saldo = cuenta.saldoPendiente ?? cuenta.total ?? 0;
        return !(cuenta.pagada ?? false) && saldo > 0.009;
      }).toList(growable: false);

      if (cuentasPendientes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay cuentas pendientes de pago en esta mesa.')),
        );
        return;
      }

      setState(() {
        _ventaActiva = venta;
        _mostrandoDetalleVenta = true;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = cuentasPendientes.first.cuentaId;
      });

      final cuenta = cuentasPendientes.length == 1
          ? cuentasPendientes.first
          : await _seleccionarCuentaParaPagoRapido(venta, cuentasPendientes);
      if (cuenta == null || !mounted) return;

      await _pagarCuenta(venta, cuenta);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<MeseroCuentaModel?> _seleccionarCuentaParaPagoRapido(
    MeseroVentaModel venta,
    List<MeseroCuentaModel> cuentas,
  ) async {
    final esMovil = MediaQuery.sizeOf(context).width < 700;
    if (esMovil) {
      return showModalBottomSheet<MeseroCuentaModel>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _SeleccionCuentaPagoSheet(venta: venta, cuentas: cuentas),
      );
    }

    return showDialog<MeseroCuentaModel>(
      context: context,
      builder: (context) => _SeleccionCuentaPagoDialog(venta: venta, cuentas: cuentas),
    );
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
                  decoration: BoxDecoration(
                    color: palette.surface.withOpacity(palette.darkBackground ? 0.98 : 0.995),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: palette.secondary.withOpacity(0.16)),
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
                                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
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
                        maxLength: 120,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Buscar productos',
                          hintText: 'Nombre, descripción, código o precio',
                          prefixIcon: Icon(Icons.search_rounded),
                        ).compactFilter(),
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
                                  style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary),
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

  Future<void> _eliminarPagoRegistrado(
    MeseroCuentaModel cuenta,
    MeseroPagoModel pago,
  ) async {
    final cuentaId = cuenta.cuentaId;
    final pagoId = pago.pagoId;
    if (cuentaId == null || pagoId == null || _processing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar pago registrado'),
        content: Text(
          'Se eliminará el pago de ${CurrencyUtils.format(pago.valor)} realizado con '
          '${pago.medioPagoNombre ?? 'el medio seleccionado'}.\n\n'
          'El saldo de la cuenta se recalculará automáticamente. Esta acción solo funciona mientras la venta siga abierta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar pago'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _processing = true);
    try {
      final updated = await _dataSource.eliminarPagoCuenta(cuentaId: cuentaId, pagoId: pagoId);
      final future = _load();
      setState(() {
        _ventaActiva = updated;
        _cuentaSeleccionadaId = cuentaId;
        _mostrandoDetalleVenta = true;
        _mostrandoPestanaAgregarProductos = false;
        _future = future;
      });
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago eliminado. El saldo de la cuenta fue recalculado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<bool> _pagarCuenta(
    MeseroVentaModel venta,
    MeseroCuentaModel cuenta, {
    bool mantenerVistaMesas = false,
    bool finalizarDirectaAlPagar = false,
  }) async {
    final cuentaId = cuenta.cuentaId;
    if (cuentaId == null) return false;

    if (_mediosPago.isEmpty) {
      setState(() => _processing = true);
      try {
        final medios = await _dataSource.listarMediosPago();
        if (!mounted) return false;
        setState(() => _mediosPago = medios);
      } catch (error) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    }

    if (!mounted) return false;
    if (_mediosPago.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay medios de pago activos para registrar el pago.')),
      );
      return false;
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
        : await showGeneralDialog<_PagarCuentaResult>(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Cerrar cobro',
            barrierColor: Colors.black.withOpacity(0.46),
            transitionDuration: const Duration(milliseconds: 240),
            pageBuilder: (dialogContext, animation, secondaryAnimation) {
              final width = MediaQuery.sizeOf(dialogContext).width;
              return SafeArea(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: width >= 1450 ? 820 : (width >= 1100 ? 760 : 700),
                    height: double.infinity,
                    child: _PagarCuentaDialog(
                      venta: venta,
                      cuenta: cuenta,
                      mediosPago: _mediosPago,
                    ),
                  ),
                ),
              );
            },
            transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
              return SlideTransition(
                position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
                child: FadeTransition(opacity: curved, child: child),
              );
            },
          );
    if (result == null) return false;

    setState(() => _processing = true);
    try {
      var updated = await _dataSource.registrarPagosCuenta(
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

      var finalizada = false;
      if (finalizarDirectaAlPagar &&
          _esVentaDirecta(updated) &&
          (updated.saldoPendiente ?? 0) <= 0.009 &&
          updated.ventaId != null) {
        updated = await _dataSource.finalizarVenta(updated.ventaId!);
        finalizada = true;
      }

      final future = _load();
      setState(() {
        _ventaActiva = finalizada ? null : updated;
        _mostrandoDetalleVenta = finalizada ? false : !mantenerVistaMesas;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = finalizada ? null : cuentaId;
        _future = future;
      });
      await future;
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            finalizada
                ? 'Venta directa cobrada y finalizada correctamente.'
                : 'Pago registrado para la cuenta.',
          ),
        ),
      );
      if ((updated.saldoPendiente ?? 0) <= 0.009 && updated.ventaId != null) {
        await _ofrecerOpcionesComprobante(updated);
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      return false;
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _ofrecerOpcionesComprobante(MeseroVentaModel venta) async {
    if (!mounted || venta.ventaId == null) return;
    final opcion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cobro registrado'),
        content: const Text('¿Deseas entregar un comprobante al cliente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ahora no'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, 'correo'),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Enviar correo'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'imprimir'),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir ticket'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (opcion == 'correo') {
      await _ofrecerComprobantePorCorreo(venta.ventaId!);
    } else if (opcion == 'imprimir') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _DetalleHistorialVentaPage(
            venta: venta,
            imprimirAlAbrir: true,
          ),
        ),
      );
    }
  }

  Future<void> _ofrecerComprobantePorCorreo(int ventaId) async {
    if (!mounted) return;
    final correoController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Enviar comprobante al cliente?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Es opcional. El cliente debe proporcionar su correo para recibir el resumen de la venta.'),
            const SizedBox(height: 12),
            TextField(
              controller: correoController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo del cliente'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ahora no')),
          FilledButton(onPressed: () {
            final value = correoController.text.trim();
            if (value.contains('@') && value.split('@').length == 2 && value.split('@').last.contains('.')) {
              Navigator.pop(ctx, value);
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Ingresa un correo válido')),
              );
            }
          }, child: const Text('Enviar')),
        ],
      ),
    );
    correoController.dispose();
    if (email == null || !mounted) return;
    try {
      await ref.read(apiClientProvider).post<void>(
        '/api/v1/mesero/ventas/$ventaId/comprobante/email',
        {'email': email},
        (_) => null,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobante enviado por correo')),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el correo: $error')),
      );
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
          _esVentaDirecta(venta)
              ? 'Se finalizará la venta directa #$ventaId y se conservarán sus productos y pagos en el historial.\n\nTotal: ${CurrencyUtils.format(venta.total)}'
              : 'Se finalizará la venta #$ventaId, se conservarán las cuentas y pagos en el historial y la mesa quedará disponible para nuevos clientes.\n\nTotal: ${CurrencyUtils.format(venta.total)}',
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_esVentaDirecta(venta) ? 'Venta directa finalizada correctamente.' : 'Venta finalizada y mesa liberada correctamente.')));
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

  Future<void> _mostrarSumarCantidadProducto(
    MeseroCuentaModel cuenta,
    MeseroDetalleProductoModel producto,
  ) async {
    final detalleId = producto.detalleId;
    if (detalleId == null || _detallesCantidadEnProceso.contains(detalleId)) return;

    if (producto.pagado == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto ya fue pagado y su cantidad no se puede modificar.')),
      );
      return;
    }

    final cantidadASumar = await showDialog<double>(
      context: context,
      builder: (dialogContext) => _SumarCantidadProductoDialog(producto: producto),
    );
    if (cantidadASumar == null || cantidadASumar <= 0 || !mounted) return;

    await _ajustarCantidadProductoCuenta(cuenta, producto, cantidadASumar);
  }

  Future<void> _ajustarCantidadProductoCuenta(
    MeseroCuentaModel cuenta,
    MeseroDetalleProductoModel producto,
    double diferencia,
  ) async {
    final cuentaId = cuenta.cuentaId;
    final detalleId = producto.detalleId;
    if (cuentaId == null || detalleId == null || diferencia == 0) return;
    if (_detallesCantidadEnProceso.contains(detalleId)) return;

    if (producto.pagado == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto ya fue pagado y su cantidad no se puede modificar.')),
      );
      return;
    }

    final cantidadActual = (producto.cantidad ?? 0).toDouble();
    final cantidadCalculada = cantidadActual + diferencia;
    final nuevaCantidad = cantidadCalculada <= 0 ? 0.0 : cantidadCalculada;
    final nombre = producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}';

    setState(() => _detallesCantidadEnProceso.add(detalleId));
    try {
      final updatedResponse = await _dataSource.actualizarCantidadProductoCuenta(
        cuentaId: cuentaId,
        detalleId: detalleId,
        cantidad: nuevaCantidad,
      );
      if (!mounted) return;
      final updated = _preservarOrdenProductosVenta(_ventaActiva, updatedResponse);

      setState(() {
        _ventaActiva = updated;
        _mostrandoDetalleVenta = true;
        _mostrandoPestanaAgregarProductos = false;
        _cuentaSeleccionadaId = cuentaId;
        _detallesCantidadEnProceso.remove(detalleId);
        _mesas = _mesas.map((mesa) {
          final corresponde = (updated.mesaId != null && mesa.mesaId == updated.mesaId) ||
              (updated.ventaId != null && mesa.ventaId == updated.ventaId);
          if (!corresponde) return mesa;
          return MeseroMesaResumenModel(
            mesaId: mesa.mesaId ?? updated.mesaId,
            mesaNumero: mesa.mesaNumero ?? updated.mesaNumero,
            sucursalId: mesa.sucursalId ?? updated.sucursalId,
            estadoMesa: mesa.estadoMesa,
            mesaDescripcion: updated.mesaDescripcion ?? mesa.mesaDescripcion,
            mesaFoto: updated.mesaFoto ?? mesa.mesaFoto,
            ventaId: updated.ventaId ?? mesa.ventaId,
            estadoVenta: updated.estado ?? mesa.estadoVenta,
            totalPendiente: updated.saldoPendiente,
            numeroCuentas: updated.cuentas.length,
          );
        }).toList(growable: false);
      });

      if (nuevaCantidad <= 0 || diferencia.abs() > 1.001) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevaCantidad <= 0
                  ? '$nombre retirado de la cuenta.'
                  : 'Se sumaron ${_formatCantidadGeneral(diferencia)} unidades de $nombre.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted && _detallesCantidadEnProceso.contains(detalleId)) {
        setState(() => _detallesCantidadEnProceso.remove(detalleId));
      }
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
    final prepared = (producto.tipoControl ?? '').trim().toUpperCase() == 'PREPARADO';

    if (prepared) {
      final decision = await showDialog<_PedidoProductoDecision>(
        context: context,
        builder: (context) => _PersonalizarProductoDialog(producto: producto),
      );
      if (decision == null || decision.cantidad <= 0) return;
      await _agregarProducto(
        cuentaId,
        producto,
        cantidad: decision.cantidad,
        ingredientesExcluidos: decision.ingredientesExcluidos,
        adiciones: decision.adiciones,
        observacion: decision.observacion,
      );
      return;
    }

    final cantidad = await showDialog<double>(
      context: context,
      builder: (context) => _CantidadProductoDialog(producto: producto),
    );

    if (cantidad == null || cantidad <= 0) return;
    await _agregarProducto(cuentaId, producto, cantidad: cantidad);
  }

  Future<void> _agregarProducto(
    int cuentaId,
    MeseroProductoModel producto, {
    double cantidad = 1,
    List<int> ingredientesExcluidos = const <int>[],
    List<int> adiciones = const <int>[],
    String? observacion,
  }) async {
    if (producto.prodId == null) return;
    setState(() => _processing = true);
    try {
      final venta = await _dataSource.agregarProducto(
        cuentaId: cuentaId,
        productoId: producto.prodId!,
        precioId: producto.precId,
        cantidad: cantidad,
        ingredientesExcluidos: ingredientesExcluidos,
        adiciones: adiciones,
        observacion: observacion,
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

  double _baseInicialCierreActual(CierreCajaResumenModel cierre) {
    final fecha = cierre.fecha ?? _fechaIso(_fechaCierreActual);
    return _baseInicialCierrePorFecha[fecha] ?? cierre.valorBase ?? 0;
  }

  Future<void> _registrarBaseInicialCierreCaja(CierreCajaResumenModel cierre) async {
    final fecha = cierre.fecha ?? _fechaIso(_fechaCierreActual);
    final controller = TextEditingController(text: _formatCurrencyInputAmount(_baseInicialCierreActual(cierre)));
    try {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) {
          final palette = ref.watch(selectedAppPaletteProvider);
          return AlertDialog(
            backgroundColor: palette.surface,
            title: Text('Registrar base inicial', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'La base es el dinero que recibe la caja al iniciar el turno para poder dar vueltas. Al final, esa base ya está incluida dentro del efectivo contado, por eso se resta en el cruce.',
                    style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: _currencyInputFormatters,
                    decoration: InputDecoration(
                      labelText: 'Base inicial recibida',
                      helperText: 'Ejemplo: efectivo entregado al cajero al comenzar el turno.',
                      prefixIcon: const Icon(Icons.savings_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar base'),
              ),
            ],
          );
        },
      );
      if (confirmado != true) return;
      final valorBase = _parseCurrencyInput(controller.text);
      if (!mounted) return;
      setState(() => _processing = true);
      try {
        final actualizado = await _dataSource.guardarBaseInicialCierreCaja(
          fecha: fecha,
          valorBase: valorBase,
        );
        if (!mounted) return;
        setState(() {
          _baseInicialCierrePorFecha[fecha] = actualizado.valorBase ?? valorBase;
          _cierreCajaFuture = Future<CierreCajaResumenModel>.value(actualizado);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Base inicial guardada: ${CurrencyUtils.format(actualizado.valorBase ?? valorBase)}',
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible guardar la base inicial: $error')),
        );
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _seleccionarFechaCierreCaja() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaCierreActual,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Seleccionar día de cierre',
    );
    if (picked == null) return;
    setState(() {
      _cierreCajaFechaFiltro = DateTime(picked.year, picked.month, picked.day);
      _cierreCajaFuture = _cargarCierreCaja();
    });
  }

  Future<void> _descargarReporteCierreCaja(CierreCajaResumenModel cierre) async {
    try {
      final fecha = cierre.fecha ?? _fechaIso(_fechaCierreActual);
      final bytes = await _crearPdfCierreCaja(cierre);
      final fileName = 'cierre-caja-$fecha.pdf';
      await downloadBytesFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reporte PDF generado: $fileName')));
    } catch (error) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: 'No fue posible generar el PDF. Error: $error'));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No fue posible generar el PDF. Se copió el error al portapapeles.')));
    }
  }

  Future<void> _registrarSalidaCaja(CierreCajaResumenModel cierre) async {
    try {
      final opciones = await _dataSource.opcionesSalidaCaja();
      if (!mounted) return;

      final decision = await showDialog<_SalidaCajaDecision>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(dialogContext).width < 700 ? 10 : 24,
            vertical: 18,
          ),
          clipBehavior: Clip.antiAlias,
          child: _SalidaCajaDialog(
            opciones: opciones,
            mediosPago: _mediosPago,
            palette: ref.read(selectedAppPaletteProvider),
          ),
        ),
      );

      if (decision == null || !mounted) return;

      setState(() => _processing = true);
      await _dataSource.registrarSalidaCaja(
        fecha: cierre.fecha ?? _fechaIso(_fechaCierreActual),
        tipo: decision.tipo,
        valor: decision.valor,
        categoria: decision.categoria,
        descripcion: decision.descripcion,
        gastoId: decision.gastoId,
        pedidoId: decision.pedidoId,
        medioPagoId: decision.medioPagoId,
      );
      await _reloadCierreCaja();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Salida registrada: ${CurrencyUtils.format(decision.valor)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible registrar la salida: $error')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _editarSalidaCaja(
    CierreCajaResumenModel cierre,
    SalidaCajaModel salida,
  ) async {
    final id = salida.salidaId;
    if (id == null || _processing) return;
    try {
      final opciones = await _dataSource.opcionesSalidaCaja();
      if (!mounted) return;
      final decision = await showDialog<_SalidaCajaDecision>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(dialogContext).width < 700 ? 10 : 24,
            vertical: 18,
          ),
          clipBehavior: Clip.antiAlias,
          child: _SalidaCajaDialog(
            opciones: opciones,
            mediosPago: _mediosPago,
            palette: ref.read(selectedAppPaletteProvider),
            initialSalida: salida,
          ),
        ),
      );
      if (decision == null || !mounted) return;
      setState(() => _processing = true);
      await _dataSource.actualizarSalidaCaja(
        salidaId: id,
        fecha: salida.fecha ?? cierre.fecha ?? _fechaIso(_fechaCierreActual),
        tipo: decision.tipo,
        valor: decision.valor,
        descripcion: decision.descripcion,
        categoria: decision.categoria,
        medioPagoId: decision.medioPagoId,
        gastoId: decision.gastoId,
        pedidoId: decision.pedidoId,
      );
      await _reloadCierreCaja();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Movimiento corregido. Totales y diferencias de caja actualizados.',
          )),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible modificar el movimiento: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _anularSalidaCaja(
    CierreCajaResumenModel cierre,
    SalidaCajaModel salida,
  ) async {
    final id = salida.salidaId;
    if (id == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Anular salida de caja'),
        content: Text(
          'Se anulará ${salida.descripcion ?? 'esta salida'} por '
          '${CurrencyUtils.format(salida.valor)}. '
          'Si corresponde a un pedido, el saldo pendiente se restaurará. '
          'También se recalcularán los totales del cierre y las diferencias por medio de pago, '
          'aunque el turno ya esté cerrado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Anular salida'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      setState(() => _processing = true);
      await _dataSource.anularSalidaCaja(id);
      await _reloadCierreCaja();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Salida anulada. Se recalcularon los totales y las diferencias de caja.',
          )),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible anular la salida: $error')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _registrarCierreCaja(CierreCajaResumenModel cierre) async {
    final esModificacion = cierre.cerrado == true && cierre.cierreCajaId != null;
    final controllers = <int, TextEditingController>{};
    for (final medio in cierre.mediosPago) {
      final id = medio.medioPagoId;
      if (id != null) {
        controllers[id] = TextEditingController(
          text: _formatCurrencyInputAmount(
            medio.valorEntregado ?? medio.totalSistema ?? 0,
          ),
        );
      }
    }
    final baseController = TextEditingController(
      text: _formatCurrencyInputAmount(_baseInicialCierreActual(cierre)),
    );
    final gastos = <({TextEditingController descripcion, TextEditingController valor})>[
      for (final gasto in cierre.gastos)
        (
          descripcion: TextEditingController(text: gasto.descripcion ?? ''),
          valor: TextEditingController(text: _formatCurrencyInputAmount(gasto.valor ?? 0)),
        ),
    ];
    final observacionController = TextEditingController(text: cierre.observacion ?? '');

    double totalEntregadoActual() => cierre.mediosPago.fold<double>(
          0,
          (sum, medio) {
            return sum + _parseCurrencyInput(
              controllers[medio.medioPagoId]?.text ?? '0',
            );
          },
        );
    double totalGastosActual() =>
        (cierre.totalSalidasCaja ?? 0) +
        gastos.fold<double>(
          0,
          (sum, gasto) => sum + _parseCurrencyInput(gasto.valor.text),
        );
    double baseActual() => _parseCurrencyInput(baseController.text);
    double totalCruceActual() => totalEntregadoActual() + totalGastosActual() - baseActual();
    double diferenciaActual() => totalCruceActual() - (cierre.totalVendido ?? 0);
    double salidasMedioActual(CierreCajaMedioPagoModel medio) {
      if (!_esMedioEfectivoCierre(medio.medioPagoNombre)) {
        return 0;
      }
      var total = cierre.salidasCaja
          .where(_salidaAfectaCajaFisicaCierre)
          .fold<double>(0, (sum, salida) => sum + (salida.valor ?? 0));
      total += gastos.fold<double>(
        0,
        (sum, gasto) => sum + _parseCurrencyInput(gasto.valor.text),
      );
      return total;
    }

    double diferenciaMedioActual(CierreCajaMedioPagoModel medio) {
      final entregado = _parseCurrencyInput(
        controllers[medio.medioPagoId]?.text ?? '0',
      );
      final sistema = medio.totalSistema ?? 0;
      if (_esMedioEfectivoCierre(medio.medioPagoNombre)) {
        return entregado + salidasMedioActual(medio) - baseActual() - sistema;
      }
      return entregado - sistema;
    }

    final palette = ref.read(selectedAppPaletteProvider);

    Widget buildConteoSurface(
      BuildContext overlayContext,
      StateSetter setDialogState, {
      required bool mobileSheet,
      ScrollController? scrollController,
    }) {
      final size = MediaQuery.sizeOf(overlayContext);
      final keyboardInset = MediaQuery.viewInsetsOf(overlayContext).bottom;
      final keyboardVisible = keyboardInset > 0;
      final compact = mobileSheet || size.width < 760;
      final diferencia = diferenciaActual();
      final diferenciaColor = diferencia.abs() < 0.01 ? AppColors.success : AppColors.danger;

      Widget sectionCard({
        required IconData icon,
        required String title,
        required String subtitle,
        required Widget child,
        Widget? trailing,
      }) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.72),
            borderRadius: BorderRadius.circular(compact ? 18 : 22),
            border: Border.all(color: palette.secondary.withOpacity(0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 38 : 42,
                    height: compact ? 38 : 42,
                    decoration: BoxDecoration(
                      color: palette.secondary.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(compact ? 12 : 14),
                    ),
                    child: Icon(icon, color: palette.secondary, size: compact ? 19 : 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: compact ? 15 : 16)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 6), trailing],
                ],
              ),
              SizedBox(height: compact ? 12 : 14),
              child,
            ],
          ),
        );
      }

      Widget medioCard(CierreCajaMedioPagoModel medio) {
        final diferenciaMedio = diferenciaMedioActual(medio);
        final cuadrado = diferenciaMedio.abs() < 0.01;
        final statusColor = cuadrado ? AppColors.success : AppColors.danger;
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.78 : 0.96),
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
            border: Border.all(color: cuadrado ? palette.cardBorder : statusColor.withOpacity(0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _esMedioEfectivoCierre(medio.medioPagoNombre)
                          ? Icons.payments_rounded
                          : Icons.account_balance_wallet_rounded,
                      color: palette.secondary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medio.medioPagoNombre ?? 'Medio ${medio.medioPagoId ?? '-'}',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sistema: ${CurrencyUtils.format(medio.totalSistema)}',
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withOpacity(0.24)),
                    ),
                    child: Text(
                      cuadrado ? 'Cuadrado' : CurrencyUtils.format(diferenciaMedio),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controllers[medio.medioPagoId],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                inputFormatters: _currencyInputFormatters,
                onChanged: (_) => setDialogState(() {}),
                decoration: InputDecoration(
                  labelText: _esMedioEfectivoCierre(medio.medioPagoNombre)
                      ? 'Efectivo contado'
                      : 'Valor recibido por ${medio.medioPagoNombre ?? 'giro electrónico'}',
                  helperText: _esMedioEfectivoCierre(medio.medioPagoNombre)
                      ? 'Incluye la base inicial y el efectivo físico que quedó en caja.'
                      : 'Registra lo realmente recibido por este medio. '
                        'La diferencia se calcula aparte del efectivo físico.',
                  prefixIcon: const Icon(Icons.edit_rounded),
                  isDense: compact,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                ),
            ],
          ),
        );
      }

      final mediosSection = sectionCard(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Conteo por medio',
        subtitle:
            'Puedes corregir el efectivo y los valores recibidos por Nequi, Daviplata y otros giros. La base inicial solo afecta el efectivo.',
        child: cierre.mediosPago.isEmpty
            ? Text('No hay medios de pago registrados para este día.', style: TextStyle(color: palette.textSecondary))
            : Column(children: cierre.mediosPago.map(medioCard).toList(growable: false)),
      );

      final ajustesSection = sectionCard(
        icon: Icons.tune_rounded,
        title: 'Base y observación',
        subtitle: cierre.salidasCaja.isEmpty
            ? 'Los pagos y salidas se registran desde el panel del turno.'
            : '${cierre.salidasCaja.length} salida(s) de caja ya incluidas automáticamente.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: baseController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              inputFormatters: _currencyInputFormatters,
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: 'Base inicial',
                prefixIcon: const Icon(Icons.savings_rounded),
                isDense: compact,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < gastos.length; i++) ...[
              Builder(
                key: ObjectKey(gastos[i].descripcion),
                builder: (context) {
                  final gasto = gastos[i];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.70),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.cardBorder),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final description = TextField(
                          controller: gasto.descripcion,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          maxLength: 300,
                          inputFormatters: [LengthLimitingTextInputFormatter(300)],
                          decoration: InputDecoration(
                            labelText: 'Descripción del gasto',
                            hintText: 'Ej. hielo o transporte',
                            counterText: '',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        final value = TextField(
                          controller: gasto.valor,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          inputFormatters: _currencyInputFormatters,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Valor',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        final remove = IconButton.filledTonal(
                          onPressed: () {
                            setDialogState(() {
                              gastos.remove(gasto);
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              gasto.descripcion.dispose();
                              gasto.valor.dispose();
                            });
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        );
                        if (constraints.maxWidth < 460) {
                          return Column(
                            children: [
                              description,
                              const SizedBox(height: 8),
                              Row(children: [Expanded(child: value), const SizedBox(width: 8), remove]),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 3, child: description),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: value),
                            const SizedBox(width: 8),
                            remove,
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 4),
            TextField(
              controller: observacionController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              minLines: 2,
              maxLines: 3,
              maxLength: 500,
              inputFormatters: [LengthLimitingTextInputFormatter(500)],
              decoration: InputDecoration(
                labelText: 'Nota del cierre (opcional)',
                counterText: '',
                prefixIcon: const Icon(Icons.notes_rounded),
                isDense: compact,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );

      Widget summaryContent(double width) {
        final values = [
          _CierreFooterValue(label: 'Sistema', value: CurrencyUtils.format(cierre.totalVendido), emphasized: true),
          _CierreFooterValue(label: 'Cruce', value: CurrencyUtils.format(totalCruceActual()), emphasized: true),
          _CierreFooterValue(label: 'Diferencia', value: CurrencyUtils.format(diferencia), valueColor: diferenciaColor, emphasized: true),
        ];
        if (mobileSheet && width >= 350) {
          return Row(
            children: [
              for (var i = 0; i < values.length; i++) ...[
                Expanded(child: values[i]),
                if (i != values.length - 1) const SizedBox(width: 8),
              ],
            ],
          );
        }
        return Wrap(spacing: 18, runSpacing: 8, children: values);
      }

      final content = Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: mobileSheet
              ? const BorderRadius.vertical(top: Radius.circular(28))
              : BorderRadius.circular(28),
          border: Border.all(color: palette.secondary.withOpacity(0.18)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.32), blurRadius: 34, offset: const Offset(0, 18))],
        ),
        child: Column(
          children: [
            if (mobileSheet) ...[
              const SizedBox(height: 9),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: palette.textSecondary.withOpacity(0.34), borderRadius: BorderRadius.circular(999)),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 15 : 22, mobileSheet ? 10 : 18, compact ? 10 : 16, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: compact ? 44 : 48,
                    height: compact ? 44 : 48,
                    decoration: BoxDecoration(
                      color: palette.secondary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.point_of_sale_rounded, color: palette.secondary, size: compact ? 23 : 25),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esModificacion ? 'Editar conteo' : 'Contar y cerrar caja',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: compact ? 19 : 23),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_formatFechaCierre(cierre.fecha ?? _fechaIso(_fechaCierreActual))} · ${cierre.ventasIncluidas ?? cierre.ventas.length} ventas',
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: compact ? 12 : 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(overlayContext, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.cardBorder),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.all(compact ? 12 : 18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (mobileSheet || constraints.maxWidth < 820) {
                      return Column(
                        children: [
                          mediosSection,
                          const SizedBox(height: 11),
                          ajustesSection,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: mediosSection),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: ajustesSection),
                      ],
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 11, compact ? 12 : 20, mobileSheet ? 10 : 14),
              decoration: BoxDecoration(
                color: palette.background.withOpacity(palette.darkBackground ? 0.58 : 0.80),
                border: Border(top: BorderSide(color: palette.cardBorder)),
                borderRadius: mobileSheet ? BorderRadius.zero : const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (mobileSheet) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (keyboardVisible) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Teclado activo',
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                                  icon: const Icon(Icons.keyboard_hide_rounded, size: 18),
                                  label: const Text('Listo'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          summaryContent(constraints.maxWidth),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(overlayContext, false),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    Navigator.pop(overlayContext, true);
                                  },
                                  icon: Icon(esModificacion ? Icons.save_rounded : Icons.lock_rounded),
                                  label: Text(esModificacion ? 'Guardar cambios' : 'Confirmar cierre'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    final actions = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(overlayContext, false), child: const Text('Cancelar')),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(overlayContext, true),
                          icon: Icon(esModificacion ? Icons.save_rounded : Icons.lock_rounded),
                          label: Text(esModificacion ? 'Guardar cambios' : 'Confirmar cierre'),
                        ),
                      ],
                    );
                    return Row(
                      children: [
                        Expanded(child: summaryContent(constraints.maxWidth)),
                        const SizedBox(width: 12),
                        actions,
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );

      if (mobileSheet) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: content,
        );
      }
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1080, maxHeight: size.height - 36),
        child: content,
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final bool? confirmado;
    if (isMobile) {
      confirmado = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.58),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final keyboardInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: keyboardInset > 0 ? 1.0 : 0.94,
                  minChildSize: keyboardInset > 0 ? 0.86 : 0.72,
                  maxChildSize: 1.0,
                  builder: (context, scrollController) {
                    return buildConteoSurface(
                      sheetContext,
                      setDialogState,
                      mobileSheet: true,
                      scrollController: scrollController,
                    );
                  },
                ),
              );
            },
          );
        },
      );
    } else {
      confirmado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
                backgroundColor: Colors.transparent,
                child: buildConteoSurface(dialogContext, setDialogState, mobileSheet: false),
              );
            },
          );
        },
      );
    }

    Future<void> disposeEditors() async {
      // La ruta todavía puede conservar widgets durante la animación de cierre.
      // Esperar evita que un TextField intente usar un controlador ya liberado.
      await Future<void>.delayed(const Duration(milliseconds: 320));
      for (final controller in controllers.values) {
        controller.dispose();
      }
      baseController.dispose();
      observacionController.dispose();
      for (final gasto in gastos) {
        gasto.descripcion.dispose();
        gasto.valor.dispose();
      }
    }

    if (confirmado != true) {
      await disposeEditors();
      return;
    }

    final medios = cierre.mediosPago
        .where(
          (medio) => medio.medioPagoId != null,
        )
        .map((medio) => {
              'medioPagoId': medio.medioPagoId,
              'valorEntregado': _parseCurrencyInput(
                controllers[medio.medioPagoId]?.text ?? '0',
              ),
            })
        .toList(growable: false);
    final gastosRequest = gastos
        .map((gasto) => {
              'descripcion': gasto.descripcion.text.trim(),
              'valor': _parseCurrencyInput(gasto.valor.text),
            })
        .where((gasto) => (gasto['descripcion']?.toString().trim().isNotEmpty ?? false) || ((gasto['valor'] as num?) ?? 0) > 0)
        .toList(growable: false);
    final valorBase = _parseCurrencyInput(baseController.text);
    final observacion = observacionController.text;
    await disposeEditors();

    if (!mounted) return;
    setState(() => _processing = true);
    try {
      if (esModificacion) {
        await _dataSource.actualizarCierreCaja(
          cierreCajaId: cierre.cierreCajaId!,
          fecha: cierre.fecha ?? _fechaIso(_fechaCierreActual),
          mediosPago: medios,
          valorBase: valorBase,
          gastos: gastosRequest,
          observacion: observacion,
        );
      } else {
        await _dataSource.registrarCierreCaja(
          fecha: cierre.fecha ?? _fechaIso(_fechaCierreActual),
          mediosPago: medios,
          valorBase: valorBase,
          gastos: gastosRequest,
          observacion: observacion,
        );
      }
      await _reloadCierreCaja();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(esModificacion ? 'Cierre de caja modificado correctamente.' : 'Cierre de caja registrado correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Widget _buildCierreCaja() {
    _cierreCajaFuture ??= _cargarCierreCaja();
    return FutureBuilder<CierreCajaResumenModel>(
      future: _cierreCajaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoader(message: 'Calculando cierre de caja...');
        }
        if (snapshot.hasError) {
          return AppErrorView(message: snapshot.error.toString(), onRetry: _reloadCierreCaja);
        }

        final cierre = snapshot.data ?? const CierreCajaResumenModel();
        final cerrado = cierre.cerrado == true;
        final valorBase = _baseInicialCierreActual(cierre);
        final totalVendido = cierre.totalVendido ?? 0;
        final totalEntregado = cierre.totalEntregado ?? 0;
        final totalGastos = cierre.totalGastos ?? 0;
        final totalCruce = cierre.totalCruce ?? (totalEntregado + totalGastos - valorBase);
        final diferencia = cierre.diferencia ?? (totalCruce - totalVendido);
        final unidadesVendidas = cierre.productos.fold<double>(0, (sum, item) => sum + (item.cantidad ?? 0));
        final puedeCerrar = !_processing && (cerrado || cierre.ventas.isNotEmpty);

        final header = _CierrePosHeader(
          fecha: _formatFechaCierre(cierre.fecha ?? _fechaIso(_fechaCierreActual)),
          cerrado: cerrado,
          ventas: cierre.ventasIncluidas ?? cierre.ventas.length,
          unidades: unidadesVendidas,
          totalVendido: totalVendido,
          diferencia: diferencia,
          onCambiarDia: _seleccionarFechaCierreCaja,
          onActualizar: _reloadCierreCaja,
          onPdf: () => _descargarReporteCierreCaja(cierre),
          onCerrar: puedeCerrar ? () => _registrarCierreCaja(cierre) : null,
        );

        final medios = _CierrePosMediosPanel(cierre: cierre);
        final resumen = _CierrePosResumenPanel(
          cerrado: cerrado,
          totalVendido: totalVendido,
          totalEntregado: totalEntregado,
          totalCruce: totalCruce,
          diferencia: diferencia,
          valorBase: valorBase,
          totalGastos: totalGastos,
          propinas: cierre.totalPropinas ?? 0,
          gastosRegistrados: cierre.gastos.length + cierre.salidasCaja.length,
          onEditarBase: cerrado ? null : () => _registrarBaseInicialCierreCaja(cierre),
          onCerrar: puedeCerrar ? () => _registrarCierreCaja(cierre) : null,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 960) {
                  return Column(
                    children: [
                      medios,
                      const SizedBox(height: 14),
                      resumen,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: medios),
                    const SizedBox(width: 16),
                    SizedBox(width: 370, child: resumen),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _CierrePosMovimientosPanel(
              valorBase: valorBase,
              totalSalidas: totalGastos,
              totalGastosTurno: cierre.totalGastosTurno ?? 0,
              totalPagosPedidos: cierre.totalPagosPedidos ?? 0,
              totalPagosGastos: cierre.totalPagosGastosConfigurados ?? 0,
              salidas: cierre.salidasCaja,
              gastosLegacy: cierre.gastos,
              cerrado: cerrado,
              onEditarBase: cerrado
                  ? null
                  : () => _registrarBaseInicialCierreCaja(cierre),
              onRegistrarSalida: _processing
                  ? null
                  : () => _registrarSalidaCaja(cierre),
              onEditarSalida: _processing
                  ? null
                  : (salida) => _editarSalidaCaja(cierre, salida),
              onAnularSalida: _processing
                  ? null
                  : (salida) => _anularSalidaCaja(cierre, salida),
              onEditarGastos: _processing
                  ? null
                  : () => _registrarCierreCaja(cierre),
            ),
            const SizedBox(height: 14),
            _CierreCollapsibleSection(
              icon: Icons.inventory_2_rounded,
              title: 'Productos del turno',
              summary: '${cierre.productos.length} referencias · ${_formatCantidadGeneral(unidadesVendidas)} unidades',
              initiallyExpanded: false,
              child: _CierreProductosTable(items: cierre.productos),
            ),
            const SizedBox(height: 12),
            _CierreCollapsibleSection(
              icon: Icons.receipt_long_rounded,
              title: 'Ventas del turno',
              summary: '${cierre.ventas.length} ventas incluidas',
              initiallyExpanded: false,
              child: _CierreVentasTable(items: cierre.ventas),
            ),
            if ((cierre.observacion ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _CierreSection(
                icon: Icons.notes_rounded,
                title: 'Nota del cierre',
                subtitle: 'Observación registrada en el turno.',
                child: Text(cierre.observacion!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SalidaCajaDecision {
  const _SalidaCajaDecision({
    required this.tipo,
    required this.valor,
    this.categoria,
    this.descripcion,
    this.gastoId,
    this.pedidoId,
    this.medioPagoId,
  });

  final String tipo;
  final double valor;
  final String? categoria;
  final String? descripcion;
  final int? gastoId;
  final int? pedidoId;
  final int? medioPagoId;
}

class _SalidaCajaDialog extends StatefulWidget {
  const _SalidaCajaDialog({
    required this.opciones,
    required this.mediosPago,
    required this.palette,
    this.initialSalida,
  });

  final SalidaCajaOpcionesModel opciones;
  final List<MeseroMedioPagoModel> mediosPago;
  final AppPalette palette;
  final SalidaCajaModel? initialSalida;

  @override
  State<_SalidaCajaDialog> createState() => _SalidaCajaDialogState();
}

class _SalidaCajaDialogState extends State<_SalidaCajaDialog> {
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  String _tipo = 'GASTO_TURNO';
  String _categoria = 'ASEO';
  int? _gastoId;
  int? _pedidoId;
  int? _medioPagoId;

  static const List<String> _categorias = <String>[
    'ASEO',
    'INSUMOS',
    'TRANSPORTE',
    'MANTENIMIENTO',
    'EMERGENCIA',
    'OTROS',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSalida;
    if (initial != null) {
      _tipo = initial.tipo ?? 'GASTO_TURNO';
      _categoria = initial.categoria ?? 'OTROS';
      _gastoId = initial.gastoId;
      _pedidoId = initial.pedidoId;
      _valorController.text = _formatCurrencyInputAmount(initial.valor ?? 0);
      _descripcionController.text = initial.descripcion ?? '';
      for (final medio in widget.mediosPago) {
        if ((medio.nombre ?? '').trim().toLowerCase() ==
            (initial.medioPagoNombre ?? '').trim().toLowerCase()) {
          _medioPagoId = medio.medioPagoId;
          break;
        }
      }
    }
    final disponibles = widget.mediosPago
        .where((medio) => medio.medioPagoId != null)
        .toList(growable: false);
    _medioPagoId ??= disponibles.length == 1 ? disponibles.first.medioPagoId : null;
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  double get _valor => _parseCurrencyInput(_valorController.text);

  SalidaCajaPedidoOpcionModel? get _pedido {
    for (final item in widget.opciones.pedidosPendientes) {
      if (item.id == _pedidoId) return item;
    }
    if (_pedidoId != null && _pedidoId == widget.initialSalida?.pedidoId) {
      return SalidaCajaPedidoOpcionModel(
        id: _pedidoId!,
        saldoPendiente: 0,
      );
    }
    return null;
  }

  SalidaCajaGastoOpcionModel? get _gasto {
    for (final item in widget.opciones.gastosConfigurados) {
      if (item.id == _gastoId) return item;
    }
    return null;
  }

  MeseroMedioPagoModel? get _medioPago =>
      _medioPagoById(widget.mediosPago, _medioPagoId);

  bool get _canSubmit {
    if (_valor <= 0) return false;
    if (_tipo == 'PAGO_GASTO') {
      return _gastoId != null && _medioPagoId != null;
    }
    if (_tipo == 'PAGO_PEDIDO') {
      final pedido = _pedido;
      final saldoEditable = (pedido?.saldoPendiente ?? 0) +
          (_pedidoId == widget.initialSalida?.pedidoId
              ? (widget.initialSalida?.valor ?? 0)
              : 0);
      return _medioPagoId != null &&
          (pedido != null
              ? _valor <= saldoEditable + .01
              : _descripcionController.text.trim().isNotEmpty);
    }
    return _descripcionController.text.trim().isNotEmpty;
  }

  void _changeType(String tipo) {
    setState(() {
      _tipo = tipo;
      _gastoId = null;
      _pedidoId = null;
      _valorController.clear();
      _descripcionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 700;
    final dialogWidth = mobile ? size.width - 20 : 680.0;
    final dialogHeight = mobile
        ? size.height - 20
        : (size.height - 48 < 720 ? size.height - 48 : 720.0);

    return SizedBox(
      width: dialogWidth,
      height: dialogHeight,
      child: Material(
        color: palette.surface,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(mobile ? 14 : 18, 14, 8, 12),
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(.055),
                border: Border(
                  bottom: BorderSide(color: palette.cardBorder.withOpacity(.55)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.secondary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.outbox_rounded, color: palette.secondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialSalida == null ? 'Registrar pago o salida' : 'Corregir gasto o pago',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: mobile ? 16 : 18,
                          ),
                        ),
                        Text(
                          'Solo el efectivo afecta el cierre; los giros electrónicos quedan como registro financiero.',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(mobile ? 12 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SalidaTipoOption(
                      selected: _tipo == 'GASTO_TURNO',
                      icon: Icons.shopping_bag_outlined,
                      title: 'Gasto del turno',
                      subtitle: 'Aseo, bolsas, transporte o compras menores.',
                      palette: palette,
                      onTap: () => _changeType('GASTO_TURNO'),
                    ),
                    const SizedBox(height: 8),
                    _SalidaTipoOption(
                      selected: _tipo == 'PAGO_GASTO',
                      icon: Icons.receipt_long_outlined,
                      title: 'Pago de factura o gasto',
                      subtitle: 'Ya existe en Costos fijos/variables.',
                      palette: palette,
                      onTap: () => _changeType('PAGO_GASTO'),
                    ),
                    const SizedBox(height: 8),
                    _SalidaTipoOption(
                      selected: _tipo == 'PAGO_PEDIDO',
                      icon: Icons.local_shipping_outlined,
                      title: 'Pago de pedido',
                      subtitle: 'Abono o pago de un pedido de compra.',
                      palette: palette,
                      onTap: () => _changeType('PAGO_PEDIDO'),
                    ),
                    const SizedBox(height: 16),
                    _buildFields(palette),
                    const SizedBox(height: 14),
                    _buildImpact(palette),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                mobile ? 12 : 18,
                10,
                mobile ? 12 : 18,
                mobile ? 12 : 14,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.cardBorder.withOpacity(.55)),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _canSubmit ? _submit : null,
                    icon: const Icon(Icons.outbox_rounded),
                    label: Text(
                      widget.initialSalida != null ? 'Guardar cambios' : (_valor > 0
                          ? 'Registrar ' + CurrencyUtils.format(_valor)
                          : 'Registrar movimiento'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFields(AppPalette palette) {
    Widget amountField() => TextField(
          controller: _valorController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _currencyInputFormatters,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _tipo == 'PAGO_PEDIDO' || _tipo == 'PAGO_GASTO'
                ? 'Valor del pago'
                : 'Valor que salió de caja',
            prefixIcon: const Icon(Icons.payments_outlined),
            suffixText: 'COP',
            helperText: _tipo == 'PAGO_PEDIDO' && _pedido != null
                ? 'Máximo: ' + CurrencyUtils.format(_pedido!.saldoPendiente + (_pedidoId == widget.initialSalida?.pedidoId ? (widget.initialSalida?.valor ?? 0) : 0))
                : null,
          ),
        );

    if (_tipo == 'PAGO_PEDIDO') {
      return Column(
        children: [
          DropdownButtonFormField<int>(
            value: _pedidoId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Pedido registrado (opcional)',
              helperText: 'Si la compra fue fuera de BarLytics, deja el pedido sin seleccionar.',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('Sin pedido asociado · compra externa'),
              ),
              if (_pedidoId != null && !widget.opciones.pedidosPendientes.any((p) => p.id == _pedidoId))
                DropdownMenuItem<int>(
                  value: _pedidoId,
                  child: Text('Pedido #$_pedidoId · asociado a este pago'),
                ),
              ...widget.opciones.pedidosPendientes.map(
                  (item) => DropdownMenuItem<int>(
                    value: item.id,
                    child: Text(
                      'Pedido #' +
                          item.id.toString() +
                          ' · saldo ' +
                          CurrencyUtils.format(item.saldoPendiente),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _pedidoId = value;
                final pedido = _pedido;
                if (pedido != null) {
                  _valorController.text =
                      _formatCurrencyInputAmount(pedido.saldoPendiente);
                }
              });
            },
          ),
          if (_pedido != null) ...[
            const SizedBox(height: 10),
            _SalidaPedidoResumen(pedido: _pedido!, palette: palette),
          ],
          if (_pedidoId == null) ...[
            const SizedBox(height: 12),
            Text(
              'Pedido externo: registra el valor, el medio de pago y una descripción. No se modificará el inventario ni se asociará a un pedido del sistema.',
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _medioPagoId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Medio con el que se pagó',
              prefixIcon: Icon(
                _medioPago == null
                    ? Icons.account_balance_wallet_outlined
                    : _iconoMedioPago(_medioPago!),
              ),
              helperText:
                  'Efectivo, Nequi, Daviplata, transferencia u otro medio activo.',
            ),
            items: (widget.mediosPago
                      .where((medio) => medio.medioPagoId != null)
                      .toList(growable: false)
                    ..sort((a, b) {
                      final prioridad =
                          _prioridadMedioPago(a).compareTo(_prioridadMedioPago(b));
                      if (prioridad != 0) return prioridad;
                      return (a.nombre ?? '').compareTo(b.nombre ?? '');
                    }))
                .map(
                  (medio) => DropdownMenuItem<int>(
                    value: medio.medioPagoId,
                    child: Row(
                      children: [
                        Icon(_iconoMedioPago(medio), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            medio.nombre ?? 'Medio ${medio.medioPagoId}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _medioPagoId = value),
          ),
          const SizedBox(height: 12),
          amountField(),
          const SizedBox(height: 12),
          TextField(
            controller: _descripcionController,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _pedidoId == null ? 'Descripción del pedido externo *' : 'Nota opcional',
              hintText: 'Ej. Compra de bebidas al proveedor',
              counterText: '',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ],
      );
    }

    if (_tipo == 'PAGO_GASTO') {
      return Column(
        children: [
          DropdownButtonFormField<int>(
            value: _gastoId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Factura o gasto configurado',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
            items: widget.opciones.gastosConfigurados
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.id,
                    child: Text(
                      item.nombre + ' · ' + (item.tipo ?? 'Gasto'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _gastoId = value;
                final gasto = _gasto;
                if (gasto?.valorConfigurado != null) {
                  _valorController.text =
                      _formatCurrencyInputAmount(gasto!.valorConfigurado!);
                }
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _medioPagoId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Medio con el que se pagó',
              prefixIcon: Icon(
                _medioPago == null
                    ? Icons.account_balance_wallet_outlined
                    : _iconoMedioPago(_medioPago!),
              ),
              helperText:
                  'Si es Nequi, Daviplata o transferencia, no afecta el efectivo del cierre.',
            ),
            items: (widget.mediosPago
                      .where((medio) => medio.medioPagoId != null)
                      .toList(growable: false)
                    ..sort((a, b) {
                      final prioridad =
                          _prioridadMedioPago(a).compareTo(_prioridadMedioPago(b));
                      if (prioridad != 0) return prioridad;
                      return (a.nombre ?? '').compareTo(b.nombre ?? '');
                    }))
                .map(
                  (medio) => DropdownMenuItem<int>(
                    value: medio.medioPagoId,
                    child: Row(
                      children: [
                        Icon(_iconoMedioPago(medio), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            medio.nombre ?? 'Medio ${medio.medioPagoId}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) => setState(() => _medioPagoId = value),
          ),
          const SizedBox(height: 12),
          amountField(),
          const SizedBox(height: 12),
          TextField(
            controller: _descripcionController,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Referencia opcional',
              hintText: 'Ej. Factura energía septiembre',
              counterText: '',
              prefixIcon: Icon(Icons.tag_rounded),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _categoria,
          decoration: const InputDecoration(
            labelText: 'Categoría',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: _categorias
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(_labelCategoriaSalida(value)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _categoria = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descripcionController,
          maxLength: 300,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '¿Qué se compró o pagó?',
            hintText: 'Ej. Papel higiénico para baños',
            counterText: '',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
        ),
        const SizedBox(height: 12),
        amountField(),
      ],
    );
  }

  Widget _buildImpact(AppPalette palette) {
    final affects = _tipo == 'GASTO_TURNO' ||
        ((_tipo == 'PAGO_PEDIDO' || _tipo == 'PAGO_GASTO') &&
            _esMedioPagoEfectivo(_medioPago));
    final medio = _medioPago;
    final text = _tipo == 'PAGO_PEDIDO'
        ? medio == null
            ? 'Selecciona cómo se pagó el pedido.'
            : _pedidoId == null
                ? _esMedioPagoEfectivo(medio)
                    ? 'Pedido externo: el efectivo sí afecta el cruce de caja. No se asocia a pedidos ni inventario del sistema.'
                    : 'Pedido externo: el pago por ${medio.nombre ?? 'giro electrónico'} queda registrado sin alterar efectivo, inventario ni saldos de pedidos internos.'
                : _esMedioPagoEfectivo(medio)
                    ? 'Reduce el saldo del pedido y sí afecta el efectivo que debe cuadrar la cajera.'
                    : 'Reduce el saldo del pedido, pero el pago por ${medio.nombre ?? 'giro electrónico'} no modifica el cierre de efectivo.'
        : _tipo == 'PAGO_GASTO'
            ? medio == null
                ? 'Selecciona cómo se pagó la factura o gasto.'
                : _esMedioPagoEfectivo(medio)
                    ? 'Registra el pago y sí afecta el efectivo del turno.'
                    : 'Registra el pago por ${medio.nombre ?? 'giro electrónico'}, pero no modifica el efectivo del cierre.'
            : 'Descuenta efectivo y se suma a gastos variables del periodo.';
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: (affects ? palette.warning : palette.secondary).withOpacity(.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: (affects ? palette.warning : palette.secondary).withOpacity(.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            affects ? Icons.trending_down_rounded : Icons.link_rounded,
            color: affects ? palette.warning : palette.secondary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    Navigator.pop(
      context,
      _SalidaCajaDecision(
        tipo: _tipo,
        valor: _valor,
        categoria: _tipo == 'GASTO_TURNO' ? _categoria : null,
        descripcion: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
        gastoId: _tipo == 'PAGO_GASTO' ? _gastoId : null,
        pedidoId: _tipo == 'PAGO_PEDIDO' ? _pedidoId : null,
        medioPagoId:
            _tipo == 'PAGO_PEDIDO' || _tipo == 'PAGO_GASTO'
                ? _medioPagoId
                : null,
      ),
    );
  }
}

class _SalidaTipoOption extends StatelessWidget {
  const _SalidaTipoOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected
            ? palette.secondary.withOpacity(.10)
            : palette.background.withOpacity(.28),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected
                    ? palette.secondary.withOpacity(.35)
                    : palette.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? palette.secondary : palette.textSecondary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
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

class _SalidaPedidoResumen extends StatelessWidget {
  const _SalidaPedidoResumen({
    required this.pedido,
    required this.palette,
  });

  final SalidaCajaPedidoOpcionModel pedido;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: palette.secondary.withOpacity(.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.secondary.withOpacity(.16)),
        ),
        child: Wrap(
          spacing: 18,
          runSpacing: 7,
          children: [
            Text(
              'Total ' + CurrencyUtils.format(pedido.total),
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
            Text(
              'Pagado ' + CurrencyUtils.format(pedido.pagado),
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
            Text(
              'Pendiente ' + CurrencyUtils.format(pedido.saldoPendiente),
              style: TextStyle(
                color: palette.secondary,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
}

String _labelCategoriaSalida(String value) => switch (value) {
      'ASEO' => 'Aseo',
      'INSUMOS' => 'Insumos',
      'TRANSPORTE' => 'Transporte',
      'MANTENIMIENTO' => 'Mantenimiento',
      'EMERGENCIA' => 'Emergencia',
      _ => 'Otros',
    };

class _CierrePosHeader extends ConsumerWidget {
  const _CierrePosHeader({
    required this.fecha,
    required this.cerrado,
    required this.ventas,
    required this.unidades,
    required this.totalVendido,
    required this.diferencia,
    required this.onCambiarDia,
    required this.onActualizar,
    required this.onPdf,
    this.onCerrar,
  });

  final String fecha;
  final bool cerrado;
  final int ventas;
  final double unidades;
  final double totalVendido;
  final double diferencia;
  final VoidCallback onCambiarDia;
  final VoidCallback onActualizar;
  final VoidCallback onPdf;
  final VoidCallback? onCerrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final cuadrado = diferencia.abs() < 0.01;
    final statusColor = cuadrado ? AppColors.success : AppColors.danger;

    Widget actions(bool compact) => Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: onCambiarDia,
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(compact ? 'Día' : 'Cambiar día'),
            ),
            IconButton.filledTonal(
              tooltip: 'Actualizar',
              onPressed: onActualizar,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton.filledTonal(
              tooltip: 'Descargar PDF',
              onPressed: onPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
            ),
            FilledButton.icon(
              onPressed: onCerrar,
              icon: Icon(cerrado ? Icons.edit_note_rounded : Icons.point_of_sale_rounded),
              label: Text(cerrado ? 'Editar cierre' : 'Contar caja'),
            ),
          ],
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.99),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.secondary.withOpacity(0.16)),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.point_of_sale_rounded, color: palette.secondary, size: 27),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Cierre de caja',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: compact ? 20 : 24),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: (cerrado ? AppColors.success : palette.secondary).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: (cerrado ? AppColors.success : palette.secondary).withOpacity(0.24)),
                          ),
                          child: Text(
                            cerrado ? 'Cerrado' : 'Pendiente',
                            style: TextStyle(color: cerrado ? AppColors.success : palette.secondary, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$fecha · $ventas ventas · ${_formatCantidadGeneral(unidades)} unidades',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          );

          final totals = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Vendido', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(CurrencyUtils.format(totalVendido), style: TextStyle(color: palette.secondary, fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(width: 14),
                Container(width: 1, height: 34, color: palette.cardBorder),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(cuadrado ? 'Estado' : 'Diferencia', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      cuadrado ? 'Cuadrada' : CurrencyUtils.format(diferencia),
                      style: TextStyle(color: statusColor, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 14),
                totals,
                const SizedBox(height: 12),
                actions(true),
              ],
            );
          }

          return Column(
            children: [
              Row(children: [Expanded(child: identity), const SizedBox(width: 18), totals]),
              const SizedBox(height: 14),
              Divider(height: 1, color: palette.cardBorder),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: actions(false)),
            ],
          );
        },
      ),
    );
  }
}

class _CierrePosMediosPanel extends ConsumerWidget {
  const _CierrePosMediosPanel({required this.cierre});

  final CierreCajaResumenModel cierre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final items = cierre.mediosPago;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.99),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.account_balance_wallet_rounded, color: palette.secondary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Medios de pago', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text('Sistema frente al valor contado.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('No hay pagos registrados para este día.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))),
            )
          else
            for (var i = 0; i < items.length; i++)
              _CierrePosMedioRow(
                cierre: cierre,
                item: items[i],
                last: i == items.length - 1,
              ),
        ],
      ),
    );
  }
}

class _CierrePosMedioRow extends ConsumerWidget {
  const _CierrePosMedioRow({required this.cierre, required this.item, required this.last});

  final CierreCajaResumenModel cierre;
  final CierreCajaMedioPagoModel item;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final diferencia = _diferenciaMedioCierreAjustada(cierre, item);
    final cuadrado = diferencia.abs() < 0.01;
    final statusColor = cuadrado ? AppColors.success : AppColors.danger;
    final contado = item.valorEntregado ?? item.totalSistema ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final identity = Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: palette.background.withOpacity(0.56), borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  _esMedioEfectivoCierre(item.medioPagoNombre) ? Icons.payments_rounded : Icons.account_balance_rounded,
                  color: palette.secondary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.medioPagoNombre ?? 'Medio ${item.medioPagoId ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          );
          final values = Row(
            children: [
              Expanded(child: _CierrePosMiniValue(label: 'Sistema', value: CurrencyUtils.format(item.totalSistema))),
              const SizedBox(width: 8),
              Expanded(
                child: _CierrePosMiniValue(
                  label: _esMedioEfectivoCierre(item.medioPagoNombre)
                      ? 'Contado'
                      : 'Automático',
                  value: CurrencyUtils.format(contado),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CierrePosMiniValue(
                  label: cuadrado ? 'Estado' : 'Diferencia',
                  value: cuadrado ? 'Cuadrado' : CurrencyUtils.format(diferencia),
                  valueColor: statusColor,
                ),
              ),
            ],
          );
          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, const SizedBox(height: 10), values]);
          }
          return Row(children: [SizedBox(width: 210, child: identity), const SizedBox(width: 14), Expanded(child: values)]);
        },
      ),
    );
  }
}

class _CierrePosMiniValue extends ConsumerWidget {
  const _CierrePosMiniValue({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: valueColor ?? palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
      ],
    );
  }
}

class _CierrePosResumenPanel extends ConsumerWidget {
  const _CierrePosResumenPanel({
    required this.cerrado,
    required this.totalVendido,
    required this.totalEntregado,
    required this.totalCruce,
    required this.diferencia,
    required this.valorBase,
    required this.totalGastos,
    required this.propinas,
    required this.gastosRegistrados,
    this.onEditarBase,
    this.onCerrar,
  });

  final bool cerrado;
  final double totalVendido;
  final double totalEntregado;
  final double totalCruce;
  final double diferencia;
  final double valorBase;
  final double totalGastos;
  final double propinas;
  final int gastosRegistrados;
  final VoidCallback? onEditarBase;
  final VoidCallback? onCerrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final cuadrado = diferencia.abs() < 0.01;
    final statusColor = cuadrado ? AppColors.success : AppColors.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.99),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cuadrado ? palette.cardBorder : statusColor.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, color: palette.secondary, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text('Resumen de caja', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17))),
            ],
          ),
          const SizedBox(height: 14),
          _CierrePosSummaryRow(label: 'Ventas del sistema', value: CurrencyUtils.format(totalVendido)),
          _CierrePosSummaryRow(label: 'Propinas', value: CurrencyUtils.format(propinas)),
          _CierrePosSummaryRow(label: 'Base inicial', value: CurrencyUtils.format(valorBase)),
          _CierrePosSummaryRow(
            label: 'Salidas que afectan efectivo',
            value: CurrencyUtils.format(totalGastos),
          ),
          _CierrePosSummaryRow(label: 'Total contado', value: CurrencyUtils.format(totalEntregado)),
          const SizedBox(height: 8),
          Divider(height: 1, color: palette.cardBorder),
          const SizedBox(height: 10),
          _CierrePosSummaryRow(label: 'Cruce de caja', value: CurrencyUtils.format(totalCruce), strong: true),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cuadrado
                      ? 'Caja cuadrada'
                      : diferencia < 0
                          ? 'Faltante de caja'
                          : 'Sobrante de caja',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(CurrencyUtils.format(diferencia), style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 24)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (onEditarBase != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(onPressed: onEditarBase, icon: const Icon(Icons.savings_rounded), label: const Text('Editar base inicial')),
            ),
          if (onEditarBase != null) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCerrar,
              icon: Icon(cerrado ? Icons.edit_note_rounded : Icons.lock_rounded),
              label: Text(cerrado ? 'Modificar cierre' : 'Contar y cerrar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CierrePosSummaryRow extends ConsumerWidget {
  const _CierrePosSummaryRow({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: strong ? FontWeight.w900 : FontWeight.w700))),
          const SizedBox(width: 12),
          Text(value, style: TextStyle(color: strong ? palette.secondary : palette.textPrimary, fontWeight: FontWeight.w900, fontSize: strong ? 16 : 14)),
        ],
      ),
    );
  }
}

class _CierrePosMovimientosPanel extends ConsumerWidget {
  const _CierrePosMovimientosPanel({
    required this.valorBase,
    required this.totalSalidas,
    required this.totalGastosTurno,
    required this.totalPagosPedidos,
    required this.totalPagosGastos,
    required this.salidas,
    required this.gastosLegacy,
    required this.cerrado,
    this.onEditarBase,
    this.onRegistrarSalida,
    this.onEditarSalida,
    this.onAnularSalida,
    this.onEditarGastos,
  });

  final double valorBase;
  final double totalSalidas;
  final double totalGastosTurno;
  final double totalPagosPedidos;
  final double totalPagosGastos;
  final List<SalidaCajaModel> salidas;
  final List<CierreCajaGastoModel> gastosLegacy;
  final bool cerrado;
  final VoidCallback? onEditarBase;
  final VoidCallback? onRegistrarSalida;
  final ValueChanged<SalidaCajaModel>? onEditarSalida;
  final ValueChanged<SalidaCajaModel>? onAnularSalida;
  final VoidCallback? onEditarGastos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    final header = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final title = Row(
          children: [
            Icon(Icons.swap_vert_circle_rounded, color: palette.secondary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gastos y movimientos de caja',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Puedes corregir gastos incluso después del cierre. El faltante o sobrante se recalcula.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onEditarBase != null)
              OutlinedButton.icon(
                onPressed: onEditarBase,
                icon: const Icon(Icons.savings_rounded, size: 18),
                label: const Text('Base inicial'),
              ),
            if (gastosLegacy.isNotEmpty && onEditarGastos != null)
              OutlinedButton.icon(
                onPressed: onEditarGastos,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Editar gastos del cierre'),
              ),
            if (onRegistrarSalida != null)
              FilledButton.icon(
                onPressed: onRegistrarSalida,
                icon: const Icon(Icons.outbox_rounded, size: 18),
                label: const Text('Registrar salida'),
              ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              actions,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(
          palette.darkBackground ? 0.86 : 0.98,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _CierrePosMovementChip(
                icon: Icons.savings_rounded,
                label: 'Base',
                value: CurrencyUtils.format(valorBase),
              ),
              _CierrePosMovementChip(
                icon: Icons.outbox_rounded,
                label: 'Salidas',
                value: CurrencyUtils.format(totalSalidas),
              ),
              _CierrePosMovementChip(
                icon: Icons.shopping_bag_outlined,
                label: 'Gasto turno',
                value: CurrencyUtils.format(totalGastosTurno),
              ),
              _CierrePosMovementChip(
                icon: Icons.local_shipping_outlined,
                label: 'Pedidos',
                value: CurrencyUtils.format(totalPagosPedidos),
              ),
              _CierrePosMovementChip(
                icon: Icons.receipt_long_outlined,
                label: 'Facturas',
                value: CurrencyUtils.format(totalPagosGastos),
              ),
            ],
          ),
          if (salidas.isNotEmpty || gastosLegacy.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: palette.cardBorder),
            const SizedBox(height: 10),
            for (final salida in salidas) ...[
              _SalidaCajaRow(
                salida: salida,
                palette: palette,
                onEditar: onEditarSalida == null
                    ? null
                    : () => onEditarSalida!(salida),
                onAnular: onAnularSalida == null
                    ? null
                    : () => onAnularSalida!(salida),
              ),
              const SizedBox(height: 7),
            ],
            for (final gasto in gastosLegacy) ...[
              _SalidaCajaLegacyRow(gasto: gasto, palette: palette),
              const SizedBox(height: 7),
            ],
          ] else ...[
            const SizedBox(height: 12),
            Text(
              cerrado
                  ? 'No se registraron pagos ni salidas en este turno. Puedes agregarlos o corregirlos.'
                  : 'Aún no hay movimientos. Registra aquí pagos de pedidos, facturas o salidas del turno.',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SalidaCajaRow extends StatelessWidget {
  const _SalidaCajaRow({
    required this.salida,
    required this.palette,
    this.onEditar,
    this.onAnular,
  });

  final SalidaCajaModel salida;
  final AppPalette palette;
  final VoidCallback? onEditar;
  final VoidCallback? onAnular;

  @override
  Widget build(BuildContext context) {
    final type = salida.tipo ?? 'GASTO_TURNO';
    final icon = switch (type) {
      'PAGO_PEDIDO' => Icons.local_shipping_outlined,
      'PAGO_GASTO' => Icons.receipt_long_outlined,
      _ => Icons.shopping_bag_outlined,
    };
    final label = switch (type) {
      'PAGO_PEDIDO' => salida.pedidoId == null
          ? 'Pago de pedido externo'
          : 'Pago pedido #${salida.pedidoId}',
      'PAGO_GASTO' => 'Pago de factura/gasto',
      _ => 'Gasto del turno',
    };
    final affects = salida.afectaResultado == true;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(.30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder.withOpacity(.65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: palette.secondary, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  salida.descripcion ?? '-',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if ((salida.categoria ?? '').trim().isNotEmpty)
                      Text(
                        salida.categoria!,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if ((salida.medioPagoNombre ?? '').trim().isNotEmpty)
                      Text(
                        'Medio: ${salida.medioPagoNombre}',
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      affects
                          ? 'Afecta rentabilidad'
                          : 'Solo flujo del medio',
                      style: TextStyle(
                        color: affects
                            ? palette.warning
                            : palette.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((salida.fechaHora ?? '').trim().isNotEmpty)
                      Text(
                        _formatHoraSalidaCaja(salida.fechaHora),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if ((salida.registradoPor ?? '').trim().isNotEmpty)
                      Text(
                        'Por ' + salida.registradoPor!,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyUtils.format(salida.valor),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              if (onEditar != null)
                IconButton(
                  tooltip: 'Editar gasto o pago',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              if (onAnular != null)
                IconButton(
                  tooltip: 'Anular salida',
                  visualDensity: VisualDensity.compact,
                  onPressed: onAnular,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalidaCajaLegacyRow extends StatelessWidget {
  const _SalidaCajaLegacyRow({
    required this.gasto,
    required this.palette,
  });

  final CierreCajaGastoModel gasto;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.background.withOpacity(.22),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: palette.cardBorder.withOpacity(.55)),
        ),
        child: Row(
          children: [
            Icon(Icons.history_rounded, color: palette.textSecondary, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gasto histórico · ' + (gasto.descripcion ?? '-'),
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
            Text(
              CurrencyUtils.format(gasto.valor),
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      );

}

class _CierrePosMovementChip extends ConsumerWidget {
  const _CierrePosMovementChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.44 : 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: palette.secondary, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
          Text(value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }
}




String _formatHoraSalidaCaja(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('hh:mm a', 'es_CO').format(parsed);
}

String _tipoSalidaCajaLabel(String? tipo) => switch (tipo) {
      'PAGO_PEDIDO' => 'Pago de pedido',
      'PAGO_GASTO' => 'Pago de factura/gasto',
      'GASTO_TURNO' => 'Gasto del turno',
      _ => tipo ?? 'Salida',
    };

bool _esMedioEfectivoCierre(String? nombre) {
  final value = (nombre ?? '').toLowerCase().trim();
  return value.contains('efectivo') || value.contains('cash');
}

bool _mismoMedioSalidaCierre(String? medioCierre, String? medioSalida) {
  final cierre = (medioCierre ?? '').trim().toLowerCase();
  final salida = (medioSalida ?? '').trim().toLowerCase();
  if (salida.isEmpty ||
      salida == 'caja' ||
      salida == 'efectivo' ||
      salida == 'cash') {
    return _esMedioEfectivoCierre(medioCierre);
  }
  return cierre.isNotEmpty && cierre == salida;
}

bool _salidaAfectaCajaFisicaCierre(SalidaCajaModel salida) {
  final medio = (salida.medioPagoNombre ?? '').trim();
  if (medio.isEmpty || medio.toLowerCase() == 'caja') return true;
  return _esMedioEfectivoCierre(medio);
}

double _salidasAplicadasMedioCierre(
  CierreCajaResumenModel cierre,
  CierreCajaMedioPagoModel medio,
) {
  if (!_esMedioEfectivoCierre(medio.medioPagoNombre)) {
    return 0;
  }
  var total = cierre.salidasCaja
      .where(_salidaAfectaCajaFisicaCierre)
      .fold<double>(0, (sum, salida) => sum + (salida.valor ?? 0));
  total += cierre.gastos.fold<double>(
    0,
    (sum, gasto) => sum + (gasto.valor ?? 0),
  );
  return total;
}

double _diferenciaMedioCierreAjustada(
  CierreCajaResumenModel cierre,
  CierreCajaMedioPagoModel medio,
) {
  final sistema = medio.totalSistema ?? 0;
  final entregado = medio.valorEntregado ?? 0;
  final base = _baseAplicadaMedioCierre(cierre, medio);
  final salidas = _salidasAplicadasMedioCierre(cierre, medio);
  return entregado + salidas - base - sistema;
}

double _baseAplicadaMedioCierre(CierreCajaResumenModel cierre, CierreCajaMedioPagoModel medio) {
  if (_esMedioEfectivoCierre(medio.medioPagoNombre)) {
    return cierre.valorBase ?? 0;
  }
  return 0;
}

String _notaDiferenciaMedioCierre(
  CierreCajaResumenModel cierre,
  CierreCajaMedioPagoModel medio,
) {
  if (_esMedioEfectivoCierre(medio.medioPagoNombre)) {
    return 'Efectivo: contado + salidas en efectivo - base inicial - recibido sistema';
  }
  return 'Informativo: se toma automáticamente de las ventas y no requiere conteo de la cajera.';
}

String _formatFechaCierre(String? value) {
  if (value == null || value.trim().isEmpty) return 'hoy';
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return value;
  const months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

Future<Uint8List> _crearPdfCierreCaja(CierreCajaResumenModel cierre) async {
  final pdf = pw.Document();
  final fecha = cierre.fecha ?? '';
  final ventasSinPropina = cierre.totalVentasSinPropina ?? ((cierre.totalVendido ?? 0) - (cierre.totalPropinas ?? 0));

  pw.Widget sectionTitle(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#EEF2FF'),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#111827'))),
      );

  pw.Widget summaryBox(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#64748B'))),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
        ]),
      );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#0F172A'),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('BarLytics - Cierre de caja', style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Fecha: $fecha    Estado: ${cierre.cerrado == true ? 'CERRADO' : 'PENDIENTE'}    Ventas incluidas: ${cierre.ventasIncluidas ?? 0}', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.Table(
          columnWidths: {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth(), 2: pw.FlexColumnWidth()},
          children: [
            pw.TableRow(children: [
              summaryBox('Total vendido', CurrencyUtils.format(cierre.totalVendido)),
              summaryBox('Ventas sin propina', CurrencyUtils.format(ventasSinPropina)),
              summaryBox('Propinas', CurrencyUtils.format(cierre.totalPropinas)),
            ]),
            pw.TableRow(children: [
              summaryBox('Entregado medios', CurrencyUtils.format(cierre.totalEntregado)),
              summaryBox('Base inicial', CurrencyUtils.format(cierre.valorBase)),
              summaryBox('Pagos y salidas', CurrencyUtils.format(cierre.totalGastos)),
            ]),
            pw.TableRow(children: [
              summaryBox('Total cruce', CurrencyUtils.format(cierre.totalCruce ?? ((cierre.totalEntregado ?? 0) + (cierre.totalGastos ?? 0) - (cierre.valorBase ?? 0)))),
              summaryBox('Diferencia', CurrencyUtils.format(cierre.diferencia)),
              summaryBox('Fecha registro', cierre.fechaRegistro ?? '-'),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text('Formula de cruce: total contado por medios + pagos/salidas del turno - base inicial = dinero real de ventas. Diferencia = cruce - total vendido.', style: const pw.TextStyle(fontSize: 8)),
        sectionTitle('1. Medios de pago - recibido, contado y diferencia ajustada'),
        pw.Table.fromTextArray(
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E2E8F0')),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          headers: const ['Valor sistema', 'Valor contado', 'Base descontada', 'Diferencia ajustada', 'Medio'],
          data: cierre.mediosPago.map((m) => [
            CurrencyUtils.format(m.totalSistema),
            CurrencyUtils.format(m.valorEntregado),
            CurrencyUtils.format(_baseAplicadaMedioCierre(cierre, m)),
            CurrencyUtils.format(_diferenciaMedioCierreAjustada(cierre, m)),
            m.medioPagoNombre ?? '-',
          ]).toList(),
        ),
        sectionTitle('2. Base inicial y salidas del turno'),
        pw.Table.fromTextArray(
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E2E8F0')),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          headers: const [
            'Valor',
            'Tipo',
            'Descripción',
            'Hora',
            'Responsable',
          ],
          data: [
            [
              CurrencyUtils.format(cierre.valorBase),
              'Base inicial',
              'Dinero recibido al iniciar el turno',
              '-',
              '-',
            ],
            ...cierre.salidasCaja.map((s) => [
                  CurrencyUtils.format(s.valor),
                  _tipoSalidaCajaLabel(s.tipo),
                  s.descripcion ?? '-',
                  _formatHoraSalidaCaja(s.fechaHora),
                  s.registradoPor ?? '-',
                ]),
            ...cierre.gastos.map((g) => [
                  CurrencyUtils.format(g.valor),
                  'Gasto histórico',
                  g.descripcion ?? '-',
                  '-',
                  '-',
                ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          columnWidths: {
            0: pw.FlexColumnWidth(),
            1: pw.FlexColumnWidth(),
            2: pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(children: [
              summaryBox(
                'Gastos del turno',
                CurrencyUtils.format(cierre.totalGastosTurno),
              ),
              summaryBox(
                'Pagos de pedidos',
                CurrencyUtils.format(cierre.totalPagosPedidos),
              ),
              summaryBox(
                'Pagos de facturas',
                CurrencyUtils.format(cierre.totalPagosGastosConfigurados),
              ),
            ]),
          ],
        ),
        sectionTitle('3. Productos vendidos'),
        pw.Table.fromTextArray(
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E2E8F0')),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          headers: const ['Total producto', 'Valor unidad', 'Cantidad', 'Producto'],
          data: cierre.productos.map((p) => [
            CurrencyUtils.format(p.totalVenta),
            CurrencyUtils.format(p.valorUnitario),
            _formatCantidadGeneral(p.cantidad ?? 0),
            p.productoNombre ?? '-',
          ]).toList(),
        ),
        sectionTitle('4. Ventas incluidas en el cierre'),
        pw.Table.fromTextArray(
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#E2E8F0')),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          headers: const ['Total', 'Propina', 'Venta sin propina', 'Venta', 'Mesa', 'Fecha'],
          data: cierre.ventas.map((v) => [
            CurrencyUtils.format(v.total),
            CurrencyUtils.format(v.propina),
            CurrencyUtils.format(v.subtotalVenta),
            '#${v.ventaId ?? '-'}',
            ((v.tipoVenta ?? '').toUpperCase() == 'DIRECTA' || v.mesaId == null) ? 'Venta directa' : 'Mesa ${v.mesaNumero ?? v.mesaId ?? '-'}',
            v.fecha ?? '-',
          ]).toList(),
        ),
        if ((cierre.observacion ?? '').trim().isNotEmpty) ...[
          sectionTitle('Observaciones'),
          pw.Text(cierre.observacion!, style: const pw.TextStyle(fontSize: 9)),
        ],
      ],
    ),
  );
  return pdf.save();
}

class _CierreFooterValue extends ConsumerWidget {
  const _CierreFooterValue({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (emphasized ? palette.secondary : palette.textPrimary),
            fontSize: emphasized ? 15 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _CierreHeroMetric extends ConsumerWidget {
  const _CierreHeroMetric({required this.label, required this.value, required this.icon, this.valueColor});

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.32 : 0.64),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (valueColor ?? palette.secondary).withOpacity(0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: valueColor ?? palette.secondary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 11)),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: valueColor ?? palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CierreTurnSummary extends ConsumerWidget {
  const _CierreTurnSummary({
    required this.totalVendido,
    required this.totalVentasSinPropina,
    required this.totalPropinas,
    required this.totalEntregado,
    required this.valorBase,
    required this.totalGastos,
    required this.totalCruce,
    required this.diferencia,
  });

  final double totalVendido;
  final double totalVentasSinPropina;
  final double totalPropinas;
  final double totalEntregado;
  final double valorBase;
  final double totalGastos;
  final double totalCruce;
  final double diferencia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final cuadrado = diferencia.abs() < 0.01;
    final diferenciaColor = cuadrado ? AppColors.success : AppColors.danger;
    final rows = <({String label, double value, bool strong})>[
      (label: 'Ventas sin propina', value: totalVentasSinPropina, strong: false),
      (label: 'Propinas', value: totalPropinas, strong: false),
      (label: 'Total vendido', value: totalVendido, strong: true),
      (label: 'Entregado por medios', value: totalEntregado, strong: false),
      (label: 'Más pagos/salidas', value: totalGastos, strong: false),
      (label: 'Menos base inicial', value: -valorBase, strong: false),
      (label: 'Total del cruce', value: totalCruce, strong: true),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.98),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.secondary.withOpacity(0.16)),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.50), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.calculate_rounded, color: palette.secondary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resumen del turno', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text('Cómo se forma el valor final del cierre.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: TextStyle(
                        color: rows[i].strong ? palette.textPrimary : palette.textSecondary,
                        fontWeight: rows[i].strong ? FontWeight.w900 : FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    CurrencyUtils.format(rows[i].value),
                    style: TextStyle(
                      color: rows[i].strong ? palette.secondary : palette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (i == 1 || i == 5) Divider(height: 8, color: palette.cardBorder),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: diferenciaColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: diferenciaColor.withOpacity(0.24)),
            ),
            child: Row(
              children: [
                Icon(cuadrado ? Icons.task_alt_rounded : Icons.error_outline_rounded, color: diferenciaColor),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    cuadrado ? 'La caja está cuadrada' : 'Existe una diferencia por revisar',
                    style: TextStyle(color: diferenciaColor, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(CurrencyUtils.format(diferencia), style: TextStyle(color: diferenciaColor, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CierreWorkflowPanel extends ConsumerWidget {
  const _CierreWorkflowPanel({
    required this.cerrado,
    required this.valorBase,
    required this.medios,
    required this.totalEntregado,
    required this.ventas,
    this.onBase,
    this.onCierre,
  });

  final bool cerrado;
  final double valorBase;
  final int medios;
  final double totalEntregado;
  final int ventas;
  final VoidCallback? onBase;
  final VoidCallback? onCierre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.98),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Flujo del cierre', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 3),
          Text('Completa el proceso sin perderte entre los valores.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 15),
          _CierreWorkflowStep(
            number: 1,
            title: 'Base inicial',
            subtitle: CurrencyUtils.format(valorBase),
            completed: valorBase > 0 || cerrado,
            onTap: onBase,
          ),
          _CierreWorkflowStep(
            number: 2,
            title: 'Conteo de medios',
            subtitle: '$medios medios · ${CurrencyUtils.format(totalEntregado)}',
            completed: totalEntregado > 0 || cerrado,
          ),
          _CierreWorkflowStep(
            number: 3,
            title: cerrado ? 'Cierre registrado' : 'Confirmar cierre',
            subtitle: '$ventas ventas incluidas',
            completed: cerrado,
            onTap: cerrado ? null : onCierre,
            last: true,
          ),
          if (!cerrado) ...[
            const SizedBox(height: 13),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCierre,
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text('Contar medios y cerrar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CierreWorkflowStep extends ConsumerWidget {
  const _CierreWorkflowStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.completed,
    this.onTap,
    this.last = false,
  });

  final int number;
  final String title;
  final String subtitle;
  final bool completed;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final statusColor = completed ? AppColors.success : palette.secondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.11),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor.withOpacity(0.28)),
                  ),
                  child: Center(
                    child: completed
                        ? Icon(Icons.check_rounded, size: 17, color: statusColor)
                        : Text('$number', style: TextStyle(color: statusColor, fontWeight: FontWeight.w900)),
                  ),
                ),
                if (!last)
                  Container(
                    width: 1,
                    height: 27,
                    color: palette.cardBorder,
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _CierreCollapsibleSection extends ConsumerWidget {
  const _CierreCollapsibleSection({
    required this.icon,
    required this.title,
    required this.summary,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.88 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('cierre-collapsible-${title.toLowerCase().replaceAll(' ', '-')}'),
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: palette.secondary.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: palette.secondary, size: 21),
          ),
          title: Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
          subtitle: Text(summary, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
          children: [child],
        ),
      ),
    );
  }
}


class _CierreMetricCard extends ConsumerWidget {
  const _CierreMetricCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.82 : 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 18, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: palette.secondary.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: palette.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CierreSection extends ConsumerWidget {
  const _CierreSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.86 : 0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: palette.secondary.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: palette.secondary, size: 21),
                    ),
                    const SizedBox(width: 11),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              );
              if (trailing == null) return heading;
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 10),
                    trailing!,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  trailing!,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}


class _CierreValueTile extends ConsumerWidget {
  const _CierreValueTile({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.description,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final String? description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.translucentBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: palette.secondary),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(color: valueColor ?? palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
                if ((description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description!, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CierreGastosTable extends ConsumerWidget {
  const _CierreGastosTable({required this.items, this.valorBase, this.totalGastos});
  final List<CierreCajaGastoModel> items;
  final double? valorBase;
  final double? totalGastos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final rows = <({String concepto, String descripcion, double valor})>[
      (concepto: 'Base inicial recibida', descripcion: 'Dinero recibido al iniciar el turno; se resta del conteo final', valor: valorBase ?? 0),
      for (final item in items) (concepto: 'Gasto', descripcion: item.descripcion ?? '-', valor: item.valor ?? 0),
    ];
    if (rows.length == 1 && (valorBase ?? 0) == 0) {
      return Text('No hay base inicial ni gastos registrados para este cierre.', style: TextStyle(color: palette.textSecondary));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final content = narrow
            ? Column(
                children: rows.map((item) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.glassSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.translucentBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CierreValueTile(label: item.concepto, value: CurrencyUtils.format(item.valor), icon: item.concepto == 'Gasto' ? Icons.shopping_bag_rounded : Icons.savings_rounded),
                        const SizedBox(height: 8),
                        Text(item.descripcion, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }).toList(growable: false),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(palette.secondary.withOpacity(0.10)),
                    columnSpacing: 26,
                    columns: const [
                      DataColumn(label: Text('Valor')),
                      DataColumn(label: Text('Concepto')),
                      DataColumn(label: Text('Descripción')),
                    ],
                    rows: rows.map((item) => DataRow(cells: [
                      DataCell(Text(CurrencyUtils.format(item.valor), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))),
                      DataCell(Text(item.concepto, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700))),
                      DataCell(SizedBox(width: 320, child: Text(item.descripcion, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)))),
                    ])).toList(growable: false),
                  ),
                ),
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total gastos: ${CurrencyUtils.format(totalGastos)}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );
  }
}

class _CierreMediosPagoTable extends ConsumerWidget {
  const _CierreMediosPagoTable({required this.cierre, required this.items});

  final CierreCajaResumenModel cierre;
  final List<CierreCajaMedioPagoModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (items.isEmpty) {
      return Text('No hay pagos registrados para este día.', style: TextStyle(color: palette.textSecondary));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 860;
        final body = narrow
            ? Column(
                children: items.map((item) {
                  final baseAplicada = _baseAplicadaMedioCierre(cierre, item);
                  final diferenciaAjustada = _diferenciaMedioCierreAjustada(cierre, item);
                  final diferenciaColor = diferenciaAjustada.abs() < 0.01 ? AppColors.success : AppColors.danger;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.glassSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.translucentBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item.medioPagoNombre ?? '-', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16))),
                            Icon(_esMedioEfectivoCierre(item.medioPagoNombre) ? Icons.payments_rounded : Icons.account_balance_wallet_rounded, color: palette.secondary),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(width: constraints.maxWidth > 520 ? (constraints.maxWidth - 34) / 2 : double.infinity, child: _CierreValueTile(label: 'Valor sistema', value: CurrencyUtils.format(item.totalSistema), icon: Icons.receipt_long_rounded)),
                            SizedBox(width: constraints.maxWidth > 520 ? (constraints.maxWidth - 34) / 2 : double.infinity, child: _CierreValueTile(label: 'Valor contado', value: CurrencyUtils.format(item.valorEntregado), icon: Icons.fact_check_rounded)),
                            SizedBox(width: constraints.maxWidth > 520 ? (constraints.maxWidth - 34) / 2 : double.infinity, child: _CierreValueTile(label: 'Base descontada', value: CurrencyUtils.format(baseAplicada), icon: Icons.savings_rounded)),
                            SizedBox(width: constraints.maxWidth > 520 ? (constraints.maxWidth - 34) / 2 : double.infinity, child: _CierreValueTile(label: 'Diferencia ajustada', value: CurrencyUtils.format(diferenciaAjustada), valueColor: diferenciaColor, icon: Icons.compare_arrows_rounded)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_notaDiferenciaMedioCierre(cierre, item), style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }).toList(growable: false),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(palette.secondary.withOpacity(0.10)),
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Valor sistema')),
                      DataColumn(label: Text('Valor contado')),
                      DataColumn(label: Text('Base descontada')),
                      DataColumn(label: Text('Diferencia ajustada')),
                      DataColumn(label: Text('Medio')),
                      DataColumn(label: Text('Cálculo')),
                    ],
                    rows: items.map((item) {
                      final baseAplicada = _baseAplicadaMedioCierre(cierre, item);
                      final diferenciaAjustada = _diferenciaMedioCierreAjustada(cierre, item);
                      final diferenciaColor = diferenciaAjustada.abs() < 0.01 ? AppColors.success : AppColors.danger;
                      return DataRow(cells: [
                        DataCell(Text(CurrencyUtils.format(item.totalSistema), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800))),
                        DataCell(Text(CurrencyUtils.format(item.valorEntregado), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800))),
                        DataCell(Text(CurrencyUtils.format(baseAplicada), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800))),
                        DataCell(Text(CurrencyUtils.format(diferenciaAjustada), style: TextStyle(color: diferenciaColor, fontWeight: FontWeight.w900))),
                        DataCell(Text(item.medioPagoNombre ?? '-', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700))),
                        DataCell(SizedBox(width: 260, child: Text(_notaDiferenciaMedioCierre(cierre, item), overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)))),
                      ]);
                    }).toList(),
                  ),
                ),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.secondary.withOpacity(0.20)),
              ),
              child: Text(
                'Nota: en efectivo la diferencia se ajusta con la base inicial y los gastos. La columna Base descontada muestra cuánto se está restando porque esa base ya viene incluida en el dinero contado al final del turno.',
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
              ),
            ),
            body,
          ],
        );
      },
    );
  }
}

class _CierreProductosTable extends ConsumerWidget {
  const _CierreProductosTable({required this.items});
  final List<CierreCajaProductoModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (items.isEmpty) {
      return Text('No hay productos vendidos para este cierre.', style: TextStyle(color: palette.textSecondary));
    }

    final totalUnidades = items.fold<double>(0, (sum, item) => sum + (item.cantidad ?? 0));
    final totalVendido = items.fold<double>(0, (sum, item) => sum + (item.totalVenta ?? 0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.secondary.withOpacity(0.16)),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  _CierreInlineMetric(icon: Icons.inventory_2_outlined, label: 'Referencias', value: '${items.length}'),
                  _CierreInlineMetric(icon: Icons.numbers_rounded, label: 'Unidades', value: _formatCantidadGeneral(totalUnidades)),
                  _CierreInlineMetric(icon: Icons.payments_outlined, label: 'Total vendido', value: CurrencyUtils.format(totalVendido), emphasized: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: palette.background.withOpacity(palette.darkBackground ? 0.28 : 0.52),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.cardBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    if (!compact)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        color: palette.secondary.withOpacity(0.10),
                        child: Row(
                          children: [
                            const SizedBox(width: 42),
                            Expanded(
                              child: Text('Producto', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                            SizedBox(
                              width: 120,
                              child: Text('Cantidad', textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                            SizedBox(
                              width: 150,
                              child: Text('Valor unidad', textAlign: TextAlign.right, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                            SizedBox(
                              width: 160,
                              child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    for (var index = 0; index < items.length; index++)
                      _CierreProductoRow(
                        item: items[index],
                        index: index,
                        compact: compact,
                        last: index == items.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CierreProductoRow extends ConsumerWidget {
  const _CierreProductoRow({required this.item, required this.index, required this.compact, required this.last});

  final CierreCajaProductoModel item;
  final int index;
  final bool compact;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final nombre = (item.productoNombre ?? 'Producto sin nombre').trim();
    final cantidad = item.cantidad ?? 0;

    final rank = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
      ),
      alignment: Alignment.center,
      child: Text('${index + 1}', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 12)),
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                rank,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Text(CurrencyUtils.format(item.totalVenta), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallInfoPill(icon: Icons.numbers_rounded, text: '${_formatCantidadGeneral(cantidad)} unidades'),
                  _SmallInfoPill(icon: Icons.sell_outlined, text: '${CurrencyUtils.format(item.valorUnitario)} c/u'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Row(
        children: [
          rank,
          const SizedBox(width: 10),
          Expanded(
            child: Text(nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
                child: Text(_formatCantidadGeneral(cantidad), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(CurrencyUtils.format(item.valorUnitario), textAlign: TextAlign.right, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            width: 160,
            child: Text(CurrencyUtils.format(item.totalVenta), textAlign: TextAlign.right, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _CierreVentasTable extends ConsumerWidget {
  const _CierreVentasTable({required this.items});
  final List<CierreCajaVentaIncluidaModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (items.isEmpty) {
      return Text('No hay ventas finalizadas pendientes de cierre para este día.', style: TextStyle(color: palette.textSecondary));
    }

    final totalSinPropina = items.fold<double>(0, (sum, item) => sum + (item.subtotalVenta ?? 0));
    final totalPropina = items.fold<double>(0, (sum, item) => sum + (item.propina ?? 0));
    final totalVentas = items.fold<double>(0, (sum, item) => sum + (item.total ?? 0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.secondary.withOpacity(0.16)),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  _CierreInlineMetric(icon: Icons.receipt_long_outlined, label: 'Ventas', value: '${items.length}'),
                  _CierreInlineMetric(icon: Icons.volunteer_activism_outlined, label: 'Propinas', value: CurrencyUtils.format(totalPropina)),
                  _CierreInlineMetric(icon: Icons.payments_outlined, label: 'Total incluido', value: CurrencyUtils.format(totalVentas), emphasized: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: palette.background.withOpacity(palette.darkBackground ? 0.28 : 0.52),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.cardBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    if (!compact)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        color: palette.secondary.withOpacity(0.10),
                        child: Row(
                          children: [
                            const SizedBox(width: 44),
                            Expanded(child: Text('Venta y mesa', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 12))),
                            SizedBox(width: 170, child: Text('Venta sin propina', textAlign: TextAlign.right, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 12))),
                            SizedBox(width: 135, child: Text('Propina', textAlign: TextAlign.right, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 12))),
                            SizedBox(width: 160, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 12))),
                          ],
                        ),
                      ),
                    for (var index = 0; index < items.length; index++)
                      _CierreVentaRow(
                        item: items[index],
                        compact: compact,
                        last: index == items.length - 1,
                      ),
                  ],
                ),
              ),
            ),
            if (totalSinPropina > 0 && totalVentas == 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Total de ventas sin propina: ${CurrencyUtils.format(totalSinPropina)}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }
}

class _CierreVentaRow extends ConsumerWidget {
  const _CierreVentaRow({required this.item, required this.compact, required this.last});

  final CierreCajaVentaIncluidaModel item;
  final bool compact;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final mesa = item.mesaNumero ?? item.mesaId;
    final fecha = _formatFechaHoraVentaDetalle(item.fecha);

    final icon = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
      ),
      child: Icon(Icons.receipt_long_rounded, color: palette.secondary, size: 18),
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Venta #${item.ventaId ?? '-'}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('Mesa ${mesa ?? '-'}${fecha.isEmpty ? '' : ' · $fecha'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(CurrencyUtils.format(item.total), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallInfoPill(icon: Icons.shopping_bag_outlined, text: 'Venta ${CurrencyUtils.format(item.subtotalVenta)}'),
                  _SmallInfoPill(icon: Icons.volunteer_activism_outlined, text: 'Propina ${CurrencyUtils.format(item.propina)}'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Venta #${item.ventaId ?? '-'} · Mesa ${mesa ?? '-'}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                if (fecha.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(fecha, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ],
            ),
          ),
          SizedBox(width: 170, child: Text(CurrencyUtils.format(item.subtotalVenta), textAlign: TextAlign.right, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800))),
          SizedBox(width: 135, child: Text(CurrencyUtils.format(item.propina), textAlign: TextAlign.right, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800))),
          SizedBox(width: 160, child: Text(CurrencyUtils.format(item.total), textAlign: TextAlign.right, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15))),
        ],
      ),
    );
  }
}

class _CierreInlineMetric extends ConsumerWidget {
  const _CierreInlineMetric({required this.icon, required this.label, required this.value, this.emphasized = false});

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: palette.secondary),
        const SizedBox(width: 7),
        Text('$label: ', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
        Text(value, style: TextStyle(color: emphasized ? palette.secondary : palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.mode, required this.isCajero});
  final MeseroPageMode mode;
  final bool isCajero;

  IconData _headerIcon(MeseroPageMode value) => switch (value) {
        MeseroPageMode.mesas => Icons.table_bar_rounded,
        MeseroPageMode.productos => Icons.inventory_2_rounded,
        MeseroPageMode.resumen => Icons.dashboard_customize_rounded,
        MeseroPageMode.historial => Icons.receipt_long_rounded,
        MeseroPageMode.cierreCaja => Icons.point_of_sale_rounded,
      };

  String _headerTitle(MeseroPageMode value) => switch (value) {
        MeseroPageMode.mesas => 'Mesas y caja',
        MeseroPageMode.productos => 'Productos y carta',
        MeseroPageMode.resumen => 'Resumen del salón',
        MeseroPageMode.historial => 'Historial de ventas',
        MeseroPageMode.cierreCaja => 'Cierre de caja',
      };

  String _headerEyebrow(MeseroPageMode value) => switch (value) {
        MeseroPageMode.mesas => 'Operación principal',
        MeseroPageMode.productos => 'Catálogo activo',
        MeseroPageMode.resumen => 'Vista general',
        MeseroPageMode.historial => 'Trazabilidad',
        MeseroPageMode.cierreCaja => 'Control del turno',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final description = switch (mode) {
      MeseroPageMode.mesas => isCajero
          ? 'Consulta el salón, continúa ventas y registra pagos rápidamente.'
          : 'Consulta el salón y continúa las ventas de tus mesas.',
      MeseroPageMode.productos => 'Consulta bebidas y productos disponibles para la venta.',
      MeseroPageMode.resumen => 'Revisa ventas abiertas, mesas disponibles y saldos pendientes.',
      MeseroPageMode.historial => 'Consulta ventas cerradas, productos y pagos registrados.',
      MeseroPageMode.cierreCaja => 'Cuadra las ventas y medios de pago del turno actual.',
    };

    final title = _headerTitle(mode);
    final eyebrow = _headerEyebrow(mode);
    final statusText = isCajero ? 'Caja activa' : 'Servicio activo';

    final content = [
      Container(
        width: compact ? 54 : 58,
        height: compact ? 54 : 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.accent, Color.lerp(palette.secondary, palette.primary, 0.35) ?? palette.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: palette.accent.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 10)),
          ],
        ),
        child: Icon(_headerIcon(mode), color: palette.onPrimary, size: compact ? 26 : 28),
      ),
      SizedBox(width: compact ? 12 : 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(palette.darkBackground ? 0.14 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: palette.secondary.withOpacity(0.20)),
                  ),
                  child: Text(
                    eyebrow.toUpperCase(),
                    style: TextStyle(
                      color: palette.secondary,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.4,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    fontSize: compact ? 24 : 28,
                    letterSpacing: -0.4,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              maxLines: compact ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12.8 : 13.4,
                height: 1.32,
              ),
            ),
          ],
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.primary.withOpacity(0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: palette.primary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(statusText, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.2)),
            ],
          ),
        ),
      ],
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 14 : 18, compact ? 14 : 18, compact ? 14 : 18, compact ? 14 : 18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.cardBorder.withOpacity(0.80)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          compact ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: content.take(3).toList()), const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.primary.withOpacity(0.20)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: palette.primary, shape: BoxShape.circle)), const SizedBox(width: 8), Text(statusText, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.2))]),
          ))]) : Row(crossAxisAlignment: CrossAxisAlignment.center, children: content),
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


class _VentaDirectaActionCard extends ConsumerWidget {
  const _VentaDirectaActionCard({
    required this.ventasAbiertas,
    required this.enabled,
    required this.onPressed,
    this.onVerAbiertas,
  });

  final List<MeseroVentaModel> ventasAbiertas;
  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback? onVerAbiertas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final abiertas = ventasAbiertas.length;
    final totalPendiente = ventasAbiertas.fold<double>(0, (sum, venta) => sum + (venta.saldoPendiente ?? 0));
    final accentColor = palette.secondary;
    final cardColor = palette.darkBackground
        ? Color.lerp(palette.surface, accentColor, 0.12)!
        : Color.lerp(palette.surface, accentColor, 0.07)!;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: enabled ? 1 : 0.62,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.28)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.055), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final info = Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.bolt_rounded, color: accentColor, size: 23),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Venta rápida',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
                                child: Text('SIN MESA', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 8.8, letterSpacing: 0.25)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            abiertas == 0
                                ? 'Cobra directamente sin abrir una mesa.'
                                : '$abiertas venta${abiertas == 1 ? '' : 's'} abierta${abiertas == 1 ? '' : 's'} · ${CurrencyUtils.format(totalPendiente)} pendiente',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.8),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final secondaryButton = abiertas > 0 && onVerAbiertas != null
                    ? OutlinedButton.icon(
                        onPressed: enabled ? onVerAbiertas : null,
                        icon: const Icon(Icons.receipt_long_rounded, size: 17),
                        label: Text('$abiertas abierta${abiertas == 1 ? '' : 's'}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          side: BorderSide(color: accentColor.withOpacity(0.30)),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    : null;
                final primaryButton = FilledButton.icon(
                  onPressed: enabled ? onPressed : null,
                  icon: Icon(abiertas == 0 ? Icons.add_rounded : Icons.arrow_forward_rounded, size: 18),
                  label: Text(abiertas == 0 ? 'Nueva venta' : 'Continuar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
                final actions = compact
                    ? Row(
                        children: [
                          if (secondaryButton != null) ...[
                            Expanded(child: secondaryButton),
                            const SizedBox(width: 8),
                          ],
                          Expanded(child: primaryButton),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (secondaryButton != null) ...[
                            secondaryButton,
                            const SizedBox(width: 8),
                          ],
                          primaryButton,
                        ],
                      );

                if (compact) {
                  return Column(children: [info, const SizedBox(height: 9), actions]);
                }
                return Row(children: [Expanded(child: info), const SizedBox(width: 12), actions]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NuevaVentaDirectaAction {
  const _NuevaVentaDirectaAction._();
  static const instance = _NuevaVentaDirectaAction._();
}

class _EliminarVentaDirectaAction {
  const _EliminarVentaDirectaAction(this.venta);
  final MeseroVentaModel venta;
}

class _VentasDirectasAbiertasSheet extends ConsumerWidget {
  const _VentasDirectasAbiertasSheet({required this.ventas});
  final List<MeseroVentaModel> ventas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 44, height: 4, decoration: BoxDecoration(color: palette.cardBorder, borderRadius: BorderRadius.circular(99))),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: palette.secondary.withOpacity(0.14), borderRadius: BorderRadius.circular(15)),
                    child: Icon(Icons.point_of_sale_rounded, color: palette.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ventas directas abiertas', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 19)),
                        Text('Selecciona una para continuar o crea una nueva.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ventas.length,
                  separatorBuilder: (_, __) => Divider(color: palette.cardBorder, height: 1),
                  itemBuilder: (context, index) {
                    final venta = ventas[index];
                    final productos = venta.cuentas.fold<int>(0, (sum, cuenta) => sum + cuenta.productos.length);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                      leading: CircleAvatar(
                        backgroundColor: palette.secondary.withOpacity(0.13),
                        child: Icon(Icons.receipt_long_rounded, color: palette.secondary),
                      ),
                      title: Text('Venta directa #${venta.ventaId ?? '-'}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                      subtitle: Text('$productos productos · Saldo ${CurrencyUtils.format(venta.saldoPendiente)}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            tooltip: 'Opciones de la venta',
                            icon: Icon(Icons.more_vert_rounded, color: palette.textSecondary),
                            onSelected: (value) {
                              if (value == 'eliminar') {
                                Navigator.of(context).pop(_EliminarVentaDirectaAction(venta));
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'eliminar',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                                    SizedBox(width: 9),
                                    Text('Eliminar venta directa'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.chevron_right_rounded, color: palette.secondary),
                        ],
                      ),
                      onTap: () => Navigator.of(context).pop(venta),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_NuevaVentaDirectaAction.instance),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Iniciar nueva venta directa'),
                ),
              ),
            ],
          ),
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
    final abiertas = mesas.where((mesa) => mesa.ventaId != null && (mesa.estadoMesa ?? '').toUpperCase() != 'INACTIVA').length;
    final inactivas = mesas.where((mesa) => (mesa.estadoMesa ?? '').toUpperCase() == 'INACTIVA').length;
    final disponibles = (mesas.length - abiertas - inactivas).clamp(0, mesas.length);
    final total = mesas.fold<double>(0, (sum, mesa) => sum + (mesa.totalPendiente ?? 0));

    Widget metric(IconData icon, String value, String label, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(palette.darkBackground ? 0.10 : 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.8, height: 1),
                  ),
                  const SizedBox(height: 3),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 9.4, height: 1)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final metrics = <Widget>[
      metric(Icons.table_bar_rounded, '${mesas.length}', 'Mesas', palette.secondary),
      metric(Icons.receipt_long_rounded, '$abiertas', 'Ocupadas', AppColors.warning),
      metric(Icons.event_available_rounded, '$disponibles', 'Libres', AppColors.success),
      metric(Icons.payments_rounded, CurrencyUtils.format(total), 'Pendiente', total > 0.009 ? AppColors.warning : palette.secondary),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          final width = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metrics.map((item) => SizedBox(width: width, child: item)).toList(growable: false),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: metrics[i]),
            ],
          ],
        );
      },
    );
  }
}

class _MesasSummaryDivider extends StatelessWidget {
  const _MesasSummaryDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(width: 1, height: 30, margin: const EdgeInsets.symmetric(horizontal: 5), color: color);
}

class _MesaCard extends ConsumerWidget {
  const _MesaCard({
    required this.mesa,
    required this.onTap,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    this.onDelete,
    this.onPagar,
  });

  final MeseroMesaResumenModel mesa;
  final VoidCallback? onTap;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPagar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final abierta = mesa.ventaId != null;
    final descripcion = (mesa.mesaDescripcion ?? '').trim();
    final estadoMesa = (mesa.estadoMesa ?? '').trim().toUpperCase();
    final inactiva = estadoMesa == 'INACTIVA';
    final ocupada = abierta && !inactiva;
    final statusText = inactiva ? 'Inactiva' : ocupada ? 'Ocupada' : 'Libre';
    final stateColor = inactiva ? palette.textSecondary : ocupada ? AppColors.warning : AppColors.success;
    final actionColor = palette.secondary;
    final cuentas = mesa.numeroCuentas ?? 0;
    final pendiente = mesa.totalPendiente ?? 0;
    final cardColor = palette.darkBackground
        ? Color.lerp(palette.surface, stateColor, ocupada ? 0.10 : 0.045)!
        : Color.lerp(palette.surface, stateColor, ocupada ? 0.055 : 0.025)!;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Opacity(
          opacity: inactiva ? 0.62 : 1,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: stateColor.withOpacity(ocupada ? 0.40 : 0.22), width: ocupada ? 1.3 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(palette.darkBackground ? 0.18 : 0.06), blurRadius: 16, offset: const Offset(0, 7))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MesaNumberPhotoBadge(
                      mesaNumero: mesa.mesaNumero,
                      mesaFoto: mesa.mesaFoto,
                      size: 48,
                      radius: 14,
                      accentColor: stateColor,
                      backgroundColor: stateColor.withOpacity(0.12),
                      textColor: palette.textPrimary,
                      compact: true,
                      veryTight: true,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Mesa ${mesa.mesaNumero ?? '-'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16.5),
                                ),
                              ),
                              const SizedBox(width: 7),
                              _MesaStatusBadge(label: statusText, compact: true, color: stateColor),
                            ],
                          ),
                          if (descripcion.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              descripcion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: palette.textSecondary.withOpacity(0.82), fontWeight: FontWeight.w600, fontSize: 10.8),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (canEdit || canDelete)
                      PopupMenuButton<String>(
                        tooltip: 'Opciones de mesa',
                        icon: Icon(Icons.more_vert_rounded, color: palette.textSecondary, size: 21),
                        color: palette.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') (onDelete ?? onEdit)();
                        },
                        itemBuilder: (context) => [
                          if (canEdit)
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 9), Text('Editar mesa')]),
                            ),
                          if (canDelete)
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18), SizedBox(width: 9), Text('Eliminar o inactivar')]),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (ocupada) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: stateColor.withOpacity(0.16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: stateColor.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.payments_rounded, color: stateColor, size: 18),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PENDIENTE', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 9.1, letterSpacing: 0.45)),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyUtils.format(pendiente),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18.5, height: 1),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(color: palette.surface.withOpacity(0.55), borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            '$cuentas ${cuentas == 1 ? 'cuenta' : 'cuentas'}',
                            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 9.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _MesaQuickActionButton(
                          label: 'Continuar',
                          icon: Icons.arrow_forward_rounded,
                          onTap: onTap,
                          accentColor: actionColor,
                          filled: false,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _MesaQuickActionButton(
                          label: 'Cobrar',
                          icon: Icons.payments_rounded,
                          onTap: onPagar,
                          accentColor: actionColor,
                          filled: true,
                        ),
                      ),
                    ],
                  ),
                ] else if (inactiva) ...[
                  const Spacer(),
                  Center(child: Icon(Icons.visibility_off_rounded, size: 24, color: palette.textSecondary)),
                  const SizedBox(height: 4),
                  Center(child: Text('Mesa no disponible', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 12))),
                  const Spacer(),
                ] else ...[
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: stateColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.event_available_rounded, color: stateColor, size: 18),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sin venta activa', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 11.7)),
                            const SizedBox(height: 2),
                            Text('Disponible para atender', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 9.8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _MesaQuickActionButton(
                      label: 'Abrir venta',
                      icon: Icons.add_rounded,
                      onTap: onTap,
                      accentColor: actionColor,
                      filled: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MesaQuickActionButton extends ConsumerWidget {
  const _MesaQuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.accentColor,
    required this.filled,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color accentColor;
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            gradient: filled && enabled
                ? LinearGradient(
                    colors: [accentColor, Color.lerp(accentColor, palette.primary, 0.42) ?? accentColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: filled ? null : Colors.white.withOpacity(enabled ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: enabled
                  ? (filled ? accentColor.withOpacity(0.24) : accentColor.withOpacity(0.28))
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: filled && enabled
                ? [BoxShadow(color: accentColor.withOpacity(0.14), blurRadius: 10, offset: const Offset(0, 5))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? (filled ? Colors.white : accentColor) : Colors.white.withOpacity(0.32),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? (filled ? Colors.white : accentColor) : Colors.white.withOpacity(0.32),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1,
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

class _MesaInlineInfo extends StatelessWidget {
  const _MesaInlineInfo({
    required this.icon,
    required this.text,
    required this.color,
    this.emphasized = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
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
    final badgeSize = size < 70 ? 24.0 : 28.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.34), Colors.white.withOpacity(0.16)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: accentColor.withOpacity(0.24), blurRadius: 18, offset: const Offset(0, 9)),
                ],
              ),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundColor,
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: photo.isNotEmpty
                    ? _BarlyticsImage(value: photo, width: size, height: size)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [backgroundColor, accentColor.withOpacity(0.20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(Icons.table_restaurant_rounded, size: size * 0.42, color: accentColor),
                      ),
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF071A24),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(
                    number,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: badgeSize * 0.46,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MesaIconAction extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final size = compact ? 28.0 : 32.0;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        iconSize: compact ? 16 : 18,
        color: color ?? palette.textSecondary,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

class _MesaCardMetricBox extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final valueColor = emphasize ? palette.secondary : Colors.white;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(emphasize ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize ? palette.secondary.withOpacity(0.26) : Colors.white.withOpacity(0.09),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 12,
            color: emphasize ? palette.secondary : Colors.white.withOpacity(0.56),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.1,
                    color: Colors.white.withOpacity(0.52),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: valueColor,
                    fontWeight: FontWeight.w900,
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

class _MiniMesaMetric extends ConsumerWidget {
  const _MiniMesaMetric({required this.icon, required this.text, this.compact = false});

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: palette.glassSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.translucentBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 12 : 14, color: palette.secondary),
            SizedBox(width: compact ? 4 : 5),
            Text(text, style: TextStyle(fontSize: compact ? 10.8 : 12, fontWeight: FontWeight.w800, color: palette.textPrimary)),
          ],
        ),
      );
  }
}

class _MesaStatusBadge extends ConsumerWidget {
  const _MesaStatusBadge({required this.label, required this.compact, this.color});

  final String label;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final baseColor = color ?? palette.textSecondary;
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 116 : 136),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 5 : 6),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(palette.darkBackground ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: baseColor.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 7 : 8,
            height: compact ? 7 : 8,
            decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w900, color: baseColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumenOperativoHeader extends ConsumerWidget {
  const _ResumenOperativoHeader({
    required this.totalPendiente,
    required this.mesasEnCurso,
    required this.mesasLibres,
    required this.cuentasAbiertas,
    required this.onActualizar,
    required this.onVerMesas,
    required this.onVerProductos,
    this.onCobrarPrioridad,
  });

  final double totalPendiente;
  final int mesasEnCurso;
  final int mesasLibres;
  final int cuentasAbiertas;
  final Future<void> Function() onActualizar;
  final VoidCallback onVerMesas;
  final VoidCallback onVerProductos;
  final VoidCallback? onCobrarPrioridad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.titleBackground.withOpacity(0.98),
            Color.lerp(palette.titleBackground, palette.secondary, 0.24) ?? palette.titleBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.secondary.withOpacity(0.20)),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 800;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: palette.secondary.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.secondary.withOpacity(0.22)),
                    ),
                    child: Icon(Icons.space_dashboard_rounded, color: palette.secondary, size: 27),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Control del turno',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalPendiente > 0.009
                              ? 'Tienes ${CurrencyUtils.format(totalPendiente)} pendientes por cobrar.'
                              : 'No hay saldos pendientes. El salón está al día.',
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar resumen',
                    onPressed: () => onActualizar(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onVerMesas,
                    icon: const Icon(Icons.table_bar_rounded),
                    label: const Text('Gestionar mesas'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onVerProductos,
                    icon: const Icon(Icons.local_bar_rounded),
                    label: const Text('Consultar productos'),
                  ),
                  if (onCobrarPrioridad != null)
                    OutlinedButton.icon(
                      onPressed: onCobrarPrioridad,
                      icon: const Icon(Icons.payments_rounded),
                      label: const Text('Cobrar mayor saldo'),
                    ),
                ],
              ),
            ],
          );

          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ResumenHeaderMetric(
                icon: Icons.pending_actions_rounded,
                label: 'Por cobrar',
                value: CurrencyUtils.format(totalPendiente),
                emphasized: totalPendiente > 0.009,
              ),
              _ResumenHeaderMetric(
                icon: Icons.room_service_rounded,
                label: 'En atención',
                value: '$mesasEnCurso mesas',
              ),
              _ResumenHeaderMetric(
                icon: Icons.receipt_long_rounded,
                label: 'Cuentas abiertas',
                value: '$cuentasAbiertas',
              ),
              _ResumenHeaderMetric(
                icon: Icons.event_available_rounded,
                label: 'Mesas libres',
                value: '$mesasLibres',
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 18),
                metrics,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: intro),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: metrics),
            ],
          );
        },
      ),
    );
  }
}

class _ResumenHeaderMetric extends ConsumerWidget {
  const _ResumenHeaderMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final color = emphasized ? palette.primary : palette.secondary;
    return Container(
      width: 190,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.44 : 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(emphasized ? 0.34 : 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: emphasized ? color : palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumenSectionCard extends ConsumerWidget {
  const _ResumenSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 22, offset: const Offset(0, 10))],
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
                  color: palette.secondary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: palette.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ResumenSectionBadge extends ConsumerWidget {
  const _ResumenSectionBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.secondary.withOpacity(0.20)),
      ),
      child: Text(label, style: TextStyle(color: palette.secondary, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _ResumenEmptyState extends ConsumerWidget {
  const _ResumenEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.44 : 0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: palette.secondary, size: 30),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResumenMesaOperativaRow extends ConsumerWidget {
  const _ResumenMesaOperativaRow({
    required this.mesa,
    required this.onAbrir,
    this.onCobrar,
  });

  final MeseroMesaResumenModel mesa;
  final VoidCallback onAbrir;
  final VoidCallback? onCobrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final descripcion = (mesa.mesaDescripcion ?? '').trim();
    final saldo = mesa.totalPendiente ?? 0;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.64),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: saldo > 0.009 ? palette.primary.withOpacity(0.20) : palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final veryCompact = constraints.maxWidth < 420;
          final identity = Row(
            children: [
              _MesaNumberPhotoBadge(
                mesaNumero: mesa.mesaNumero,
                mesaFoto: mesa.mesaFoto,
                size: 48,
                radius: 17,
                accentColor: palette.secondary,
                backgroundColor: palette.secondary.withOpacity(0.16),
                textColor: palette.textPrimary,
                compact: false,
                veryTight: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mesa ${mesa.mesaNumero ?? '-'}', style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      descripcion.isEmpty ? '${mesa.numeroCuentas ?? 0} cuentas abiertas' : '$descripcion · ${mesa.numeroCuentas ?? 0} cuentas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          );

          final amount = Column(
            crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text('Saldo pendiente', style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                CurrencyUtils.format(saldo),
                style: TextStyle(color: saldo > 0.009 ? palette.primary : AppColors.success, fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAbrir,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('Abrir'),
              ),
              if (onCobrar != null)
                FilledButton.icon(
                  onPressed: onCobrar,
                  icon: const Icon(Icons.payments_rounded, size: 17),
                  label: const Text('Cobrar'),
                ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 12),
                if (veryCompact) ...[
                  amount,
                  const SizedBox(height: 10),
                  actions,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: amount),
                      actions,
                    ],
                  ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              amount,
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ResumenProductoDia {
  const _ResumenProductoDia({
    required this.nombre,
    required this.cantidad,
    required this.total,
  });

  final String nombre;
  final double cantidad;
  final double total;
}

class _ResumenActividadHoyCard extends ConsumerWidget {
  const _ResumenActividadHoyCard({
    required this.ventas,
    required this.cuentas,
    required this.totalVendido,
    required this.totalCobrado,
    required this.propinas,
    required this.productos,
    required this.onProductoTap,
  });

  final int ventas;
  final int cuentas;
  final double totalVendido;
  final double totalCobrado;
  final double propinas;
  final List<_ResumenProductoDia> productos;
  final ValueChanged<String> onProductoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return _ResumenSectionCard(
      icon: Icons.insights_rounded,
      title: 'Actividad de hoy',
      subtitle: 'Ventas cerradas y productos con mayor movimiento.',
      trailing: _ResumenSectionBadge(label: '$ventas ventas'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 440 ? (constraints.maxWidth - 10) / 2 : (constraints.maxWidth - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: itemWidth, child: _ResumenDiaMetric(label: 'Vendido', value: CurrencyUtils.format(totalVendido), icon: Icons.trending_up_rounded)),
                  SizedBox(width: itemWidth, child: _ResumenDiaMetric(label: 'Cobrado', value: CurrencyUtils.format(totalCobrado), icon: Icons.account_balance_wallet_rounded)),
                  SizedBox(width: itemWidth, child: _ResumenDiaMetric(label: 'Propinas', value: CurrencyUtils.format(propinas), icon: Icons.volunteer_activism_rounded)),
                  SizedBox(width: itemWidth, child: _ResumenDiaMetric(label: 'Cuentas', value: '$cuentas', icon: Icons.receipt_long_rounded)),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: palette.secondary, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text('Más pedidos hoy', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 10),
          if (productos.isEmpty)
            Text('Todavía no hay productos vendidos hoy.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))
          else
            for (var index = 0; index < productos.length; index++) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onProductoTap(productos[index].nombre),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: palette.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text('${index + 1}', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(productos[index].nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text('${_formatCantidadGeneral(productos[index].cantidad)} unidades', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(CurrencyUtils.format(productos[index].total), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: palette.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              if (index != productos.length - 1) Divider(height: 1, color: palette.cardBorder),
            ],
        ],
      ),
    );
  }
}

class _ResumenDiaMetric extends ConsumerWidget {
  const _ResumenDiaMetric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.secondary, size: 19),
          const SizedBox(height: 8),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _VentaInfoPanel extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final descripcion = (venta.mesaDescripcion ?? '').trim();
    final ventaDirecta = (venta.tipoVenta ?? '').trim().toUpperCase() == 'DIRECTA' || venta.mesaId == null;
    final cuentas = venta.cuentas.length;
    final productos = venta.cuentas.fold<int>(0, (sum, cuenta) => sum + cuenta.productos.length);
    final saldo = venta.saldoPendiente ?? 0;
    final pagada = venta.pagada == true || saldo <= 0.009;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.985),
            Color.lerp(palette.surface, palette.secondary, 0.07)?.withOpacity(
                  palette.darkBackground ? 0.96 : 0.99,
                ) ??
                palette.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.secondary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withOpacity(0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final profileSize = compact ? 72.0 : 84.0;

          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ventaDirecta
                  ? Container(
                      width: profileSize,
                      height: profileSize,
                      decoration: BoxDecoration(
                        color: palette.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(profileSize * 0.32),
                      ),
                      child: Icon(Icons.point_of_sale_rounded, color: palette.secondary, size: profileSize * 0.46),
                    )
                  : _MesaNumberPhotoBadge(
                      mesaNumero: venta.mesaNumero,
                      mesaFoto: venta.mesaFoto,
                      size: profileSize,
                      radius: profileSize / 2,
                      accentColor: palette.secondary,
                      backgroundColor: palette.background.withOpacity(0.72),
                      textColor: Colors.white,
                      compact: compact,
                      veryTight: compact,
                    ),
              SizedBox(width: compact ? 14 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ventaDirecta ? 'Venta directa' : 'Mesa ${venta.mesaNumero ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 23 : 27,
                            height: 1,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _VentaMetaChip(
                          icon: ventaDirecta ? Icons.storefront_rounded : Icons.receipt_long_rounded,
                          label: ventaDirecta ? 'Mostrador · Venta #${venta.ventaId ?? '-'}' : 'Venta #${venta.ventaId ?? '-'}',
                        ),
                        if (descripcion.isNotEmpty)
                          _VentaMetaChip(
                            icon: Icons.notes_rounded,
                            label: descripcion,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final total = Container(
            constraints: BoxConstraints(minWidth: compact ? 0 : 205),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.76),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.secondary.withOpacity(0.16)),
            ),
            child: Column(
              crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(
                  pagada ? 'Total pagado' : 'Total de la venta',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  CurrencyUtils.format(venta.total),
                  style: TextStyle(
                    color: palette.secondary,
                    fontSize: compact ? 25 : 30,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                _ResumenEstadoVentaChip(
                  label: pagada ? 'Pagada' : 'Saldo pendiente',
                  danger: !pagada,
                ),
              ],
            ),
          );

          final summary = _VentaResumenGrid(
            items: [
              _VentaResumenItem(
                icon: Icons.groups_2_rounded,
                label: 'Cuentas',
                value: '$cuentas',
              ),
              _VentaResumenItem(
                icon: Icons.shopping_bag_rounded,
                label: 'Productos',
                value: '$productos',
              ),
              _VentaResumenItem(
                icon: Icons.check_circle_outline_rounded,
                label: 'Pagado',
                value: CurrencyUtils.format(venta.totalPagado),
              ),
              _VentaResumenItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Saldo',
                value: CurrencyUtils.format(saldo),
                danger: saldo > 0.009,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: total),
                const SizedBox(height: 16),
                summary,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 20),
                  total,
                ],
              ),
              const SizedBox(height: 18),
              summary,
            ],
          );
        },
      ),
    );
  }
}

class _VentaMetaChip extends ConsumerWidget {
  const _VentaMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.72),
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
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumenEstadoVentaChip extends ConsumerWidget {
  const _ResumenEstadoVentaChip({required this.label, required this.danger});

  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final color = danger ? palette.primary : AppColors.success;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(danger ? Icons.pending_actions_rounded : Icons.check_circle_rounded, color: color, size: 16),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: danger ? color : (palette.darkBackground ? color : AppColors.success), fontWeight: FontWeight.w900, fontSize: 12)),
      ],
    );
  }
}

class _VentaResumenItem {
  const _VentaResumenItem({
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool danger;
}

class _VentaResumenGrid extends ConsumerWidget {
  const _VentaResumenGrid({required this.items});

  final List<_VentaResumenItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : 4;
        final gap = 10.0;
        final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _VentaResumenTile(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _VentaResumenTile extends ConsumerWidget {
  const _VentaResumenTile({required this.item});

  final _VentaResumenItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final valueColor = item.danger ? AppColors.danger : palette.textPrimary;
    final iconColor = item.danger ? AppColors.danger : palette.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.34 : 0.70),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: item.danger
              ? AppColors.danger.withOpacity(0.18)
              : palette.secondary.withOpacity(0.11),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
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
        color: palette.background.withOpacity(palette.darkBackground ? 0.44 : 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.translucentBorder),
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

class _CuentaSelectorCard extends ConsumerWidget {
  const _CuentaSelectorCard({required this.cuenta, required this.selected, required this.onTap});

  final MeseroCuentaModel cuenta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final descripcion = (cuenta.descripcion ?? '').trim();
    return Material(
      color: selected ? palette.secondary.withOpacity(0.12) : palette.background.withOpacity(palette.darkBackground ? 0.48 : 0.70),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? palette.secondary : palette.cardBorder, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? palette.secondary : palette.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cuentaNombreVisible(cuenta),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: palette.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                descripcion.isEmpty ? 'Sin descripción' : descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: descripcion.isEmpty ? palette.textSecondary.withOpacity(0.75) : palette.textSecondary, fontWeight: FontWeight.w600),
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


class _CuentasTabMenu extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
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
          color: palette.background.withOpacity(palette.darkBackground ? 0.34 : 0.72),
          borderRadius: BorderRadius.circular(compact ? 22 : 24),
          border: Border.all(color: palette.secondary.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: palette.cardShadow.withOpacity(0.14),
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

class _CuentaSelectorTab extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final saldo = cuenta.saldoPendiente ?? 0;
    final pagada = cuenta.pagada == true;
    final colorActivo = palette.secondary;
    final colorInactivo = palette.textSecondary;
    final colorEstado = pagada ? AppColors.success : palette.secondary;
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
                constraints: BoxConstraints(minHeight: compact ? 82 : 88),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: compact ? 8 : 10,
                ).copyWith(right: canDelete ? (compact ? 24 : 28) : null),
                decoration: BoxDecoration(
                  color: selected ? palette.secondary.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected ? palette.secondary.withOpacity(0.34) : Colors.transparent,
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
                    Icon(icon, size: compact ? 21 : 23, color: selected ? colorActivo : colorInactivo),
                    const SizedBox(height: 4),
                    Text(
                      _cuentaNombreVisible(cuenta),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? colorActivo : palette.textPrimary,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalPill extends ConsumerWidget {
  const _TotalPill({required this.total});
  final num? total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(palette.darkBackground ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.secondary.withOpacity(0.22)),
      ),
      child: Text(CurrencyUtils.format(total), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
    );
  }
}


class _CuentaDetalle extends ConsumerWidget {
  const _CuentaDetalle({
    required this.cuenta,
    this.onAgregarProductos,
    this.onIncrementarProducto,
    this.onDisminuirProducto,
    this.onSumarCantidadProducto,
    this.productoActualizando,
    this.onEliminarProducto,
    this.onMoverProducto,
    this.onPagarCuenta,
    this.onEliminarPago,
    this.onFinalizarVenta,
    this.onLimpiarVentaSinConsumos,
  });

  final MeseroCuentaModel cuenta;
  final VoidCallback? onAgregarProductos;
  final ValueChanged<MeseroDetalleProductoModel>? onIncrementarProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onDisminuirProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onSumarCantidadProducto;
  final bool Function(MeseroDetalleProductoModel)? productoActualizando;
  final ValueChanged<MeseroDetalleProductoModel>? onEliminarProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onMoverProducto;
  final VoidCallback? onPagarCuenta;
  final ValueChanged<MeseroPagoModel>? onEliminarPago;
  final VoidCallback? onFinalizarVenta;
  final VoidCallback? onLimpiarVentaSinConsumos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final nombreCuenta = _cuentaNombreVisible(cuenta);

    final productosPanel = _PosSectionPanel(
      icon: Icons.shopping_cart_checkout_rounded,
      title: 'Productos solicitados',
      subtitle: cuenta.productos.isEmpty
          ? 'Aún no hay productos en esta cuenta.'
          : '${cuenta.productos.length} ${cuenta.productos.length == 1 ? 'producto registrado' : 'productos registrados'}',
      trailing: FilledButton.icon(
        onPressed: onAgregarProductos,
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: const Text('Agregar productos'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(174, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      child: cuenta.productos.isEmpty
          ? _PosEmptyProducts(onAgregarProductos: onAgregarProductos)
          : _CuentaProductosTabla(
              cuenta: cuenta,
              productos: cuenta.productos,
              showTotals: false,
              onIncrementarProducto: onIncrementarProducto,
              onDisminuirProducto: onDisminuirProducto,
              onSumarCantidadProducto: onSumarCantidadProducto,
              productoActualizando: productoActualizando,
              onEliminarProducto: onEliminarProducto,
              onMoverProducto: onMoverProducto,
            ),
    );

    final pagosPanel = _PosSectionPanel(
      icon: Icons.payments_outlined,
      title: 'Pagos registrados',
      subtitle: cuenta.pagos.isEmpty
          ? 'Todavía no se han registrado pagos.'
          : '${cuenta.pagos.length} ${cuenta.pagos.length == 1 ? 'pago aplicado' : 'pagos aplicados'}',
      trailing: _PosCountBadge(
        icon: Icons.receipt_long_rounded,
        text: '${cuenta.pagos.length}',
      ),
      child: cuenta.pagos.isEmpty
          ? const _CuentaEmptySection(
              icon: Icons.payments_outlined,
              message: 'Esta cuenta todavía no tiene pagos registrados.',
            )
          : Column(
              children: [
                for (var i = 0; i < cuenta.pagos.length; i++)
                  _CuentaPagoRegistradoTile(
                    pago: cuenta.pagos[i],
                    last: i == cuenta.pagos.length - 1,
                    onEliminar: onEliminarPago == null ? null : () => onEliminarPago!(cuenta.pagos[i]),
                  ),
              ],
            ),
    );

    final checkoutPanel = _PosCheckoutPanel(
      nombreCuenta: nombreCuenta,
      cuenta: cuenta,
      onPagarCuenta: onPagarCuenta,
      onFinalizarVenta: onFinalizarVenta,
      onLimpiarVentaSinConsumos: onLimpiarVentaSinConsumos,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // En escritorio se prioriza mantener el resumen de cobro visible al lado.
        // La tabla de productos se adapta internamente a un modo compacto cuando
        // el panel izquierdo queda más angosto. En móvil sí apilamos todo.
        final sideCheckout = constraints.maxWidth >= 920;
        if (!sideCheckout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              productosPanel,
              const SizedBox(height: 14),
              checkoutPanel,
              const SizedBox(height: 14),
              pagosPanel,
            ],
          );
        }

        final checkoutWidth = constraints.maxWidth >= 1320
            ? 360.0
            : constraints.maxWidth >= 1120
                ? 330.0
                : 300.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  productosPanel,
                  const SizedBox(height: 14),
                  pagosPanel,
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: checkoutWidth, child: checkoutPanel),
          ],
        );
      },
    );
  }
}

class _PosSectionPanel extends ConsumerWidget {
  const _PosSectionPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.94 : 0.985),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.secondary.withOpacity(0.13)),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final heading = Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: palette.secondary.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: palette.secondary, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (trailing == null) return heading;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      const SizedBox(height: 12),
                      trailing!,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: palette.cardBorder.withOpacity(0.78)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PosEmptyProducts extends ConsumerWidget {
  const _PosEmptyProducts({this.onAgregarProductos});

  final VoidCallback? onAgregarProductos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.secondary.withOpacity(0.11)),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_bar_outlined, color: palette.secondary, size: 27),
          ),
          const SizedBox(height: 12),
          Text(
            'La cuenta está lista para recibir productos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Agrega las bebidas o productos solicitados por el cliente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAgregarProductos,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar primer producto'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(210, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosCountBadge extends ConsumerWidget {
  const _PosCountBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.secondary.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: palette.secondary, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: palette.secondary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosCheckoutPanel extends ConsumerWidget {
  const _PosCheckoutPanel({
    required this.nombreCuenta,
    required this.cuenta,
    this.onPagarCuenta,
    this.onFinalizarVenta,
    this.onLimpiarVentaSinConsumos,
  });

  final String nombreCuenta;
  final MeseroCuentaModel cuenta;
  final VoidCallback? onPagarCuenta;
  final VoidCallback? onFinalizarVenta;
  final VoidCallback? onLimpiarVentaSinConsumos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final saldo = cuenta.saldoPendiente ?? 0;
    final pagada = cuenta.pagada == true || saldo <= 0.009;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.96 : 0.99),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.secondary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CuentaDetalleHeader(nombreCuenta: nombreCuenta, cuenta: cuenta),
          const SizedBox(height: 16),
          Text(
            'Resumen para cobrar',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          _PosAmountRow(
            label: 'Productos',
            value: CurrencyUtils.format(cuenta.subtotalProductos),
          ),
          _PosAmountRow(
            label: 'Propina',
            value: CurrencyUtils.format(cuenta.propina),
          ),
          _PosAmountRow(
            label: 'Pagado',
            value: CurrencyUtils.format(cuenta.totalPagado),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: palette.cardBorder),
          ),
          _PosAmountRow(
            label: 'Total de la cuenta',
            value: CurrencyUtils.format(cuenta.total),
            strong: true,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pagada
                  ? AppColors.success.withOpacity(0.10)
                  : palette.primary.withOpacity(0.11),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: pagada
                    ? AppColors.success.withOpacity(0.20)
                    : palette.primary.withOpacity(0.20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  pagada ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded,
                  color: pagada ? AppColors.success : palette.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pagada ? 'Cuenta pagada' : 'Saldo pendiente',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        CurrencyUtils.format(saldo),
                        style: TextStyle(
                          color: pagada ? AppColors.success : palette.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 23,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PosCashierActions(
            cuenta: cuenta,
            onPagarCuenta: onPagarCuenta,
            onFinalizarVenta: onFinalizarVenta,
            onLimpiarVentaSinConsumos: onLimpiarVentaSinConsumos,
          ),
        ],
      ),
    );
  }
}

class _CuentaDetalleHeader extends ConsumerWidget {
  const _CuentaDetalleHeader({required this.nombreCuenta, required this.cuenta});

  final String nombreCuenta;
  final MeseroCuentaModel cuenta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final descripcion = (cuenta.descripcion ?? '').trim();
    final saldo = cuenta.saldoPendiente ?? 0;
    final pagada = cuenta.pagada == true || saldo <= 0.009;
    final statusColor = pagada ? AppColors.success : palette.secondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  pagada ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreCuenta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      descripcion.isEmpty ? 'Sin descripción' : descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PosSmallChip(
                icon: Icons.shopping_bag_outlined,
                text: '${cuenta.productos.length} productos',
              ),
              _PosSmallChip(
                icon: pagada ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
                text: pagada ? 'Pagada' : 'Pendiente',
                color: statusColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PosSmallChip extends ConsumerWidget {
  const _PosSmallChip({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final chipColor = color ?? palette.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: chipColor, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosAmountRow extends ConsumerWidget {
  const _PosAmountRow({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? palette.textPrimary : palette.textSecondary,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              color: strong ? palette.secondary : palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: strong ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosCashierActions extends ConsumerWidget {
  const _PosCashierActions({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final saldo = cuenta.saldoPendiente ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onPagarCuenta,
          icon: const Icon(Icons.payments_rounded, size: 22),
          label: Text(
            saldo > 0.009
                ? 'Cobrar ${CurrencyUtils.format(saldo)}'
                : 'Registrar pago',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          ),
        ),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: onFinalizarVenta,
          icon: const Icon(Icons.check_circle_outline_rounded, size: 21),
          label: const Text('Finalizar venta'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: AppColors.success,
            side: BorderSide(color: AppColors.success.withOpacity(0.30)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        if (onLimpiarVentaSinConsumos != null) ...[
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: onLimpiarVentaSinConsumos,
            icon: const Icon(Icons.event_available_rounded, size: 21),
            label: const Text('Liberar mesa'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: palette.secondary,
              side: BorderSide(color: palette.secondary.withOpacity(0.28)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ],
    );
  }
}

class _CuentaSectionCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(color: palette.secondary, borderRadius: BorderRadius.circular(999)),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: palette.secondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary)),
                    const SizedBox(height: 1),
                    Text(description, style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 2),
          Divider(height: 22, color: palette.cardBorder),
        ],
      ),
    );
  }
}

class _CuentaEmptySection extends ConsumerWidget {
  const _CuentaEmptySection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.50 : 0.68), borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.cardBorder)),
      child: Row(
        children: [
          Icon(icon, color: palette.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}


class _CuentaPagoRegistradoTile extends ConsumerWidget {
  const _CuentaPagoRegistradoTile({required this.pago, this.last = false, this.onEliminar});

  final MeseroPagoModel pago;
  final bool last;
  final VoidCallback? onEliminar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final tieneRecibido = pago.valorRecibido != null;

    return Container(
      padding: EdgeInsets.fromLTRB(0, 12, 0, last ? 4 : 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments_rounded, color: AppColors.success, size: 20),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tieneRecibido
                      ? 'Recibido ${CurrencyUtils.format(pago.valorRecibido)} · Vueltas ${CurrencyUtils.format(pago.cambio ?? 0)}'
                      : 'Pago aplicado a la cuenta',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyUtils.format(pago.valor),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: palette.secondary,
                ),
              ),
              if (onEliminar != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: onEliminar,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 30),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Eliminar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}


class _CuentaPagosTable extends ConsumerWidget {
  const _CuentaPagosTable({required this.pagos});

  final List<MeseroPagoModel> pagos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.28 : 0.66),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder.withOpacity(0.82)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 760
              ? constraints.maxWidth
              : 760.0;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 58,
                horizontalMargin: 14,
                columnSpacing: 24,
                headingRowColor: WidgetStatePropertyAll(
                  palette.secondary.withOpacity(palette.darkBackground ? 0.09 : 0.06),
                ),
                headingTextStyle: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
                dataTextStyle: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
                columns: const [
                  DataColumn(label: Text('Medio de pago')),
                  DataColumn(label: Text('Valor'), numeric: true),
                  DataColumn(label: Text('Recibido'), numeric: true),
                  DataColumn(label: Text('Vueltas'), numeric: true),
                  DataColumn(label: Text('Estado')),
                ],
                rows: pagos.map((pago) {
                  final tieneRecibido = pago.valorRecibido != null;
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payments_rounded, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Text(pago.medioPagoNombre ?? 'Medio ${pago.medioPagoId ?? '-'}'),
                          ],
                        ),
                      ),
                      DataCell(Text(CurrencyUtils.format(pago.valor))),
                      DataCell(Text(tieneRecibido ? CurrencyUtils.format(pago.valorRecibido) : '—')),
                      DataCell(Text(tieneRecibido ? CurrencyUtils.format(pago.cambio ?? 0) : '—')),
                      const DataCell(_PagoAplicadoChip()),
                    ],
                  );
                }).toList(growable: false),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PagoAplicadoChip extends StatelessWidget {
  const _PagoAplicadoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.success.withOpacity(0.24)),
      ),
      child: const Text(
        'Aplicado',
        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }
}

class _CuentaProductosTabla extends ConsumerWidget {
  const _CuentaProductosTabla({
    required this.cuenta,
    required this.productos,
    this.showTotals = true,
    this.onIncrementarProducto,
    this.onDisminuirProducto,
    this.onSumarCantidadProducto,
    this.productoActualizando,
    this.onEliminarProducto,
    this.onMoverProducto,
  });

  final MeseroCuentaModel cuenta;
  final List<MeseroDetalleProductoModel> productos;
  final bool showTotals;
  final ValueChanged<MeseroDetalleProductoModel>? onIncrementarProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onDisminuirProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onSumarCantidadProducto;
  final bool Function(MeseroDetalleProductoModel)? productoActualizando;
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
            final mobileCards = constraints.maxWidth < 600;
            final compactTable = constraints.maxWidth < 980;

            if (mobileCards) {
              return Column(
                children: [
                  ...productos.map(
                    (producto) => _CuentaProductoMobileRow(
                      producto: producto,
                      palette: palette,
                      onIncrementarProducto: onIncrementarProducto,
                      onDisminuirProducto: onDisminuirProducto,
                      onSumarCantidadProducto: onSumarCantidadProducto,
                      actualizando: productoActualizando?.call(producto) ?? false,
                      onEliminarProducto: onEliminarProducto,
                      onMoverProducto: onMoverProducto,
                    ),
                  ),
                  if (showTotals) _CuentaTotalesBajoTabla(cuenta: cuenta, compact: true),
                ],
              );
            }

            return SizedBox(
              width: constraints.maxWidth,
              child: Column(
                children: [
                  compactTable ? _buildCompactHeader(palette) : _buildHeader(palette),
                  ...productos.map(
                    (producto) => compactTable
                        ? _buildCompactRow(producto, palette)
                        : _buildRow(producto, palette),
                  ),
                  if (showTotals) _CuentaTotalesBajoTabla(cuenta: cuenta, compact: compactTable),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactHeader(AppPalette palette) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(palette.darkBackground ? 0.16 : 0.08),
        border: Border(bottom: BorderSide(color: palette.cardBorder)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 48, child: _CuentaProductoHeaderCell('Foto')),
          Expanded(flex: 4, child: _CuentaProductoHeaderCell('Producto')),
          SizedBox(width: 8),
          SizedBox(width: 122, child: _CuentaProductoHeaderCell('Cantidad')),
          SizedBox(width: 8),
          SizedBox(width: 82, child: _CuentaProductoHeaderCell('Total', alignEnd: true)),
          SizedBox(width: 10),
          SizedBox(width: 80, child: _CuentaProductoHeaderCell('Estado')),
          SizedBox(width: 8),
          SizedBox(width: 72, child: _CuentaProductoHeaderCell('Acciones', alignEnd: true)),
        ],
      ),
    );
  }

  Widget _buildCompactRow(MeseroDetalleProductoModel producto, AppPalette palette) {
    final pagado = producto.pagado == true;
    final actualizando = productoActualizando?.call(producto) ?? false;
    final puedeIncrementar = !pagado && !actualizando && onIncrementarProducto != null;
    final puedeDisminuir = !pagado && !actualizando && onDisminuirProducto != null;
    final puedeSumarCantidad = !pagado && !actualizando && onSumarCantidadProducto != null;
    final puedeEliminar = !pagado && !actualizando && onEliminarProducto != null;
    final puedeMover = !pagado && !actualizando && onMoverProducto != null;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Row(
        children: [
          SizedBox(width: 48, child: _ProductImageThumb(value: producto.productoFoto, size: 40)),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Tooltip(
                  message: pagado ? 'Producto ya pagado' : 'Producto pendiente de pago',
                  child: Icon(
                    pagado ? Icons.lock_rounded : Icons.lock_open_rounded,
                    size: 16,
                    color: pagado ? AppColors.textSecondary : AppColors.secondaryDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 122,
            child: _ProductoCantidadStepper(
              cantidad: producto.cantidad ?? 0,
              habilitado: !pagado && !actualizando,
              cargando: actualizando,
              onDisminuir: puedeDisminuir ? () => onDisminuirProducto!(producto) : null,
              onIncrementar: puedeIncrementar ? () => onIncrementarProducto!(producto) : null,
              onCantidadTap: puedeSumarCantidad ? () => onSumarCantidadProducto!(producto) : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: _CuentaProductoValueCell(
              CurrencyUtils.format(producto.subtotal),
              alignEnd: true,
              strong: true,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _EstadoPagoChip(pagado: pagado),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    maximumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: pagado ? 'No se puede mover porque ya fue pagado' : 'Pasar producto a otra cuenta',
                  onPressed: puedeMover ? () => onMoverProducto!(producto) : null,
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    maximumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
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
          SizedBox(width: 152, child: _CuentaProductoHeaderCell('Cantidad')),
          SizedBox(width: 14),
          SizedBox(width: 112, child: _CuentaProductoHeaderCell('Unitario', alignEnd: true)),
          SizedBox(width: 14),
          SizedBox(width: 118, child: _CuentaProductoHeaderCell('Total', alignEnd: true)),
          SizedBox(width: 18),
          SizedBox(width: 110, child: _CuentaProductoHeaderCell('Estado')),
          SizedBox(width: 14),
          SizedBox(width: 92, child: _CuentaProductoHeaderCell('Acciones', alignEnd: true)),
        ],
      ),
    );
  }

  Widget _buildRow(MeseroDetalleProductoModel producto, AppPalette palette) {
    final pagado = producto.pagado == true;
    final actualizando = productoActualizando?.call(producto) ?? false;
    final puedeIncrementar = !pagado && !actualizando && onIncrementarProducto != null;
    final puedeDisminuir = !pagado && !actualizando && onDisminuirProducto != null;
    final puedeSumarCantidad = !pagado && !actualizando && onSumarCantidadProducto != null;
    final puedeEliminar = !pagado && !actualizando && onEliminarProducto != null;
    final puedeMover = !pagado && !actualizando && onMoverProducto != null;

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
          SizedBox(
            width: 152,
            child: _ProductoCantidadStepper(
              cantidad: producto.cantidad ?? 0,
              habilitado: !pagado && !actualizando,
              cargando: actualizando,
              onDisminuir: puedeDisminuir ? () => onDisminuirProducto!(producto) : null,
              onIncrementar: puedeIncrementar ? () => onIncrementarProducto!(producto) : null,
              onCantidadTap: puedeSumarCantidad ? () => onSumarCantidadProducto!(producto) : null,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(width: 112, child: _CuentaProductoValueCell(CurrencyUtils.format(producto.valorUnitario), alignEnd: true)),
          const SizedBox(width: 14),
          SizedBox(width: 118, child: _CuentaProductoValueCell(CurrencyUtils.format(producto.subtotal), alignEnd: true, strong: true)),
          const SizedBox(width: 18),
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _EstadoPagoChip(pagado: pagado),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 92,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    minimumSize: const Size(34, 34),
                    maximumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  visualDensity: VisualDensity.compact,
                  iconSize: 19,
                  tooltip: pagado ? 'No se puede mover porque ya fue pagado' : 'Pasar producto a otra cuenta',
                  onPressed: puedeMover ? () => onMoverProducto!(producto) : null,
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    minimumSize: const Size(34, 34),
                    maximumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  visualDensity: VisualDensity.compact,
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


class _CuentaTotalesBajoTabla extends ConsumerWidget {
  const _CuentaTotalesBajoTabla({required this.cuenta, this.compact = false});

  final MeseroCuentaModel cuenta;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final saldo = cuenta.saldoPendiente ?? 0;
    final items = [
      _CuentaResumenDato(label: 'Productos', value: CurrencyUtils.format(cuenta.subtotalProductos)),
      _CuentaResumenDato(label: 'Propina', value: CurrencyUtils.format(cuenta.propina)),
      _CuentaResumenDato(label: 'Pagado', value: CurrencyUtils.format(cuenta.totalPagado), highlighted: true),
      _CuentaResumenDato(label: 'Saldo', value: CurrencyUtils.format(cuenta.saldoPendiente), danger: saldo > 0.009),
      _CuentaResumenDato(label: 'Total', value: CurrencyUtils.format(cuenta.total), strong: true),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 12 : 13),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.55),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useWrap = compact || constraints.maxWidth < 760;
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.summarize_rounded, color: palette.secondary, size: 18),
              const SizedBox(width: 7),
              Text('Totales de cuenta', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
            ],
          );

          if (useWrap) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: items.map((item) => SizedBox(width: 132, child: item)).toList(growable: false),
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 160, child: title),
              Expanded(
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) VerticalDivider(width: 24, color: palette.cardBorder),
                        Expanded(child: items[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CuentaResumenDato extends ConsumerWidget {
  const _CuentaResumenDato({
    required this.label,
    required this.value,
    this.highlighted = false,
    this.strong = false,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool highlighted;
  final bool strong;
  final bool danger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final Color valueColor = danger
        ? AppColors.danger
        : strong || highlighted
            ? palette.secondary
            : palette.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: palette.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: strong ? 15 : 14, fontWeight: FontWeight.w900, color: valueColor),
        ),
      ],
    );
  }
}

class _ProductoCantidadStepper extends ConsumerWidget {
  const _ProductoCantidadStepper({
    required this.cantidad,
    required this.habilitado,
    this.onDisminuir,
    this.onIncrementar,
    this.onCantidadTap,
    this.expandido = false,
    this.cargando = false,
  });

  final num cantidad;
  final bool habilitado;
  final VoidCallback? onDisminuir;
  final VoidCallback? onIncrementar;
  final VoidCallback? onCantidadTap;
  final bool expandido;
  final bool cargando;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final puedeDisminuir = habilitado && !cargando && onDisminuir != null;
    final puedeIncrementar = habilitado && !cargando && onIncrementar != null;
    final puedeEditar = habilitado && !cargando && onCantidadTap != null;
    final compacto = !expandido;

    final quantityButton = Semantics(
      button: puedeEditar,
      label: puedeEditar ? 'Sumar varias unidades' : 'Cantidad actual',
      child: Material(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.46 : 0.72),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: puedeEditar ? onCantidadTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: expandido ? 86 : 46,
              maxWidth: expandido ? double.infinity : 46,
              minHeight: compacto ? 28 : 32,
            ),
            child: Center(
              child: cargando
                  ? SizedBox(
                      width: compacto ? 16 : 18,
                      height: compacto ? 16 : 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: palette.secondary),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatCantidadGeneral(cantidad),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: habilitado ? palette.textPrimary : palette.textSecondary,
                              fontWeight: FontWeight.w900,
                              fontSize: compacto ? 13 : 14,
                            ),
                          ),
                          if (puedeEditar) ...[
                            SizedBox(width: compacto ? 3 : 5),
                            Icon(
                              Icons.edit_rounded,
                              size: compacto ? 12 : 14,
                              color: palette.secondary,
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );

    return Container(
      width: expandido ? double.infinity : null,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.48 : 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.secondary.withOpacity(habilitado ? 0.22 : 0.10)),
      ),
      child: Row(
        mainAxisSize: expandido ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _CantidadStepperButton(
            semanticLabel: cantidad <= 1 ? 'Quitar producto de la cuenta' : 'Disminuir cantidad',
            icon: cantidad <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            onTap: puedeDisminuir ? onDisminuir : null,
            palette: palette,
            size: compacto ? 28 : 34,
            iconSize: compacto ? 17 : 19,
          ),
          if (expandido) const Spacer() else const SizedBox(width: 3),
          quantityButton,
          if (expandido) const Spacer() else const SizedBox(width: 3),
          _CantidadStepperButton(
            semanticLabel: 'Aumentar una unidad',
            icon: Icons.add_rounded,
            onTap: puedeIncrementar ? onIncrementar : null,
            palette: palette,
            destacado: true,
            size: compacto ? 28 : 34,
            iconSize: compacto ? 17 : 19,
          ),
        ],
      ),
    );
  }
}

class _CantidadStepperButton extends StatelessWidget {
  const _CantidadStepperButton({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    required this.palette,
    this.destacado = false,
    this.size = 34,
    this.iconSize = 19,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onTap;
  final AppPalette palette;
  final bool destacado;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: enabled,
      child: Material(
        color: enabled
            ? (destacado ? palette.primary.withOpacity(0.18) : palette.surface.withOpacity(0.72))
            : palette.surface.withOpacity(0.28),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: iconSize,
              color: enabled
                  ? (destacado ? palette.primary : palette.textPrimary)
                  : palette.textSecondary.withOpacity(0.42),
            ),
          ),
        ),
      ),
    );
  }
}

class _CuentaProductoMobileRow extends StatelessWidget {
  const _CuentaProductoMobileRow({
    required this.producto,
    required this.palette,
    this.onIncrementarProducto,
    this.onDisminuirProducto,
    this.onSumarCantidadProducto,
    this.actualizando = false,
    this.onEliminarProducto,
    this.onMoverProducto,
  });

  final MeseroDetalleProductoModel producto;
  final AppPalette palette;
  final ValueChanged<MeseroDetalleProductoModel>? onIncrementarProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onDisminuirProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onSumarCantidadProducto;
  final bool actualizando;
  final ValueChanged<MeseroDetalleProductoModel>? onEliminarProducto;
  final ValueChanged<MeseroDetalleProductoModel>? onMoverProducto;

  @override
  Widget build(BuildContext context) {
    final pagado = producto.pagado == true;
    final puedeIncrementar = !pagado && !actualizando && onIncrementarProducto != null;
    final puedeDisminuir = !pagado && !actualizando && onDisminuirProducto != null;
    final puedeSumarCantidad = !pagado && !actualizando && onSumarCantidadProducto != null;
    final puedeEliminar = !pagado && !actualizando && onEliminarProducto != null;
    final puedeMover = !pagado && !actualizando && onMoverProducto != null;

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
          _ProductoCantidadStepper(
            cantidad: producto.cantidad ?? 0,
            habilitado: !pagado && !actualizando,
            cargando: actualizando,
            expandido: true,
            onDisminuir: puedeDisminuir ? () => onDisminuirProducto!(producto) : null,
            onIncrementar: puedeIncrementar ? () => onIncrementarProducto!(producto) : null,
            onCantidadTap: puedeSumarCantidad ? () => onSumarCantidadProducto!(producto) : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MobileMiniMetric(label: 'Unitario', value: CurrencyUtils.format(producto.valorUnitario))),
              const SizedBox(width: 8),
              Expanded(child: _MobileMiniMetric(label: 'Total', value: CurrencyUtils.format(producto.subtotal), alignEnd: true)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              Widget moveButton = OutlinedButton.icon(
                onPressed: puedeMover ? () => onMoverProducto!(producto) : null,
                icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                label: const Text('Mover'),
              );
              Widget deleteButton = OutlinedButton.icon(
                onPressed: puedeEliminar ? () => onEliminarProducto!(producto) : null,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Eliminar'),
              );
              if (constraints.maxWidth < 230) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    moveButton,
                    const SizedBox(height: 8),
                    deleteButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: moveButton),
                  const SizedBox(width: 8),
                  Expanded(child: deleteButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EstadoPagoChip extends ConsumerWidget {
  const _EstadoPagoChip({required this.pagado});

  final bool pagado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final statusColor = pagado ? AppColors.success : palette.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: statusColor.withOpacity(0.26)),
      ),
      child: Text(
        pagado ? 'Pagado' : 'Pendiente',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: statusColor,
        ),
      ),
    );
  }
}

class _CuentaProductoHeaderCell extends ConsumerWidget {
  const _CuentaProductoHeaderCell(this.text, {this.alignEnd = false});

  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: palette.textSecondary),
      ),
    );
  }
}

class _CuentaProductoValueCell extends ConsumerWidget {
  const _CuentaProductoValueCell(this.text, {this.alignEnd = false, this.strong = false});

  final String text;
  final bool alignEnd;
  final bool strong;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          color: strong ? palette.textPrimary : palette.textSecondary,
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
      ),
      _CuentaActionButton(
        icon: Icons.check_circle_rounded,
        title: 'Finalizar venta',
        subtitle: onFinalizarVenta == null ? 'Pendiente' : 'Cerrar venta',
        colors: const [AppColors.success, AppColors.primary],
        onTap: onFinalizarVenta,
      ),
      if (onLimpiarVentaSinConsumos != null)
        _CuentaActionButton(
          icon: Icons.event_available_rounded,
          title: 'Liberar mesa',
          subtitle: 'Sin consumos',
          colors: const [AppColors.danger, AppColors.secondaryDark],
          onTap: onLimpiarVentaSinConsumos,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final usarColumna = constraints.maxWidth < 560;
        if (usarColumna) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < acciones.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                acciones[i],
              ],
            ],
          );
        }

        return Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: acciones.map((accion) => SizedBox(width: 190, child: accion)).toList(growable: false),
        );
      },
    );
  }
}

class _CuentaActionButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final enabled = onTap != null;
    final color = enabled ? colors.last : palette.textSecondary;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: enabled ? color.withOpacity(0.42) : palette.cardBorder),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: enabled ? palette.textPrimary : palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(enabled ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded, size: 18, color: color),
        ],
      ),
    );
  }
}

class _ProductosCatalogoResumen extends ConsumerWidget {
  const _ProductosCatalogoResumen({
    required this.total,
    required this.visibles,
    required this.tipos,
    required this.marcas,
    required this.precioDesde,
  });

  final int total;
  final int visibles;
  final int tipos;
  final int marcas;
  final double? precioDesde;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final metrics = <Widget>[
      _CatalogoMetric(icon: Icons.inventory_2_outlined, label: 'Catálogo', value: '$total'),
      _CatalogoMetric(icon: Icons.visibility_outlined, label: 'Visibles', value: '$visibles'),
      _CatalogoMetric(icon: Icons.category_outlined, label: 'Categorías', value: '$tipos'),
      _CatalogoMetric(
        icon: Icons.sell_outlined,
        label: 'Desde',
        value: precioDesde == null ? '—' : CurrencyUtils.format(precioDesde),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: palette.panelPadding(16),
      decoration: palette.panelDecoration(
        baseRadius: 24,
        tint: palette.primary,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final heading = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.actionColor,
                  borderRadius: BorderRadius.circular(palette.radius(15)),
                ),
                child: Icon(Icons.local_bar_rounded, color: palette.onAction, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Catálogo de productos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      visibles == total
                          ? 'Consulta precios, imágenes y categorías de la sucursal.'
                          : 'Mostrando $visibles de $total productos según los filtros.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 13),
                Wrap(spacing: 8, runSpacing: 8, children: metrics),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: heading),
              const SizedBox(width: 22),
              Expanded(
                flex: 5,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: metrics,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CatalogoMetric extends ConsumerWidget {
  const _CatalogoMetric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: EdgeInsets.symmetric(horizontal: 12 * palette.spacingScale, vertical: 9 * palette.spacingScale),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.72),
        borderRadius: BorderRadius.circular(palette.radius(16)),
        border: Border.all(color: palette.secondary.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: palette.secondary),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogoCategoryChip extends ConsumerWidget {
  const _CatalogoCategoryChip({required this.label, required this.icon, required this.selected, required this.onSelected});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: Icon(icon, size: 16, color: selected ? palette.onPrimary : palette.secondary),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? palette.onPrimary : palette.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      selectedColor: palette.actionColor,
      backgroundColor: palette.background.withOpacity(palette.darkBackground ? 0.40 : 0.70),
      side: BorderSide(color: selected ? palette.secondary.withOpacity(0.42) : palette.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(palette.radius(999))),
      showCheckmark: false,
      padding: EdgeInsets.symmetric(horizontal: 9 * palette.spacingScale, vertical: 7 * palette.spacingScale),
    );
  }
}

class _CatalogoViewToggle extends ConsumerWidget {
  const _CatalogoViewToggle({required this.gridSelected, required this.onGrid, required this.onList});

  final bool gridSelected;
  final VoidCallback onGrid;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    Widget button({required IconData icon, required String tooltip, required bool selected, required VoidCallback onTap}) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        color: selected ? palette.onAction : palette.textSecondary,
        style: IconButton.styleFrom(
          backgroundColor: selected ? palette.actionColor : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.48 : 0.74),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(icon: Icons.grid_view_rounded, tooltip: 'Vista de tarjetas', selected: gridSelected, onTap: onGrid),
          const SizedBox(width: 3),
          button(icon: Icons.view_agenda_rounded, tooltip: 'Vista compacta', selected: !gridSelected, onTap: onList),
        ],
      ),
    );
  }
}

class _CatalogoEmptyState extends ConsumerWidget {
  const _CatalogoEmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24 * palette.spacingScale, vertical: 40 * palette.spacingScale),
      decoration: palette.panelDecoration(
        baseRadius: 24,
        tint: palette.secondary,
        elevated: false,
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.search_off_rounded, color: palette.secondary, size: 30),
          ),
          const SizedBox(height: 14),
          Text('No encontramos productos', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Prueba otra búsqueda o elimina los filtros seleccionados.', textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.filter_alt_off_rounded), label: const Text('Quitar filtros')),
        ],
      ),
    );
  }
}

class _ProductosCatalogoTabla extends ConsumerWidget {
  const _ProductosCatalogoTabla({
    required this.productos,
    required this.vistaCuadricula,
    required this.onOpen,
  });

  final List<MeseroProductoModel> productos;
  final bool vistaCuadricula;
  final ValueChanged<MeseroProductoModel> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (vistaCuadricula) {
          final width = constraints.maxWidth;
          final columns = width >= 1660
              ? 6
              : width >= 1320
                  ? 5
                  : width >= 1020
                      ? 4
                      : width >= 760
                          ? 3
                          : width >= 480
                              ? 2
                              : 1;
          final extent = switch (palette.density) {
            AppDensityPreset.compact => columns == 1 ? 216.0 : 236.0,
            AppDensityPreset.balanced => columns == 1 ? 232.0 : 252.0,
            AppDensityPreset.spacious => columns == 1 ? 254.0 : 276.0,
          };
          final gap = 12 * palette.spacingScale;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: productos.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: extent,
            ),
            itemBuilder: (context, index) => _ProductoCatalogoCard(
              producto: productos[index],
              onTap: () => onOpen(productos[index]),
            ),
          );
        }

        return Container(
          width: double.infinity,
          decoration: palette.panelDecoration(
            baseRadius: 22,
            tint: palette.secondary,
            elevated: false,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < productos.length; index++)
                _ProductoCatalogoListRow(
                  producto: productos[index],
                  last: index == productos.length - 1,
                  onTap: () => onOpen(productos[index]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductoCatalogoCard extends ConsumerStatefulWidget {
  const _ProductoCatalogoCard({required this.producto, required this.onTap});

  final MeseroProductoModel producto;
  final VoidCallback onTap;

  @override
  ConsumerState<_ProductoCatalogoCard> createState() => _ProductoCatalogoCardState();
}

class _ProductoCatalogoCardState extends ConsumerState<_ProductoCatalogoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final theme = Theme.of(context);
    final producto = widget.producto;
    final tipo = _catalogoTipoProducto(producto);
    final marca = _catalogoMarcaProducto(producto);
    final descripcion = _catalogoDescripcionProducto(producto);
    final compact = palette.density == AppDensityPreset.compact;
    final spacious = palette.density == AppDensityPreset.spacious;
    final imageHeight = compact ? 102.0 : (spacious ? 128.0 : 114.0);
    final imageSize = compact ? 76.0 : (spacious ? 98.0 : 88.0);
    final radius = palette.radius(22);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.012 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          decoration: palette.panelDecoration(
            baseRadius: 22,
            tint: palette.secondary,
            elevated: true,
          ).copyWith(
            border: Border.all(
              color: _hovered
                  ? palette.secondary.withOpacity(0.46)
                  : palette.secondary.withOpacity(palette.darkBackground ? 0.16 : 0.12),
              width: _hovered ? 1.35 : 1,
            ),
            boxShadow: palette.surfaceStyle == AppSurfacePreset.flat
                ? const []
                : [
                    BoxShadow(
                      color: palette.cardShadow.withOpacity(_hovered ? 0.33 : 0.18),
                      blurRadius: _hovered ? 24 : 16,
                      offset: Offset(0, _hovered ? 10 : 7),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                palette.background.withOpacity(palette.darkBackground ? 0.72 : 0.68),
                                palette.secondary.withOpacity(_hovered ? 0.18 : 0.09),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Center(child: _ProductoCatalogoImage(value: producto.foto, size: imageSize)),
                        Positioned(
                          top: compact ? 8 : 10,
                          left: compact ? 8 : 10,
                          child: _CatalogoPill(
                            icon: Icons.category_outlined,
                            text: tipo,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        13 * palette.spacingScale,
                        11 * palette.spacingScale,
                        13 * palette.spacingScale,
                        12 * palette.spacingScale,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          if (descripcion.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              descripcion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Icon(Icons.local_offer_outlined, size: 14, color: palette.secondary),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  marca,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Precio',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: palette.textSecondary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      CurrencyUtils.format(producto.precioVenta),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: palette.secondary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 8 : 10,
                                  vertical: compact ? 6 : 7,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.actionColor.withOpacity(_hovered ? 1 : 0.90),
                                  borderRadius: BorderRadius.circular(palette.radius(12)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Ver',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: palette.onAction,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, size: 16, color: palette.onAction),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _ProductoCatalogoListRow extends ConsumerWidget {
  const _ProductoCatalogoListRow({required this.producto, required this.last, required this.onTap});

  final MeseroProductoModel producto;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final tipo = _catalogoTipoProducto(producto);
    final marca = _catalogoMarcaProducto(producto);
    final descripcion = _catalogoDescripcionProducto(producto);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              final content = Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ProductoCatalogoImage(value: producto.foto, size: compact ? 66 : 74),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: compact ? 14 : 15.5),
                        ),
                        if (descripcion.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            descripcion,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            _CatalogoPill(icon: Icons.category_rounded, text: tipo, compact: true),
                            _CatalogoPill(icon: Icons.local_offer_rounded, text: marca, compact: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Precio vigente', style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(CurrencyUtils.format(producto.precioVenta), style: TextStyle(color: palette.secondary, fontSize: 17, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.chevron_right_rounded, color: palette.secondary),
                  ],
                ],
              );

              if (!compact) return content;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('Precio', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 11)),
                      const Spacer(),
                      Text(CurrencyUtils.format(producto.precioVenta), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: palette.secondary),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductoCatalogoImage extends ConsumerWidget {
  const _ProductoCatalogoImage({required this.value, required this.size});

  final String? value;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final image = (value ?? '').trim();
    final radius = palette.radius(size > 90 ? 22 : 17);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(7 * palette.spacingScale),
      decoration: BoxDecoration(
        gradient: palette.panelGradient(tint: palette.secondary),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.secondary.withOpacity(0.16)),
        boxShadow: palette.surfaceStyle == AppSurfacePreset.flat
            ? const []
            : [
                BoxShadow(
                  color: palette.cardShadow.withOpacity(0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: image.isEmpty
          ? Icon(Icons.inventory_2_outlined, color: palette.secondary, size: size * 0.34)
          : ClipRRect(
              borderRadius: BorderRadius.circular(palette.radius(size > 90 ? 16 : 12)),
              child: _BarlyticsImage(
                value: image,
                width: size - 14,
                height: size - 14,
                fit: BoxFit.contain,
              ),
            ),
    );
  }
}

class _CatalogoPill extends ConsumerWidget {
  const _CatalogoPill({required this.icon, required this.text, this.compact = false});

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 5 : 7),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.66 : 0.78),
        borderRadius: BorderRadius.circular(palette.radius(999)),
        border: Border.all(color: palette.secondary.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: palette.secondary),
          SizedBox(width: compact ? 5 : 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: compact ? 10.5 : 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductoCatalogoDetalleSheet extends ConsumerWidget {
  const _ProductoCatalogoDetalleSheet({required this.producto});

  final MeseroProductoModel producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final media = MediaQuery.of(context);
    final size = media.size;
    final tipo = _catalogoTipoProducto(producto);
    final marca = _catalogoMarcaProducto(producto);
    final descripcion = _catalogoDescripcionProducto(producto);
    final isHandheld = size.width < 900 || size.width / size.height < 0.95;
    final isVeryCompact = size.width < 480;
    final spacing = palette.spacingScale;
    final sheetHeight = isHandheld
        ? (size.height * 0.94).clamp(520.0, size.height).toDouble()
        : (size.height * 0.82).clamp(540.0, 760.0).toDouble();
    final horizontalMargin = isHandheld ? 8.0 : 24.0;
    final sheetWidth = isHandheld ? size.width - (horizontalMargin * 2) : 760.0;
    final radius = palette.radius(isHandheld ? 26 : 30);

    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w900,
          height: 1.12,
        );

    Widget buildProductIdentity({required bool compact}) {
      final imageSize = compact ? 118.0 : 148.0;
      final textContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _CatalogoPill(icon: Icons.category_rounded, text: tipo, compact: true),
              _CatalogoPill(icon: Icons.local_offer_rounded, text: marca, compact: true),
            ],
          ),
          SizedBox(height: 12 * spacing),
          Text(
            producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
            maxLines: compact ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          SizedBox(height: 7 * spacing),
          Text(
            descripcion.isEmpty
                ? 'Este producto no tiene una descripción comercial registrada.'
                : descripcion,
            maxLines: compact ? 4 : 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.34,
                ),
          ),
        ],
      );

      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _ProductoCatalogoImage(value: producto.foto, size: imageSize)),
            SizedBox(height: 16 * spacing),
            textContent,
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ProductoCatalogoImage(value: producto.foto, size: imageSize),
          SizedBox(width: 18 * spacing),
          Expanded(child: textContent),
        ],
      );
    }

    final body = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20 * spacing,
        18 * spacing,
        20 * spacing,
        24 * spacing + media.viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildProductIdentity(compact: isVeryCompact),
          SizedBox(height: 18 * spacing),
          Container(
            padding: EdgeInsets.all(15 * spacing),
            decoration: BoxDecoration(
              gradient: palette.panelGradient(tint: palette.secondary),
              borderRadius: BorderRadius.circular(palette.radius(20)),
              border: Border.all(color: palette.secondary.withOpacity(0.22)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.actionColor,
                    borderRadius: BorderRadius.circular(palette.radius(14)),
                  ),
                  child: Icon(Icons.sell_rounded, color: palette.onAction),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio vigente',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        CurrencyUtils.format(producto.precioVenta),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12 * spacing),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15 * spacing, vertical: 13 * spacing),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(palette.darkBackground ? 0.34 : 0.62),
              borderRadius: BorderRadius.circular(palette.radius(17)),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(palette.radius(12)),
                  ),
                  child: Icon(Icons.tag_rounded, size: 19, color: palette.secondary),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Código del producto',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '#${producto.prodId ?? '-'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
        child: SizedBox(
          width: sheetWidth,
          height: sheetHeight,
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: palette.panelGradient(tint: palette.secondary),
                borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                border: Border.all(color: palette.secondary.withOpacity(0.20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.36),
                    blurRadius: 36,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16 * spacing, 10 * spacing, 10 * spacing, 10 * spacing),
                    child: Column(
                      children: [
                        Container(
                          width: 46,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.secondary.withOpacity(0.48),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        SizedBox(height: 9 * spacing),
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: palette.secondary.withOpacity(0.13),
                                borderRadius: BorderRadius.circular(palette.radius(12)),
                              ),
                              child: Icon(Icons.inventory_2_outlined, size: 19, color: palette.secondary),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Detalle del producto',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: palette.textPrimary,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  Text(
                                    'Consulta imagen, marca y precio vigente.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: palette.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Cerrar',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: palette.cardBorder),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductoCard extends ConsumerWidget {
  const _ProductoCard({required this.producto, this.actionLabel, this.onAction});

  final MeseroProductoModel producto;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
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
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(CurrencyUtils.format(producto.precioVenta), style: TextStyle(fontWeight: FontWeight.w900, color: palette.secondary))),
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

class _AgregarProductosList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 18, offset: const Offset(0, 8))],
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
                    _buildHeader(palette),
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

  Widget _buildHeader(AppPalette palette) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.52 : 0.70),
        border: Border(bottom: BorderSide(color: palette.cardBorder)),
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

class _AgregarProductoTableRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final tipo = (producto.tipoProductoNombre ?? '').trim().isNotEmpty
        ? producto.tipoProductoNombre!.trim()
        : (producto.tipoProductoId == null ? 'Sin tipo' : 'Tipo ${producto.tipoProductoId}');
    final marca = (producto.marcaNombre ?? '').trim().isNotEmpty
        ? producto.marcaNombre!.trim()
        : (producto.marcaId == null ? 'Sin marca' : 'Marca ${producto.marcaId}');
    final descripcion = (producto.descripcion ?? '').trim();
    final yaPedido = cantidadVenta > 0.009;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAgregar,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.cardBorder))),
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
                      color: yaPedido ? palette.secondary.withOpacity(0.14) : palette.background.withOpacity(palette.darkBackground ? 0.45 : 0.70),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: yaPedido ? palette.secondary.withOpacity(0.32) : palette.cardBorder),
                    ),
                    child: Text('#$posicion', style: TextStyle(color: yaPedido ? palette.secondary : palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 12)),
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
                      style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary),
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
                            color: palette.background.withOpacity(palette.darkBackground ? 0.48 : 0.70),
                            borderColor: palette.cardBorder,
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

class _AgregarProductoMobileRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final tipo = (producto.tipoProductoNombre ?? '').trim().isNotEmpty
        ? producto.tipoProductoNombre!.trim()
        : (producto.tipoProductoId == null ? 'Sin tipo' : 'Tipo ${producto.tipoProductoId}');
    final marca = (producto.marcaNombre ?? '').trim().isNotEmpty
        ? producto.marcaNombre!.trim()
        : (producto.marcaId == null ? 'Sin marca' : 'Marca ${producto.marcaId}');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAgregar,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.cardBorder))),
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
                      color: cantidadVenta > 0.009 ? palette.secondary.withOpacity(0.14) : palette.background.withOpacity(palette.darkBackground ? 0.45 : 0.70),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cantidadVenta > 0.009 ? palette.secondary.withOpacity(0.32) : palette.cardBorder),
                    ),
                    child: Text('#$posicion', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: palette.secondary)),
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
                          style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary),
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

class _PedidoTag extends ConsumerWidget {
  const _PedidoTag({required this.icon, required this.text, required this.color, required this.borderColor});

  final IconData icon;
  final String text;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(palette.darkBackground ? 0.72 : 0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor.withOpacity(0.86)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.secondary),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: palette.textSecondary)),
        ],
      ),
    );
  }
}

class _ProductoTag extends ConsumerWidget {
  const _ProductoTag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surface.withOpacity(palette.darkBackground ? 0.72 : 0.88),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: palette.secondary),
            const SizedBox(width: 5),
            Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: palette.textSecondary)),
          ],
        ),
      );
  }
}


String _formatFechaHoraVentaDetalle(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return '';

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;

  final date = parsed.toLocal();
  const meses = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'p. m.' : 'a. m.';
  return '${date.day} ${meses[date.month - 1]} ${date.year} · $hour:$minute $period';
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

class _DetalleHistorialVentaPage extends ConsumerStatefulWidget {
  const _DetalleHistorialVentaPage({required this.venta, this.imprimirAlAbrir = false, this.enviarCorreoAlAbrir = false});

  final MeseroVentaModel venta;
  final bool imprimirAlAbrir;
  final bool enviarCorreoAlAbrir;

  @override
  ConsumerState<_DetalleHistorialVentaPage> createState() => _DetalleHistorialVentaPageState();
}

class _DetalleHistorialVentaPageState extends ConsumerState<_DetalleHistorialVentaPage> {
  late MeseroVentaModel _venta;
  late MeseroRemoteDataSource _dataSource;
  int? _actualizandoPagoId;

  @override
  void initState() {
    super.initState();
    _venta = widget.venta;
    _dataSource = MeseroRemoteDataSource(ref.read(apiClientProvider));
    if (widget.imprimirAlAbrir || widget.enviarCorreoAlAbrir) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.imprimirAlAbrir) {
          _imprimirTicketTermico();
        } else {
          _enviarComprobanteCorreo();
        }
      });
    }
  }

  bool _imprimiendoTicket = false;

  String _nombreSucursalTicket(int? sucursalId) {
    final sucursales = ref.read(branchScopeProvider).branches;
    for (final sucursal in sucursales) {
      if (sucursal.sucuId == sucursalId) {
        final nombre = (sucursal.sucuNombre ?? '').trim();
        if (nombre.isNotEmpty) return nombre;
      }
    }
    return sucursalId == null ? 'Sucursal' : 'Sucursal #$sucursalId';
  }

  Future<void> _imprimirTicketTermico() async {
    if (_imprimiendoTicket) return;
    final method = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.wifi_rounded),
          title: const Text('Imprimir por Wi-Fi / LAN'),
          subtitle: const Text('Impresora térmica ESC/POS por IP'),
          onTap: () => Navigator.pop(sheet, 'lan'),
        ),
        ListTile(
          leading: const Icon(Icons.print_outlined),
          title: const Text('Imprimir con el sistema'),
          subtitle: const Text('Impresora instalada o servicio de impresión'),
          onTap: () => Navigator.pop(sheet, 'system'),
        ),
      ])),
    );
    if (method == null || !mounted) return;
    setState(() => _imprimiendoTicket = true);
    try {
      if (method == 'lan') {
        final venta = _venta;
        final items = venta.cuentas.expand((cuenta) => cuenta.productos).toList();
        final subtotal = items.fold<double>(0, (sum, item) => sum + _detalleProductoSubtotal(item));
        final propina = venta.propina ?? venta.cuentas.fold<double>(0, (sum, cuenta) => sum + (cuenta.propina ?? 0));
        final ticket = StringBuffer()
          ..writeln(_nombreSucursalTicket(venta.sucursalId).toUpperCase())
          ..writeln('COMPROBANTE DE VENTA')
          ..writeln('Venta #${venta.ventaId ?? "-"}')
          ..writeln(_nombreSucursalTicket(venta.sucursalId))
          ..writeln('Fecha: ${venta.fecha ?? "-"}')
          ..writeln('--------------------------------');
        for (final item in items) {
          ticket.writeln('${item.cantidad ?? 0} x ${item.productoNombre ?? "Producto"}');
          ticket.writeln('  ${CurrencyUtils.format(_detalleProductoSubtotal(item))}');
        }
        ticket
          ..writeln('--------------------------------')
          ..writeln('Subtotal: ${CurrencyUtils.format(subtotal)}')
          ..writeln('Servicio/propina: ${CurrencyUtils.format(propina)}')
          ..writeln('TOTAL: ${CurrencyUtils.format(venta.total ?? subtotal + propina)}')
          ..writeln('Pagado: ${CurrencyUtils.format(venta.totalPagado ?? 0)}')
          ..writeln()
          ..writeln('Gracias por tu compra')
          ..writeln('Comprobante informativo. No es')
          ..writeln('factura electronica DIAN.');
        final printed = await printTicketOverLan(context, venta.sucursalId ?? 0, ticket.toString());
        if (printed && mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket enviado a la impresora de red')),
        );
        return;
      }
      final venta = _venta;
      final pdf = pw.Document();
      final items = venta.cuentas.expand((cuenta) => cuenta.productos).toList();
      final subtotal = items.fold<double>(0, (sum, producto) => sum + _detalleProductoSubtotal(producto));
      final propina = venta.propina ?? venta.cuentas.fold<double>(0, (sum, cuenta) => sum + (cuenta.propina ?? 0));
      final total = venta.total ?? (subtotal + propina);
      final pagado = venta.totalPagado ?? 0;
      final pagos = venta.cuentas.expand((cuenta) => cuenta.pagos).toList();
      // Altura del rollo proporcional al contenido, no una hoja A4 ni
      // una página de longitud fija. Dejamos espacio para nombres extensos.
      final lineasProductos = items.fold<int>(0, (sum, item) {
        final nombre = item.productoNombre ?? 'Producto';
        return sum + ((nombre.length + 4) / 30).ceil().clamp(1, 20);
      });
      final lineasAviso = 3;
      final altoContenidoPt = 155.0 + (lineasProductos * 14.0) + (lineasAviso * 9.0);
      final pageHeight = (altoContenidoPt / PdfPageFormat.mm + 15.0).clamp(95.0, 2000.0).toDouble();
      final ticketFormat = PdfPageFormat(
        80 * PdfPageFormat.mm,
        pageHeight * PdfPageFormat.mm,
        marginAll: 5 * PdfPageFormat.mm,
      );
      pdf.addPage(pw.Page(
        pageFormat: ticketFormat,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(child: pw.Text(_nombreSucursalTicket(venta.sucursalId).toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text('Comprobante de venta', style: const pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 8),
            pw.Text('Venta #${venta.ventaId ?? "-"}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Fecha: ${venta.fecha ?? ""}', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(_nombreSucursalTicket(venta.sucursalId), style: const pw.TextStyle(fontSize: 8)),
            pw.Divider(),
            ...items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(children: [
                pw.Expanded(child: pw.Text('${item.productoNombre ?? "Producto"} x${item.cantidad ?? 0}', style: const pw.TextStyle(fontSize: 8))),
                pw.Text(CurrencyUtils.format(_detalleProductoSubtotal(item)), style: const pw.TextStyle(fontSize: 8)),
              ]),
            )),
            pw.Divider(),
            pw.Text('Productos: ${CurrencyUtils.format(subtotal)}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Servicio / propina: ${CurrencyUtils.format(propina)}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('TOTAL: ${CurrencyUtils.format(total)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('Pagado: ${CurrencyUtils.format(pagado)}', style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Text('Gracias por tu compra', style: const pw.TextStyle(fontSize: 9))),
            pw.Center(child: pw.Text('Comprobante informativo. No equivale a factura electrónica DIAN.', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
          ],
        ),
      ));
      await Printing.layoutPdf(
        onLayout: (_) => pdf.save(),
        name: 'ticket_venta_${venta.ventaId ?? 0}',
        format: ticketFormat,
        usePrinterSettings: false,
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible imprimir el ticket: $error')),
      );
    } finally {
      if (mounted) setState(() => _imprimiendoTicket = false);
    }
  }

  bool _enviandoComprobante = false;

  Future<void> _enviarComprobanteCorreo() async {
    final ventaId = _venta.ventaId;
    if (ventaId == null || _enviandoComprobante) return;
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar comprobante por correo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo del cliente',
            hintText: 'cliente@correo.com',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.contains('@') && value.split('@').length == 2 && value.split('@').last.contains('.')) {
                Navigator.pop(dialogContext, value);
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Ingresa un correo válido.')),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || !mounted) return;
    setState(() => _enviandoComprobante = true);
    try {
      await ref.read(apiClientProvider).post<void>(
        '/api/v1/mesero/ventas/$ventaId/comprobante/email',
        {'email': email},
        (_) => null,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobante enviado correctamente')),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el comprobante: ＄error')),
      );
    } finally {
      if (mounted) setState(() => _enviandoComprobante = false);
    }
  }

  Future<void> _cambiarMedioPago(MeseroCuentaModel cuenta, MeseroPagoModel pago) async {
    final pagoId = pago.pagoId;
    if (pagoId == null || _actualizandoPagoId != null) return;
    final authorized = ref.read(authControllerProvider).roles.any((role) {
      final code = role.toUpperCase().replaceFirst('ROLE_', '');
      return const {'ADMINISTRADOR', 'GERENTE', 'ADMIN', 'SUPERADMIN',
        'SUPER_ADMIN', 'MANAGER'}.contains(code);
    });
    if (!authorized) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Solo gerencia o administración puede modificar pagos históricos.'),
      ));
      return;
    }
    setState(() => _actualizandoPagoId = pagoId);
    try {
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => PagosListPage(initialPaymentId: pagoId),
      ));
      final ventaId = _venta.ventaId;
      final actualizada = ventaId == null
          ? _venta : await _dataSource.consultarVenta(ventaId);
      if (mounted) setState(() => _venta = actualizada);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible actualizar los pagos: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizandoPagoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venta = _venta;
    final palette = ref.watch(selectedAppPaletteProvider);
    final productos = _agruparProductosFactura(venta.cuentas.expand((cuenta) => cuenta.productos));
    final pagos = venta.cuentas.expand((cuenta) => cuenta.pagos.map((pago) => (cuenta: cuenta, pago: pago))).toList(growable: false);
    final totalProductos = venta.cuentas.fold<double>(
      0,
      (sum, cuenta) => sum +
          (cuenta.subtotalProductos ??
              cuenta.productos.fold<double>(0, (acc, producto) => acc + _detalleProductoSubtotal(producto))),
    );
    final totalPropina = venta.propina ?? venta.cuentas.fold<double>(0, (sum, cuenta) => sum + (cuenta.propina ?? 0));
    final totalCambio = pagos.fold<double>(0, (sum, item) => sum + (item.pago.cambio ?? 0));
    final totalUnidades = productos.fold<double>(0, (sum, producto) => sum + producto.cantidad);

    final productosPanel = _HistorialFacturaProductos(productos: productos);
    final cuentasPanel = _HistorialCuentasPanel(venta: venta);
    final resumenPanel = _HistorialCobroResumen(
      venta: venta,
      totalProductos: totalProductos,
      totalPropina: totalPropina,
      totalCambio: totalCambio,
    );
    final ventaFinalizada = (venta.estado ?? '').trim().toUpperCase() == 'FINALIZADA';
    final pagosPanel = _HistorialPagosPanel(
      pagos: pagos,
      onCambiarMedioPago: ventaFinalizada ? _cambiarMedioPago : null,
      actualizandoPagoId: _actualizandoPagoId,
    );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        toolbarHeight: 72,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: palette.titleBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.onTitle,
        iconTheme: IconThemeData(color: palette.onTitle),
        titleSpacing: 0,
        actions: [
          IconButton(
            tooltip: 'Imprimir ticket de 80 mm',
            onPressed: _imprimiendoTicket ? null : _imprimirTicketTermico,
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Enviar comprobante por correo',
            onPressed: _enviandoComprobante ? null : _enviarComprobanteCorreo,
            icon: const Icon(Icons.email_outlined),
          ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Detalle de venta',
              style: TextStyle(color: palette.onTitle, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              'Venta #${venta.ventaId ?? '-'} · ${_origenVentaVisible(venta)}',
              style: TextStyle(color: palette.onTitle.withOpacity(0.72), fontWeight: FontWeight.w700, fontSize: 11.5),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: palette.secondary.withOpacity(0.20)),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppPageBackground(),
          SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, viewport) {
                final minHeight = viewport.maxHeight > 48 ? viewport.maxHeight - 48 : 0.0;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HistorialVentaCabecera(
                              venta: venta,
                              productos: productos.length,
                              unidades: totalUnidades,
                              pagos: pagos.length,
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final desktop = constraints.maxWidth >= 980;
                                if (!desktop) {
                                  return Column(
                                    children: [
                                      productosPanel,
                                      const SizedBox(height: 14),
                                      resumenPanel,
                                      const SizedBox(height: 14),
                                      pagosPanel,
                                      const SizedBox(height: 14),
                                      cuentasPanel,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: Column(
                                        children: [
                                          productosPanel,
                                          const SizedBox(height: 14),
                                          cuentasPanel,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 390,
                                      child: Column(
                                        children: [
                                          resumenPanel,
                                          const SizedBox(height: 14),
                                          pagosPanel,
                                        ],
                                      ),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorialVentaCabecera extends ConsumerWidget {
  const _HistorialVentaCabecera({
    required this.venta,
    required this.productos,
    required this.unidades,
    required this.pagos,
  });

  final MeseroVentaModel venta;
  final int productos;
  final double unidades;
  final int pagos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final descripcion = (venta.mesaDescripcion ?? '').trim();
    final ventaDirecta = (venta.tipoVenta ?? '').trim().toUpperCase() == 'DIRECTA' || venta.mesaId == null;
    final pagada = venta.pagada == true || (venta.saldoPendiente ?? 0) <= 0.009;

    Widget identity() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ventaDirecta
              ? Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(color: palette.secondary.withOpacity(0.14), borderRadius: BorderRadius.circular(22)),
                  child: Icon(Icons.point_of_sale_rounded, color: palette.secondary, size: 32),
                )
              : _MesaNumberPhotoBadge(
                  mesaNumero: venta.mesaNumero,
                  mesaFoto: venta.mesaFoto,
                  size: 68,
                  radius: 34,
                  accentColor: palette.secondary,
                  backgroundColor: palette.background.withOpacity(0.72),
                  textColor: Colors.white,
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
                        'Venta #${venta.ventaId ?? '-'}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary),
                      ),
                    ),
                    _HistorialEstadoChip(pagada: pagada),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  ventaDirecta ? 'Venta directa · Mostrador' : (descripcion.isEmpty ? 'Mesa ${venta.mesaNumero ?? venta.mesaId ?? '-'}' : descripcion),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                ),
                if ((venta.fecha ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: palette.textSecondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _formatFechaHoraVentaDetalle(venta.fecha),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final total = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.48 : 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Total de la venta', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(CurrencyUtils.format(venta.total), style: TextStyle(color: palette.secondary, fontSize: 25, fontWeight: FontWeight.w900)),
          if (!pagada) ...[
            const SizedBox(height: 4),
            Text('Saldo ${CurrencyUtils.format(venta.saldoPendiente)}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900, fontSize: 12)),
          ],
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                identity(),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: total),
              ] else
                Row(children: [Expanded(child: identity()), const SizedBox(width: 18), total]),
              const SizedBox(height: 16),
              Divider(height: 1, color: palette.cardBorder),
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _HistorialDatoInline(icon: Icons.call_split_rounded, label: 'Cuentas', value: '${venta.cuentas.length}'),
                  _HistorialDatoInline(icon: Icons.inventory_2_rounded, label: 'Productos', value: '$productos'),
                  _HistorialDatoInline(icon: Icons.numbers_rounded, label: 'Unidades', value: _formatCantidadGeneral(unidades)),
                  _HistorialDatoInline(icon: Icons.payments_rounded, label: 'Pagos', value: '$pagos'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistorialEstadoChip extends ConsumerWidget {
  const _HistorialEstadoChip({required this.pagada});
  final bool pagada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final color = pagada ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.28))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pagada ? Icons.check_circle_rounded : Icons.pending_actions_rounded, size: 15, color: color),
          const SizedBox(width: 5),
          Text(pagada ? 'Pagada' : 'Pendiente', style: TextStyle(color: pagada ? color : (palette.darkBackground ? color : AppColors.danger), fontWeight: FontWeight.w900, fontSize: 11)),
        ],
      ),
    );
  }
}

class _HistorialDatoInline extends ConsumerWidget {
  const _HistorialDatoInline({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: palette.secondary),
        const SizedBox(width: 7),
        Text('$label: ', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
        Text(value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
      ],
    );
  }
}

class _HistorialFacturaProductos extends ConsumerWidget {
  const _HistorialFacturaProductos({required this.productos});
  final List<_FacturaProductoAgrupado> productos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: palette.secondary),
                const SizedBox(width: 10),
                Expanded(child: Text('Productos facturados', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary))),
                Text(productos.length == 1 ? '1 referencia' : '${productos.length} referencias', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
          Divider(height: 1, color: palette.cardBorder),
          if (productos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text('Esta venta no tiene productos registrados.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 650;
                if (compact) {
                  return Column(
                    children: [
                      for (var i = 0; i < productos.length; i++)
                        _HistorialProductoFacturaMobile(producto: productos[i], last: i == productos.length - 1),
                    ],
                  );
                }
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: palette.background.withOpacity(palette.darkBackground ? 0.35 : 0.65),
                      child: Row(
                        children: [
                          const SizedBox(width: 70, child: _HistorialTablaHeader('Cant.')),
                          const Expanded(child: _HistorialTablaHeader('Producto')),
                          const SizedBox(width: 120, child: _HistorialTablaHeader('Unitario', alignEnd: true)),
                          const SizedBox(width: 130, child: _HistorialTablaHeader('Total', alignEnd: true)),
                        ],
                      ),
                    ),
                    for (var i = 0; i < productos.length; i++)
                      _HistorialProductoFacturaRow(producto: productos[i], last: i == productos.length - 1),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _HistorialTablaHeader extends ConsumerWidget {
  const _HistorialTablaHeader(this.text, {this.alignEnd = false});
  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(text, style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _HistorialProductoFacturaRow extends ConsumerWidget {
  const _HistorialProductoFacturaRow({required this.producto, required this.last});
  final _FacturaProductoAgrupado producto;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(_formatCantidadGeneral(producto.cantidad), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))),
          Expanded(child: Text(producto.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800))),
          SizedBox(width: 120, child: Text(CurrencyUtils.format(producto.precioUnitario), textAlign: TextAlign.right, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))),
          SizedBox(width: 130, child: Text(CurrencyUtils.format(producto.total), textAlign: TextAlign.right, style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _HistorialProductoFacturaMobile extends ConsumerWidget {
  const _HistorialProductoFacturaMobile({required this.producto, required this.last});
  final _FacturaProductoAgrupado producto;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(producto.nombre, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _HistorialMiniDato(label: 'Cantidad', value: _formatCantidadGeneral(producto.cantidad))),
              Expanded(child: _HistorialMiniDato(label: 'Unitario', value: CurrencyUtils.format(producto.precioUnitario), alignEnd: true)),
              Expanded(child: _HistorialMiniDato(label: 'Total', value: CurrencyUtils.format(producto.total), alignEnd: true, highlight: true)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistorialMiniDato extends ConsumerWidget {
  const _HistorialMiniDato({required this.label, required this.value, this.alignEnd = false, this.highlight = false});
  final String label;
  final String value;
  final bool alignEnd;
  final bool highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: highlight ? palette.secondary : palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _HistorialCobroResumen extends ConsumerWidget {
  const _HistorialCobroResumen({required this.venta, required this.totalProductos, required this.totalPropina, required this.totalCambio});
  final MeseroVentaModel venta;
  final double totalProductos;
  final double totalPropina;
  final double totalCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final saldo = venta.saldoPendiente ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.calculate_rounded, color: palette.secondary), const SizedBox(width: 9), Text('Resumen de cobro', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary))]),
          const SizedBox(height: 14),
          _detalleLinea(palette, 'Productos', CurrencyUtils.format(totalProductos)),
          _detalleLinea(palette, 'Propina', CurrencyUtils.format(totalPropina)),
          Divider(height: 20, color: palette.cardBorder),
          _detalleLinea(palette, 'Total venta', CurrencyUtils.format(venta.total), destacado: true),
          _detalleLinea(palette, 'Total pagado', CurrencyUtils.format(venta.totalPagado ?? (venta.pagada == true ? venta.total : 0))),
          if (totalCambio > 0) _detalleLinea(palette, 'Vueltas entregadas', CurrencyUtils.format(totalCambio)),
          Divider(height: 20, color: palette.cardBorder),
          _detalleLinea(palette, 'Saldo pendiente', CurrencyUtils.format(saldo), destacado: true, danger: saldo > 0.009),
        ],
      ),
    );
  }
}

class _HistorialPagosPanel extends ConsumerWidget {
  const _HistorialPagosPanel({
    required this.pagos,
    this.onCambiarMedioPago,
    this.actualizandoPagoId,
  });
  final List<({MeseroCuentaModel cuenta, MeseroPagoModel pago})> pagos;
  final Future<void> Function(MeseroCuentaModel cuenta, MeseroPagoModel pago)? onCambiarMedioPago;
  final int? actualizandoPagoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final totals = <String, double>{};
    for (final item in pagos) {
      final name = (item.pago.medioPagoNombre ?? 'Medio ${item.pago.medioPagoId ?? '-'}').trim();
      totals[name] = (totals[name] ?? 0) + (item.pago.valor ?? 0);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.payments_rounded, color: palette.secondary), const SizedBox(width: 9), Expanded(child: Text('Pagos registrados', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary))), Text('${pagos.length}', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900))]),
          if (totals.isNotEmpty && (totals.length > 1 || pagos.length > 1)) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: totals.entries.map((entry) => _SmallInfoPill(icon: Icons.account_balance_wallet_rounded, text: '${entry.key}: ${CurrencyUtils.format(entry.value)}')).toList(growable: false),
            ),
          ],
          const SizedBox(height: 12),
          if (pagos.isEmpty)
            Text('No hay pagos registrados para esta venta.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))
          else
            for (var i = 0; i < pagos.length; i++)
              _HistorialPagoCompacto(
                item: pagos[i],
                last: i == pagos.length - 1,
                onCambiarMedioPago: onCambiarMedioPago,
                actualizando: actualizandoPagoId == pagos[i].pago.pagoId,
              ),
        ],
      ),
    );
  }
}

class _HistorialPagoCompacto extends ConsumerWidget {
  const _HistorialPagoCompacto({
    required this.item,
    required this.last,
    this.onCambiarMedioPago,
    this.actualizando = false,
  });
  final ({MeseroCuentaModel cuenta, MeseroPagoModel pago}) item;
  final bool last;
  final Future<void> Function(MeseroCuentaModel cuenta, MeseroPagoModel pago)? onCambiarMedioPago;
  final bool actualizando;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final pago = item.pago;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, size: 18, color: palette.secondary),
              const SizedBox(width: 8),
              Expanded(child: Text(pago.medioPagoNombre ?? 'Medio ${pago.medioPagoId ?? '-'}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))),
              Text(CurrencyUtils.format(pago.valor), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
              if (onCambiarMedioPago != null && pago.pagoId != null) ...[
                const SizedBox(width: 6),
                actualizando
                    ? const SizedBox(width: 28, height: 28, child: Padding(padding: EdgeInsets.all(5), child: CircularProgressIndicator(strokeWidth: 2)))
                    : Tooltip(
                        message: 'Modificar importe o dividir pagos',
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 19,
                          onPressed: () => onCambiarMedioPago?.call(item.cuenta, pago),
                          icon: Icon(Icons.edit_rounded, color: palette.secondary),
                        ),
                      ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            [
              _cuentaNombreVisible(item.cuenta),
              if ((pago.valorRecibido ?? 0) > 0) 'Recibido ${CurrencyUtils.format(pago.valorRecibido)}',
              if ((pago.cambio ?? 0) > 0) 'Vueltas ${CurrencyUtils.format(pago.cambio)}',
            ].join(' · '),
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HistorialCuentasPanel extends ConsumerWidget {
  const _HistorialCuentasPanel({required this.venta});
  final MeseroVentaModel venta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
            child: Row(children: [Icon(Icons.call_split_rounded, color: palette.secondary), const SizedBox(width: 9), Expanded(child: Text('Distribución por cuentas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary))), Text('${venta.cuentas.length}', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900))]),
          ),
          Divider(height: 1, color: palette.cardBorder),
          if (venta.cuentas.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text('La venta no tiene cuentas registradas.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)))
          else
            for (var i = 0; i < venta.cuentas.length; i++)
              _HistorialCuentaExpansion(
                cuenta: venta.cuentas[i],
                last: i == venta.cuentas.length - 1,
                initiallyExpanded: venta.cuentas.length == 1,
              ),
        ],
      ),
    );
  }
}

class _HistorialCuentaExpansion extends ConsumerWidget {
  const _HistorialCuentaExpansion({required this.cuenta, required this.last, this.initiallyExpanded = false});
  final MeseroCuentaModel cuenta;
  final bool last;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final pagada = cuenta.pagada == true || (cuenta.saldoPendiente ?? 0) <= 0.009;
    final productosLabel = cuenta.productos.length == 1 ? '1 producto' : '${cuenta.productos.length} productos';
    final pagosLabel = cuenta.pagos.length == 1 ? '1 pago' : '${cuenta.pagos.length} pagos';
    return Container(
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
      child: ExpansionTile(
        key: PageStorageKey<String>('historial-cuenta-${cuenta.cuentaId ?? _cuentaNombreVisible(cuenta)}'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: CircleAvatar(
          backgroundColor: palette.secondary.withOpacity(0.14),
          foregroundColor: palette.secondary,
          child: const Icon(Icons.receipt_long_rounded, size: 20),
        ),
        title: Text(_cuentaNombreVisible(cuenta), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
        subtitle: Text('$productosLabel · $pagosLabel', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyUtils.format(cuenta.total), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
                Text(pagada ? 'Pagada' : 'Saldo ${CurrencyUtils.format(cuenta.saldoPendiente)}', style: TextStyle(color: pagada ? AppColors.success : AppColors.danger, fontSize: 10, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.expand_more_rounded, color: palette.textSecondary, size: 21),
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.38 : 0.68), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _detalleLinea(palette, 'Subtotal productos', CurrencyUtils.format(cuenta.subtotalProductos)),
                _detalleLinea(palette, 'Propina', CurrencyUtils.format(cuenta.propina)),
                _detalleLinea(palette, 'Pagado', CurrencyUtils.format(cuenta.totalPagado)),
                _detalleLinea(palette, 'Saldo', CurrencyUtils.format(cuenta.saldoPendiente), danger: (cuenta.saldoPendiente ?? 0) > 0.009),
              ],
            ),
          ),
          if (cuenta.productos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: Text('Productos', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12))),
            const SizedBox(height: 6),
            for (final producto in cuenta.productos)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Expanded(child: Text(producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12))),
                    Text('${_formatCantidadGeneral(producto.cantidad)} × ${CurrencyUtils.format(producto.valorUnitario)}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HistorialCuentaDetallePage extends ConsumerWidget {
  const _HistorialCuentaDetallePage({required this.venta, required this.cuenta});

  final MeseroVentaModel venta;
  final MeseroCuentaModel cuenta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final descripcion = (cuenta.descripcion ?? '').trim();
    final productos = _agruparProductosFactura(cuenta.productos);
    final cambioTotal = cuenta.pagos.fold<double>(0, (sum, pago) => sum + (pago.cambio ?? 0));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_cuentaNombreVisible(cuenta)),
        centerTitle: false,
        foregroundColor: palette.onTitle,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: palette.mainGradient)),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TechGlassTitlePanel(
                        title: 'Detalle de cuenta pagada',
                        subtitle: descripcion.isEmpty ? 'Cuenta sin descripción.' : descripcion,
                        icon: Icons.person_pin_circle_rounded,
                        trailing: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SmallInfoPill(icon: _ventaEsDirecta(venta) ? Icons.point_of_sale_rounded : Icons.table_restaurant_rounded, text: _origenVentaVisible(venta)),
                            _SmallInfoPill(icon: Icons.receipt_long_rounded, text: _cuentaNombreVisible(cuenta)),
                            _SmallInfoPill(icon: cuenta.pagada == true ? Icons.check_circle_rounded : Icons.pending_actions_rounded, text: cuenta.pagada == true ? 'Pagada' : 'Saldo ${CurrencyUtils.format(cuenta.saldoPendiente)}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _historialSection(
                        context,
                        palette,
                        icon: Icons.summarize_rounded,
                        title: 'Resumen de la cuenta',
                        child: Column(
                          children: [
                            _detalleLinea(palette, 'Subtotal productos', CurrencyUtils.format(cuenta.subtotalProductos)),
                            _detalleLinea(palette, 'Propina', CurrencyUtils.format(cuenta.propina)),
                            _detalleLinea(palette, 'Total cuenta', CurrencyUtils.format(cuenta.total), destacado: true),
                            _detalleLinea(palette, 'Total pagado', CurrencyUtils.format(cuenta.totalPagado)),
                            if (cambioTotal > 0) _detalleLinea(palette, 'Vueltas entregadas', CurrencyUtils.format(cambioTotal)),
                            _detalleLinea(palette, 'Saldo pendiente', CurrencyUtils.format(cuenta.saldoPendiente), destacado: true, danger: (cuenta.saldoPendiente ?? 0) > 0.009),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _historialSection(
                        context,
                        palette,
                        icon: Icons.shopping_cart_checkout_rounded,
                        title: 'Productos de esta cuenta',
                        child: productos.isEmpty
                            ? Text('Esta cuenta no tiene productos registrados.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))
                            : Column(children: productos.map((producto) => _productoHistorialTile(palette, producto)).toList(growable: false)),
                      ),
                      const SizedBox(height: 16),
                      _historialSection(
                        context,
                        palette,
                        icon: Icons.payments_rounded,
                        title: 'Pagos de esta cuenta',
                        child: cuenta.pagos.isEmpty
                            ? Text('No hay pagos registrados para esta cuenta.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))
                            : Column(children: cuenta.pagos.map((pago) => _pagoHistorialTile(palette, cuenta, pago)).toList(growable: false)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _historialSection(BuildContext context, AppPalette palette, {required IconData icon, required String title, required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: palette.surface.withOpacity(palette.darkBackground ? 0.86 : 0.92),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: palette.cardBorder),
      boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 20, offset: const Offset(0, 10))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: palette.secondary),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary))),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

BoxDecoration _historialInnerDecoration(AppPalette palette) => BoxDecoration(
      color: palette.background.withOpacity(palette.darkBackground ? 0.50 : 0.60),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: palette.cardBorder),
    );

Widget _productoHistorialTile(AppPalette palette, _FacturaProductoAgrupado producto) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: _historialInnerDecoration(palette),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final name = Text(producto.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary));
        final data = Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _SmallInfoPill(icon: Icons.numbers_rounded, text: 'Cant. ${_formatCantidadGeneral(producto.cantidad)}'),
            _SmallInfoPill(icon: Icons.sell_rounded, text: CurrencyUtils.format(producto.precioUnitario)),
            _SmallInfoPill(icon: Icons.payments_rounded, text: CurrencyUtils.format(producto.total)),
          ],
        );
        if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [name, const SizedBox(height: 10), data]);
        return Row(children: [Expanded(child: name), const SizedBox(width: 12), data]);
      },
    ),
  );
}

Widget _pagoHistorialTile(AppPalette palette, MeseroCuentaModel cuenta, MeseroPagoModel pago) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: _historialInnerDecoration(palette),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(pago.medioPagoNombre ?? 'Medio ${pago.medioPagoId ?? '-'}', style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary))),
            Text(CurrencyUtils.format(pago.valor), style: TextStyle(fontWeight: FontWeight.w900, color: palette.secondary)),
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
}

Widget _detalleLinea(AppPalette palette, String label, String value, {bool destacado = false, bool danger = false}) {
  final color = danger ? AppColors.danger : (destacado ? palette.secondary : palette.textPrimary);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: danger ? AppColors.danger : palette.textSecondary, fontWeight: destacado ? FontWeight.w900 : FontWeight.w700))),
        Text(value, textAlign: TextAlign.right, style: TextStyle(color: color, fontWeight: destacado ? FontWeight.w900 : FontWeight.w800, fontSize: destacado ? 16 : 14)),
      ],
    ),
  );
}

class _HistorialResumenOperacion extends ConsumerWidget {
  const _HistorialResumenOperacion({
    required this.ventas,
    required this.totalVendido,
    required this.totalPagado,
    required this.saldoPendiente,
    required this.propinas,
    required this.ticketPromedio,
  });

  final int ventas;
  final double totalVendido;
  final double totalPagado;
  final double saldoPendiente;
  final double propinas;
  final double ticketPromedio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final items = <_HistorialResumenDato>[
      _HistorialResumenDato(icon: Icons.receipt_long_rounded, label: 'Ventas', value: '$ventas'),
      _HistorialResumenDato(icon: Icons.point_of_sale_rounded, label: 'Total vendido', value: CurrencyUtils.format(totalVendido), highlight: true),
      _HistorialResumenDato(icon: Icons.payments_rounded, label: 'Total cobrado', value: CurrencyUtils.format(totalPagado)),
      _HistorialResumenDato(icon: Icons.pending_actions_rounded, label: 'Saldo pendiente', value: CurrencyUtils.format(saldoPendiente), danger: saldoPendiente > 0.009),
      _HistorialResumenDato(icon: Icons.volunteer_activism_rounded, label: 'Propinas', value: CurrencyUtils.format(propinas)),
      _HistorialResumenDato(icon: Icons.analytics_rounded, label: 'Ticket promedio', value: CurrencyUtils.format(ticketPromedio)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.secondary.withOpacity(0.16)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1100 ? 6 : (constraints.maxWidth >= 720 ? 3 : 2);
          final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) => SizedBox(width: width, child: _HistorialResumenMetrica(item: item))).toList(growable: false),
          );
        },
      ),
    );
  }
}

class _HistorialResumenDato {
  const _HistorialResumenDato({required this.icon, required this.label, required this.value, this.highlight = false, this.danger = false});
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final bool danger;
}

class _HistorialResumenMetrica extends ConsumerWidget {
  const _HistorialResumenMetrica({required this.item});
  final _HistorialResumenDato item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final color = item.danger ? AppColors.danger : (item.highlight ? palette.secondary : palette.textPrimary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.34 : 0.66),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: item.danger ? AppColors.danger : palette.secondary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.5)),
                const SizedBox(height: 3),
                Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorialDiaSection extends ConsumerWidget {
  const _HistorialDiaSection({
    required this.titulo,
    required this.fecha,
    required this.ventas,
    required this.horaVenta,
    required this.onVerDetalle,
  });

  final String titulo;
  final String fecha;
  final List<MeseroVentaModel> ventas;
  final String Function(MeseroVentaModel) horaVenta;
  final ValueChanged<MeseroVentaModel> onVerDetalle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final total = ventas.fold<double>(0, (sum, venta) => sum + (venta.total ?? 0));
    final pagadas = ventas.where((venta) => venta.pagada == true || (venta.saldoPendiente ?? 0) <= 0.009).length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.88 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heading = Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: palette.secondary.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.calendar_today_rounded, color: palette.secondary, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          if (fecha.isNotEmpty)
                            Text(
                              fecha,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );

                final indicadores = Wrap(
                  alignment: constraints.maxWidth >= 820 ? WrapAlignment.end : WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallInfoPill(icon: Icons.receipt_long_rounded, text: '${ventas.length} ventas'),
                    _SmallInfoPill(icon: Icons.check_circle_rounded, text: '$pagadas pagadas'),
                    _TotalPill(total: total),
                  ],
                );

                // Nunca poner Wrap junto a un Expanded mínimo en móviles:
                // las métricas empujaban la fecha a una columna de letras.
                if (constraints.maxWidth < 820) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      const SizedBox(height: 12),
                      indicadores,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: heading),
                    const SizedBox(width: 12),
                    Expanded(flex: 5, child: indicadores),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: palette.cardBorder),
          for (var i = 0; i < ventas.length; i++)
            _HistorialVentaListadoRow(
              venta: ventas[i],
              hora: horaVenta(ventas[i]),
              last: i == ventas.length - 1,
              onTap: () => onVerDetalle(ventas[i]),
            ),
        ],
      ),
    );
  }
}

class _HistorialVentaListadoRow extends ConsumerWidget {
  const _HistorialVentaListadoRow({required this.venta, required this.hora, required this.last, required this.onTap});
  final MeseroVentaModel venta;
  final String hora;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final pagada = venta.pagada == true || (venta.saldoPendiente ?? 0) <= 0.009;
    final descripcion = (venta.mesaDescripcion ?? '').trim();
    final ventaDirecta = (venta.tipoVenta ?? '').trim().toUpperCase() == 'DIRECTA' || venta.mesaId == null;
    final productos = venta.cuentas.fold<int>(0, (sum, cuenta) => sum + cuenta.productos.length);
    final pagos = venta.cuentas.fold<int>(0, (sum, cuenta) => sum + cuenta.pagos.length);
    final medios = venta.cuentas
        .expand((cuenta) => cuenta.pagos)
        .map((pago) => (pago.medioPagoNombre ?? '').trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(2)
        .join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: palette.cardBorder))),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final identity = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ventaDirecta
                      ? Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: palette.secondary.withOpacity(0.14), borderRadius: BorderRadius.circular(15)),
                          child: Icon(Icons.point_of_sale_rounded, color: palette.secondary, size: 23),
                        )
                      : _MesaNumberPhotoBadge(
                          mesaNumero: venta.mesaNumero,
                          mesaFoto: venta.mesaFoto,
                          size: 48,
                          radius: 24,
                          accentColor: palette.secondary,
                          backgroundColor: palette.background.withOpacity(0.72),
                          textColor: Colors.white,
                          compact: true,
                          veryTight: true,
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Venta #${venta.ventaId ?? '-'}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15))),
                            _HistorialEstadoChip(pagada: pagada),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [if (hora.isNotEmpty) hora, ventaDirecta ? 'Venta directa' : (descripcion.isEmpty ? 'Mesa ${venta.mesaNumero ?? '-'}' : descripcion)].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11.5),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 12,
                          runSpacing: 5,
                          children: [
                            _HistorialDatoInline(icon: Icons.call_split_rounded, label: 'Cuentas', value: '${venta.cuentas.length}'),
                            _HistorialDatoInline(icon: Icons.inventory_2_rounded, label: 'Productos', value: '$productos'),
                            _HistorialDatoInline(icon: Icons.payments_rounded, label: 'Pagos', value: '$pagos'),
                            if (medios.isNotEmpty) _HistorialDatoInline(icon: Icons.account_balance_wallet_rounded, label: 'Medios', value: medios),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final totals = Column(
                crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Text(CurrencyUtils.format(venta.total), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 3),
                  Text(
                    pagada ? 'Cobrado ${CurrencyUtils.format(venta.totalPagado ?? venta.total)}' : 'Saldo ${CurrencyUtils.format(venta.saldoPendiente)}',
                    style: TextStyle(color: pagada ? palette.textSecondary : AppColors.danger, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ver detalle', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 12)),
                      const SizedBox(width: 3),
                      Icon(Icons.chevron_right_rounded, color: palette.secondary, size: 20),
                    ],
                  ),
                ],
              );

              if (compact) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, const SizedBox(height: 11), totals]);
              }
              return Row(children: [Expanded(child: identity), const SizedBox(width: 20), totals]);
            },
          ),
        ),
      ),
    );
  }
}

class _HistorialMesaSection extends ConsumerWidget {
  const _HistorialMesaSection({required this.mesa, required this.ventas, required this.onVerDetalle});

  final String mesa;
  final List<MeseroVentaModel> ventas;
  final ValueChanged<MeseroVentaModel> onVerDetalle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final total = ventas.fold<double>(0, (sum, venta) => sum + (venta.total ?? 0));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.86 : 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(mesa, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary))),
              _SmallInfoPill(icon: Icons.receipt_long_rounded, text: '${ventas.length} ventas'),
              const SizedBox(width: 8),
              _TotalPill(total: total),
            ],
          ),
          const SizedBox(height: 12),
          ...ventas.map(
            (venta) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: _historialInnerDecoration(palette),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;
                  final title = Row(
                    children: [
                      Icon(Icons.point_of_sale_rounded, color: palette.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Venta #${venta.ventaId ?? '-'}', style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)),
                            const SizedBox(height: 3),
                            Text([
                              if ((venta.fecha ?? '').trim().isNotEmpty) venta.fecha!,
                              'Estado: ${venta.estado ?? '-'}',
                              '${venta.cuentas.length} cuentas',
                            ].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(CurrencyUtils.format(venta.total), style: TextStyle(fontWeight: FontWeight.w900, color: palette.secondary)),
                      OutlinedButton.icon(
                        onPressed: () => onVerDetalle(venta),
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Ver detalle'),
                      ),
                    ],
                  );
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: compact
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), actions])
                        : Row(children: [Expanded(child: title), const SizedBox(width: 12), actions]),
                  );
                },
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

String _normalizarMedioPagoTexto(String? value) {
  return (value ?? '')
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

String _textoMedioPago(MeseroMedioPagoModel medio) {
  return '${_normalizarMedioPagoTexto(medio.nombre)} ${_normalizarMedioPagoTexto(medio.descripcion)}';
}

IconData _iconoMedioPago(MeseroMedioPagoModel medio) {
  final texto = _textoMedioPago(medio);
  if (texto.contains('efectivo') || texto.contains('cash')) return Icons.payments_rounded;
  if (texto.contains('tarjeta') || texto.contains('credito') || texto.contains('debito') || texto.contains('datafono')) {
    return Icons.credit_card_rounded;
  }
  if (texto.contains('transferencia') || texto.contains('banco') || texto.contains('pse')) {
    return Icons.account_balance_rounded;
  }
  if (texto.contains('nequi') || texto.contains('daviplata') || texto.contains('billetera') || texto.contains('wallet')) {
    return Icons.phone_android_rounded;
  }
  if (texto.contains('qr')) return Icons.qr_code_2_rounded;
  if (texto.contains('bono') || texto.contains('vale')) return Icons.confirmation_number_rounded;
  return Icons.account_balance_wallet_rounded;
}

int _prioridadMedioPago(MeseroMedioPagoModel medio) {
  final texto = _textoMedioPago(medio);
  if (texto.contains('efectivo') || texto.contains('cash')) return 0;
  if (texto.contains('tarjeta') || texto.contains('credito') || texto.contains('debito') || texto.contains('datafono')) return 1;
  if (texto.contains('transferencia') || texto.contains('banco') || texto.contains('pse')) return 2;
  if (texto.contains('nequi')) return 3;
  if (texto.contains('daviplata')) return 4;
  if (texto.contains('billetera') || texto.contains('wallet') || texto.contains('qr')) return 5;
  return 20;
}

String? _qrMedioPago(MeseroMedioPagoModel? medio) {
  final qr = (medio?.qr ?? '').trim();
  return qr.isEmpty ? null : qr;
}

String _nombreQrMedioPago(MeseroMedioPagoModel medio) {
  final texto = _textoMedioPago(medio);
  if (texto.contains('nequi')) return 'Nequi';
  if (texto.contains('daviplata')) return 'Daviplata';
  return medio.nombre ?? 'Billetera digital';
}

class _PagoFormRowData {
  _PagoFormRowData({required this.mediosPago, int? medioPagoId, double? valor, double? valorRecibido})
      : medioPagoId = medioPagoId ?? _defaultMedioPagoId(mediosPago),
        valorController = TextEditingController(text: valor == null || valor <= 0 ? '' : _formatCurrencyInputAmount(valor)),
        valorRecibidoController = TextEditingController(
          text: valorRecibido == null || valorRecibido <= 0 ? '' : _formatCurrencyInputAmount(valorRecibido),
        );

  final List<MeseroMedioPagoModel> mediosPago;
  int? medioPagoId;
  final TextEditingController valorController;
  final TextEditingController valorRecibidoController;
  final Map<int, int> denominaciones = <int, int>{};
  bool efectivoManual = false;

  MeseroMedioPagoModel? get medioPago => _medioPagoById(mediosPago, medioPagoId);

  bool get esEfectivo => _esMedioPagoEfectivo(medioPago);

  double get efectivoSeleccionado => denominaciones.entries.fold<double>(
        0,
        (total, entry) => total + (entry.key * entry.value),
      );

  void sincronizarEfectivoSeleccionado() {
    final total = efectivoSeleccionado;
    valorRecibidoController.text = total <= 0 ? '' : _formatCurrencyInputAmount(total);
  }

  void limpiarDenominaciones({bool limpiarValorRecibido = true}) {
    denominaciones.clear();
    if (limpiarValorRecibido) valorRecibidoController.clear();
  }

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

class _SeleccionCuentaPagoDialog extends ConsumerWidget {
  const _SeleccionCuentaPagoDialog({required this.venta, required this.cuentas});

  final MeseroVentaModel venta;
  final List<MeseroCuentaModel> cuentas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: TechGlassPanel(
        maxWidth: 520,
        padding: const EdgeInsets.all(22),
        dark: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selecciona la cuenta a cobrar', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${_origenVentaVisible(venta)} · Elige la cuenta pendiente que deseas pagar desde la tarjeta.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cuentas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _CuentaPagoRapidoTile(
                  cuenta: cuentas[index],
                  onTap: () => Navigator.of(context).pop(cuentas[index]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeleccionCuentaPagoSheet extends ConsumerWidget {
  const _SeleccionCuentaPagoSheet({required this.venta, required this.cuentas});

  final MeseroVentaModel venta;
  final List<MeseroCuentaModel> cuentas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: palette.translucentBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 46, height: 5, decoration: BoxDecoration(color: palette.translucentBorder, borderRadius: BorderRadius.circular(999))),
              ),
              const SizedBox(height: 14),
              Text('Selecciona la cuenta a cobrar', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${_origenVentaVisible(venta)} · Pago rápido desde la tarjeta.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.52),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cuentas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _CuentaPagoRapidoTile(
                    cuenta: cuentas[index],
                    onTap: () => Navigator.of(context).pop(cuentas[index]),
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

class _CuentaPagoRapidoTile extends ConsumerWidget {
  const _CuentaPagoRapidoTile({required this.cuenta, required this.onTap});

  final MeseroCuentaModel cuenta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final pendiente = cuenta.saldoPendiente ?? cuenta.total ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.90),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.translucentBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: palette.mainGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_cuentaNombreVisible(cuenta), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Pendiente: ${CurrencyUtils.format(pendiente)}', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
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
  AppPalette get _palette => ProviderScope.containerOf(context).read(selectedAppPaletteProvider);
  AppPalette get palette => _palette;

  final _formKey = GlobalKey<FormState>();
  final ScrollController _pagosScrollController = ScrollController();
  late final TextEditingController _propinaController;
  bool _servicioSugeridoSeleccionado = false;
  late final List<_PagoFormRowData> _pagos;
  late double _ultimaPropinaSincronizada;
  bool _mostrarDetalleProductos = false;
  int _cantidadPagosSeleccionada = 1;
  int _pagoActivoIndex = 0;
  final Set<int> _pagosListos = <int>{};

  @override
  void initState() {
    super.initState();
    _ultimaPropinaSincronizada = 0;
    _propinaController = TextEditingController();
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
    _pagosScrollController.dispose();
    _propinaController.dispose();
    for (final pago in _pagos) {
      pago.dispose();
    }
    super.dispose();
  }

  double _parse(String value) => _parseCurrencyInput(value);

  double get _propina => _parse(_propinaController.text);

  // Servicio sugerido, voluntario y calculado únicamente sobre productos pendientes
  // de esta cuenta: evita cobrar propina dos veces por productos ya pagados.
  double get _servicioSugerido => (_subtotalProductos * 0.10).roundToDouble();

  void _seleccionarServicioSugerido(bool selected) {
    setState(() {
      _servicioSugeridoSeleccionado = selected;
      _propinaController.text = selected
          ? _formatCurrencyInputAmount(_servicioSugerido)
          : '';
      _sincronizarPagosPorCambioPropina();
    });
  }

  double get _propinaRegistrada => (widget.cuenta.propina ?? 0).toDouble();

  double get _propinaTotal => _propinaRegistrada + _propina;

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

  double get _propinaPendienteExistente =>
      (_propinaRegistrada - _propinaPagadaEstimada).clamp(0, double.infinity).toDouble();

  double get _propinaPendiente => _propinaPendienteExistente + _propina;

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

  double get _totalPagosConfirmadosEnFlujo {
    var total = 0.0;
    for (final index in _pagosListos) {
      if (index < 0 || index >= _pagos.length) continue;
      total += _parse(_pagos[index].valorController.text);
    }
    return total;
  }

  double get _saldoPorRegistrarEnFlujo =>
      (_totalCuenta - _totalPagosConfirmadosEnFlujo).clamp(0, double.infinity).toDouble();

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

  bool get _esVentaDirecta => _ventaEsDirecta(widget.venta);

  bool get _modoRapidoVentaDirecta => _esVentaDirecta && _pagos.length == 1;

  void _sincronizarPagosPorCambioPropina() {
    _pagosListos.clear();
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
    pago.valorController.text = _formatInputAmount(valorActual + diferencia);
  }

  void _disminuirPagosDesdeElUltimo(double diferencia) {
    var pendientePorDescontar = diferencia;

    for (final pago in _pagos.reversed) {
      if (pendientePorDescontar <= 0.009) break;

      final valorActual = _parse(pago.valorController.text);
      if (valorActual <= 0) continue;

      final descuento = valorActual < pendientePorDescontar ? valorActual : pendientePorDescontar;
      final nuevoValor = valorActual - descuento;
      pago.valorController.text = nuevoValor <= 0 ? '' : _formatInputAmount(nuevoValor);
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
  }

  void _completarPagosEfectivoPendientes() {
    for (final pago in _pagos) {
      _completarEfectivoConSaldoPendiente(pago);
    }
  }

  String _formatCantidad(num? value) => _formatCantidadGeneral(value);

  double _valorPagoRepartido(int index, int cantidadPagos) {
    if (cantidadPagos <= 0) return 0;
    final centavos = (_totalCuenta * 100).round();
    final base = centavos ~/ cantidadPagos;
    final asignadosAntes = base * (cantidadPagos - 1);
    final valorCentavos = index == cantidadPagos - 1 ? centavos - asignadosAntes : base;
    return valorCentavos / 100.0;
  }

  void _configurarCantidadPagos(int cantidad) {
    if (cantidad < 1 || cantidad > 5 || cantidad == _cantidadPagosSeleccionada) return;
    setState(() {
      for (final pago in _pagos) {
        pago.dispose();
      }
      _pagos
        ..clear()
        ..addAll(List.generate(
          cantidad,
          (index) => _PagoFormRowData(
            mediosPago: widget.mediosPago,
            valor: _valorPagoRepartido(index, cantidad),
          ),
        ));
      _cantidadPagosSeleccionada = cantidad;
      _pagoActivoIndex = 0;
      _pagosListos.clear();
    });
  }

  void _repartirPagosPorIgual() {
    setState(() {
      _pagosListos.clear();
      for (var index = 0; index < _pagos.length; index++) {
        _pagos[index].valorController.text = _formatInputAmount(_valorPagoRepartido(index, _pagos.length));
      }
    });
  }

  void _eliminarPagoEnPreparacion(int index) {
    if (_pagos.length <= 1 || index < 0 || index >= _pagos.length) return;
    setState(() {
      final eliminado = _pagos.removeAt(index);
      eliminado.dispose();
      _cantidadPagosSeleccionada = _pagos.length;
      _pagosListos.clear();

      final totalActual = _pagos.fold<double>(0, (sum, pago) => sum + _parse(pago.valorController.text));
      final diferencia = _totalCuenta - totalActual;
      if (_pagos.isNotEmpty && diferencia.abs() > 0.009) {
        final compensador = _pagos.last;
        final nuevoValor = (_parse(compensador.valorController.text) + diferencia).clamp(0, double.infinity).toDouble();
        compensador.valorController.text = nuevoValor <= 0.009 ? '' : _formatInputAmount(nuevoValor);
      }

      if (_pagos.isEmpty) {
        _pagoActivoIndex = 0;
      } else {
        _pagoActivoIndex = index.clamp(0, _pagos.length - 1).toInt();
      }
    });
  }

  void _sincronizarPagoRestante(int indexEditado) {
    if (_pagos.length <= 1 || indexEditado < 0 || indexEditado >= _pagos.length) return;

    final indexCompensador = indexEditado == _pagos.length - 1 ? _pagos.length - 2 : _pagos.length - 1;
    var totalFijo = 0.0;
    for (var index = 0; index < _pagos.length; index++) {
      if (index == indexEditado || index == indexCompensador) continue;
      totalFijo += _parse(_pagos[index].valorController.text);
    }

    final maximoEditable = (_totalCuenta - totalFijo).clamp(0.0, double.infinity).toDouble();
    var valorEditado = _parse(_pagos[indexEditado].valorController.text);
    if (valorEditado > maximoEditable) {
      valorEditado = maximoEditable;
      _pagos[indexEditado].valorController.text = _formatInputAmount(valorEditado);
      _pagos[indexEditado].valorController.selection = TextSelection.collapsed(
        offset: _pagos[indexEditado].valorController.text.length,
      );
    }

    final restante = (maximoEditable - valorEditado).clamp(0.0, double.infinity).toDouble();
    _pagos[indexCompensador].valorController.text = restante <= 0.009 ? '' : _formatInputAmount(restante);
  }

  int get _primerPagoPendienteIndex {
    for (var index = 0; index < _pagos.length; index++) {
      if (!_pagosListos.contains(index)) return index;
    }
    return _pagos.isEmpty ? 0 : _pagos.length - 1;
  }

  void _invalidarPagoDesde(int index) {
    _pagosListos.removeWhere((item) => item >= index);
  }

  void _invalidarPago(_PagoFormRowData pago) {
    final index = _pagos.indexOf(pago);
    if (index >= 0) _invalidarPagoDesde(index);
  }

  String? _errorPagoIndividual(int index) {
    if (index < 0 || index >= _pagos.length) return 'No se encontró el pago seleccionado.';
    final pago = _pagos[index];
    final valor = _parse(pago.valorController.text);
    if (pago.medioPagoId == null) return 'Selecciona el medio de pago del Pago ${index + 1}.';
    if (valor <= 0) return 'Ingresa un valor válido para el Pago ${index + 1}.';
    if (pago.esEfectivo) {
      final recibido = pago.efectivoManual
          ? _parse(pago.valorRecibidoController.text)
          : pago.efectivoSeleccionado;
      if (recibido <= 0) return 'Registra el efectivo recibido del Pago ${index + 1}.';
      if (recibido + 0.009 < valor) return 'El efectivo del Pago ${index + 1} no alcanza para cubrir su valor.';
    }
    return null;
  }

  void _subirAlInicioPagos() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pagosScrollController.hasClients) return;
      _pagosScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _registrarPagoActualYContinuar() {
    if (_pagos.isEmpty) return;
    final index = _pagoActivoIndex.clamp(0, _pagos.length - 1).toInt();
    final error = _errorPagoIndividual(index);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final esUltimo = index == _pagos.length - 1;
    setState(() {
      _pagosListos.add(index);
      if (!esUltimo) {
        var siguiente = index + 1;
        while (siguiente < _pagos.length && _pagosListos.contains(siguiente)) {
          siguiente++;
        }
        _pagoActivoIndex = siguiente < _pagos.length ? siguiente : _pagos.length - 1;
      }
    });

    if (esUltimo) {
      _guardarPago();
    } else {
      _subirAlInicioPagos();
    }
  }

  void _seleccionarPago(int index) {
    if (index < 0 || index >= _pagos.length) return;
    final primerPendiente = _primerPagoPendienteIndex;
    if (!_pagosListos.contains(index) && index > primerPendiente) return;
    setState(() => _pagoActivoIndex = index);
  }

  static const List<int> _billetesColombia = <int>[100000, 50000, 20000, 10000, 5000, 2000];
  static const List<int> _monedasColombia = <int>[1000, 500, 200, 100, 50];

  Map<int, int>? _descomposicionDenominacion(int valor) {
    switch (valor) {
      case 100000:
        return const <int, int>{50000: 2};
      case 50000:
        return const <int, int>{20000: 2, 10000: 1};
      case 20000:
        return const <int, int>{10000: 2};
      case 10000:
        return const <int, int>{5000: 2};
      case 5000:
        return const <int, int>{2000: 2, 1000: 1};
      case 2000:
        return const <int, int>{1000: 2};
      case 1000:
        return const <int, int>{500: 2};
      case 500:
        return const <int, int>{200: 2, 100: 1};
      case 200:
        return const <int, int>{100: 2};
      case 100:
        return const <int, int>{50: 2};
      default:
        return null;
    }
  }

  void _sumarDenominacion(_PagoFormRowData pago, int valor, {FormFieldState<double>? field}) {
    setState(() {
      _invalidarPago(pago);
      pago.denominaciones[valor] = (pago.denominaciones[valor] ?? 0) + 1;
      pago.sincronizarEfectivoSeleccionado();
      field?.didChange(pago.efectivoSeleccionado);
    });
  }

  void _restarDenominacion(_PagoFormRowData pago, int valor, {FormFieldState<double>? field}) {
    final actual = pago.denominaciones[valor] ?? 0;
    if (actual <= 0) return;
    setState(() {
      _invalidarPago(pago);
      if (actual == 1) {
        pago.denominaciones.remove(valor);
      } else {
        pago.denominaciones[valor] = actual - 1;
      }
      pago.sincronizarEfectivoSeleccionado();
      field?.didChange(pago.efectivoSeleccionado);
    });
  }

  void _desagregarDenominacion(_PagoFormRowData pago, int valor, {FormFieldState<double>? field}) {
    final actual = pago.denominaciones[valor] ?? 0;
    final desglose = _descomposicionDenominacion(valor);
    if (actual <= 0 || desglose == null) return;
    setState(() {
      _invalidarPago(pago);
      if (actual == 1) {
        pago.denominaciones.remove(valor);
      } else {
        pago.denominaciones[valor] = actual - 1;
      }
      for (final entry in desglose.entries) {
        pago.denominaciones[entry.key] = (pago.denominaciones[entry.key] ?? 0) + entry.value;
      }
      pago.sincronizarEfectivoSeleccionado();
      field?.didChange(pago.efectivoSeleccionado);
    });
  }

  void _cambiarModoEfectivo(_PagoFormRowData pago, bool manual) {
    if (pago.efectivoManual == manual) return;
    setState(() {
      _invalidarPago(pago);
      if (manual) {
        final seleccionado = pago.efectivoSeleccionado;
        pago.efectivoManual = true;
        pago.limpiarDenominaciones(limpiarValorRecibido: false);
        if (seleccionado > 0) {
          pago.valorRecibidoController.text = _formatInputAmount(seleccionado);
        }
      } else {
        pago.efectivoManual = false;
        pago.limpiarDenominaciones();
      }
    });
  }

  void _marcarPagoExacto(_PagoFormRowData pago) {
    final aplicado = _parse(pago.valorController.text);
    if (!pago.esEfectivo || aplicado <= 0) return;
    setState(() {
      _invalidarPago(pago);
      pago.efectivoManual = true;
      pago.denominaciones.clear();
      pago.valorRecibidoController.text = _formatInputAmount(aplicado);
    });
  }

  void _limpiarDenominaciones(_PagoFormRowData pago, {FormFieldState<double>? field}) {
    setState(() {
      _invalidarPago(pago);
      pago.limpiarDenominaciones();
      field?.didChange(0);
    });
  }

  _PagarCuentaResult _crearResultadoPago() {
    return _PagarCuentaResult(
      propina: _propinaTotal,
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

  int? _primerPagoInvalido() {
    for (var index = 0; index < _pagos.length; index++) {
      final pago = _pagos[index];
      final valor = _parse(pago.valorController.text);
      if (pago.medioPagoId == null || valor <= 0) return index;
      if (pago.esEfectivo) {
        final recibido = pago.efectivoManual
            ? _parse(pago.valorRecibidoController.text)
            : pago.efectivoSeleccionado;
        if (recibido + 0.009 < valor) return index;
      }
    }
    return null;
  }

  void _guardarPago() {
    _completarPagosEfectivoPendientes();
    final pagoInvalido = _primerPagoInvalido();
    if (pagoInvalido != null) {
      setState(() => _pagoActivoIndex = pagoInvalido);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _modoRapidoVentaDirecta
                ? 'Completa la información del cobro.'
                : 'Completa la información del Pago ${pagoInvalido + 1}.',
          ),
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_totalPagos > _totalCuenta + 0.009) return;
    if (_hayEfectivoConValorRecibidoInvalido) return;
    Navigator.of(context).pop(_crearResultadoPago());
  }

  Widget _buildFormularioPago(
    BuildContext context, {
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SingleChildScrollView(
        controller: _pagosScrollController,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_modoRapidoVentaDirecta) ...[
              _buildMediosPagoFactura(context),
              const SizedBox(height: 14),
              _buildPropinaFactura(),
            ] else ...[
              _buildPropinaFactura(),
              const SizedBox(height: 14),
              _buildMediosPagoFactura(context),
            ],
            const SizedBox(height: 14),
            _buildProductosFactura(context),
            if (_totalPagos > _totalCuenta + 0.009)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _MensajeCobroError(
                  text: 'El valor aplicado no puede superar el total por cobrar.',
                ),
              ),
            if (_hayEfectivoConValorRecibidoInvalido)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _MensajeCobroError(
                  text: 'En efectivo, el valor recibido no puede ser menor al valor aplicado.',
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraAccionesPantalla() {
    final palette = _palette;
    final pagoCompleto = _saldo <= 0.009 && _totalPagos > 0;
    final flujoPorPasos = _pagos.length > 1;
    final cobroRapido = _modoRapidoVentaDirecta;
    final pagoActivoSeguro = _pagos.isEmpty ? 0 : _pagoActivoIndex.clamp(0, _pagos.length - 1).toInt();
    final pagoActivoListo = flujoPorPasos && _pagosListos.contains(pagoActivoSeguro);
    final ultimoPaso = !flujoPorPasos || pagoActivoSeguro == _pagos.length - 1;
    final saldoDespues = flujoPorPasos
        ? _saldoPorRegistrarEnFlujo
        : _totalCuenta.clamp(0, double.infinity).toDouble();

    final actionLabel = flujoPorPasos
        ? (pagoActivoListo
            ? (ultimoPaso ? 'Finalizar cobro' : 'Continuar al Pago ${pagoActivoSeguro + 2}')
            : (ultimoPaso
                ? 'Registrar Pago ${pagoActivoSeguro + 1} y finalizar'
                : 'Registrar Pago ${pagoActivoSeguro + 1} y continuar'))
        : (cobroRapido
            ? 'Cobrar y finalizar'
            : (pagoCompleto ? 'Confirmar pago' : 'Registrar pago'));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.985 : 0.998),
        border: Border(top: BorderSide(color: palette.secondary.withOpacity(0.14))),
        boxShadow: [BoxShadow(color: palette.cardShadow, blurRadius: 24, offset: const Offset(0, -8))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          final saldo = Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (saldoDespues > 0.009 ? palette.primary : AppColors.success).withOpacity(0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  saldoDespues > 0.009 ? Icons.account_balance_wallet_outlined : Icons.task_alt_rounded,
                  color: saldoDespues > 0.009 ? palette.primary : AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flujoPorPasos
                          ? (pagoActivoListo ? 'Pago ${pagoActivoSeguro + 1} listo' : 'Pago ${pagoActivoSeguro + 1} de ${_pagos.length}')
                          : (cobroRapido ? 'Venta directa · Total' : 'Total por registrar'),
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 11.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      saldoDespues > 0.009 ? CurrencyUtils.format(saldoDespues) : 'Listo para finalizar',
                      style: TextStyle(
                        color: saldoDespues > 0.009 ? palette.textPrimary : AppColors.success,
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 20 : 22,
                      ),
                    ),
                  ],
                ),
              ),
              if (_totalCambio > 0.009) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success.withOpacity(0.22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Vuelta', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.5)),
                      Text(CurrencyUtils.format(_totalCambio), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ],
          );

          final actions = Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: flujoPorPasos ? _registrarPagoActualYContinuar : _guardarPago,
                  icon: Icon(
                    flujoPorPasos
                        ? (ultimoPaso ? Icons.check_circle_rounded : Icons.arrow_forward_rounded)
                        : Icons.point_of_sale_rounded,
                  ),
                  label: Text(actionLabel, textAlign: TextAlign.center),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                saldo,
                const SizedBox(height: 10),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: saldo),
              const SizedBox(width: 16),
              SizedBox(width: 390, child: actions),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final descripcion = (widget.cuenta.descripcion ?? '').trim();
    final palette = _palette;

    final content = Column(
      children: [
        _buildDialogHeader(descripcion),
        Expanded(
          child: _buildFormularioPago(
            context,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          ),
        ),
        _buildBarraAccionesPantalla(),
      ],
    );

    if (widget.mostrarComoPagina) {
      return Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(child: content),
      );
    }

    return Material(
      color: palette.background,
      elevation: 28,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(30)),
        side: BorderSide(color: palette.secondary.withOpacity(0.18)),
      ),
      child: content,
    );
  }

  Widget _buildDialogHeader(String descripcion) {
    final palette = _palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.primary.withOpacity(0.20),
            palette.secondary.withOpacity(0.10),
            palette.surface.withOpacity(0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: palette.secondary.withOpacity(0.16))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.background.withOpacity(palette.darkBackground ? 0.56 : 0.82),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: palette.secondary.withOpacity(0.20)),
                ),
                child: Icon(Icons.point_of_sale_rounded, color: palette.secondary, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modoRapidoVentaDirecta
                          ? 'Cobro rápido'
                          : (_esVentaDirecta ? 'Cobrar venta directa' : 'Cobrar cuenta'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: palette.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _modoRapidoVentaDirecta
                          ? '${_origenVentaVisible(widget.venta)} · Mostrador'
                          : '${_origenVentaVisible(widget.venta)} · ${_cuentaEtiquetaVisible(widget.cuenta)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
                    ),
                    if (descripcion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        descripcion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary.withOpacity(0.84), fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final total = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(palette.darkBackground ? 0.58 : 0.84),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.secondary.withOpacity(0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Total por cobrar', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(CurrencyUtils.format(_totalCuenta), style: TextStyle(color: palette.secondary, fontSize: 30, fontWeight: FontWeight.w900, height: 1.0)),
                const SizedBox(height: 2),
                Text('Venta #${widget.venta.ventaId ?? '-'}', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          );

          final close = IconButton(
            tooltip: 'Cerrar cobro',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [Expanded(child: identity), close]),
                const SizedBox(height: 12),
                total,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 14),
              total,
              const SizedBox(width: 4),
              close,
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductosFactura(BuildContext context) {
    final palette = _palette;
    final productos = _productosAgrupadosFactura;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: productos.isEmpty ? null : () => setState(() => _mostrarDetalleProductos = !_mostrarDetalleProductos),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
                      child: Icon(Icons.receipt_long_rounded, color: palette.secondary, size: 20),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Detalle de productos', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            productos.isEmpty ? 'No hay productos pendientes.' : '${productos.length} producto${productos.length == 1 ? '' : 's'} por cobrar',
                            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(CurrencyUtils.format(_subtotalProductos), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
                    if (productos.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(_mostrarDetalleProductos ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: palette.textSecondary),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_mostrarDetalleProductos && productos.isNotEmpty) ...[
            Divider(height: 1, color: palette.cardBorder),
            Padding(
              padding: const EdgeInsets.all(14),
              child: MediaQuery.sizeOf(context).width < 760 ? _buildProductosMovil(productos) : _buildProductosTabla(productos),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductosTabla(List<_FacturaProductoAgrupado> productos) {
    final palette = _palette;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(palette.darkBackground ? 0.52 : 0.72),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              SizedBox(width: 70, child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.w900, color: palette.textSecondary))),
              Expanded(flex: 4, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.w900, color: palette.textSecondary))),
              Expanded(flex: 2, child: Text('Precio', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textSecondary))),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textSecondary))),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...productos.map((producto) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: palette.background.withOpacity(palette.darkBackground ? 0.36 : 0.58),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Row(
                children: [
                  SizedBox(width: 70, child: Text(_formatCantidad(producto.cantidad), style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary))),
                  Expanded(flex: 4, child: Text(producto.nombre, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary))),
                  Expanded(flex: 2, child: Text(CurrencyUtils.format(producto.precioUnitario), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textSecondary))),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: Text(CurrencyUtils.format(producto.total), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: palette.secondary))),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildProductosMovil(List<_FacturaProductoAgrupado> productos) {
    final palette = _palette;
    return Column(
      children: productos.map((producto) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.66),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(producto.nombre, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)),
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
          )).toList(growable: false),
    );
  }

  Widget _miniDatoFactura(String label, String value, {bool alignEnd = false}) {
    final palette = _palette;
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)),
      ],
    );
  }

  Widget _buildPropinaFactura() {
    final palette = _palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.92 : 0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final info = Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.volunteer_activism_rounded, color: palette.secondary, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Propina', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      _propinaRegistrada > 0
                          ? 'Registrada ${CurrencyUtils.format(_propinaRegistrada)} · agrega solo una propina nueva si aplica.'
                          : 'El servicio del 10 % es sugerido y solo se agrega si el cliente lo acepta.',
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );

          final controls = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Servicio sugerido (10 %)', style: TextStyle(
                fontWeight: FontWeight.w800, color: palette.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Opcional y sujeto a la aceptación del cliente. Calculado sobre productos pendientes: ${CurrencyUtils.format(_subtotalProductos)}.',
                style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                  label: Text('Agregar 10 % · ${CurrencyUtils.format(_servicioSugerido)}'),
                  selected: _servicioSugeridoSeleccionado,
                  onSelected: (_) => _seleccionarServicioSugerido(!_servicioSugeridoSeleccionado),
                ),
                ChoiceChip(
                  label: const Text('Sin servicio'),
                  selected: !_servicioSugeridoSeleccionado && _propina == 0,
                  onSelected: (_) => _seleccionarServicioSugerido(false),
                ),
              ]),
            ],
          );

          final field = TextFormField(
            controller: _propinaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _tipCurrencyInputFormatters,
            decoration: const InputDecoration(
              labelText: 'Agregar propina adicional',
              hintText: '0',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
            onChanged: (_) => setState(() {
              _servicioSugeridoSeleccionado = false;
              _sincronizarPagosPorCambioPropina();
            }),
            validator: (value) => _parse(value ?? '') < 0 ? 'La propina no puede ser negativa' : null,
          );

          if (compact) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 12), controls, const SizedBox(height: 12), field]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 12), controls, const SizedBox(height: 12), field]);
        },
      ),
    );
  }

  Widget _buildMediosPagoFactura(BuildContext context) {
    final palette = _palette;
    final multipago = _pagos.length > 1;
    final cobroRapido = _modoRapidoVentaDirecta;
    final pagoActivoSeguro = _pagos.isEmpty ? 0 : _pagoActivoIndex.clamp(0, _pagos.length - 1).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.995),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.secondary.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.14), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cobroRapido ? 'Forma de pago' : 'Forma de cobro',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cobroRapido
                          ? 'Elige cómo pagó el cliente. Usa varios medios solo cuando realmente lo necesites.'
                          : (multipago ? 'Configura cada pago por pasos.' : 'Selecciona el medio y registra el valor recibido.'),
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  cobroRapido ? 'VENTA DIRECTA' : '${_pagos.length} pago${_pagos.length == 1 ? '' : 's'}',
                  style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (cobroRapido)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _configurarCantidadPagos(2),
                icon: const Icon(Icons.call_split_rounded, size: 18),
                label: const Text('Varios medios'),
              ),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Cantidad:', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 11)),
                for (var cantidad = 1; cantidad <= 5; cantidad++)
                  ChoiceChip(
                    label: Text('$cantidad'),
                    selected: _cantidadPagosSeleccionada == cantidad,
                    onSelected: (_) => _configurarCantidadPagos(cantidad),
                    visualDensity: VisualDensity.compact,
                  ),
                if (multipago)
                  ActionChip(
                    avatar: const Icon(Icons.balance_rounded, size: 16),
                    label: const Text('Repartir por igual'),
                    onPressed: _repartirPagosPorIgual,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          if (multipago) ...[
            const SizedBox(height: 16),
            _buildStepperPagos(),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: palette.background.withOpacity(palette.darkBackground ? 0.46 : 0.68),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _pagosListos.contains(pagoActivoSeguro)
                          ? 'Pago ${pagoActivoSeguro + 1} listo para continuar'
                          : 'Estás registrando Pago ${pagoActivoSeguro + 1} de ${_pagos.length}',
                      style: TextStyle(
                        color: _pagosListos.contains(pagoActivoSeguro) ? AppColors.success : palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Por registrar ${CurrencyUtils.format(_saldoPorRegistrarEnFlujo)}',
                    style: TextStyle(
                      color: _saldoPorRegistrarEnFlujo > 0.009 ? palette.primary : AppColors.success,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_pagos.isNotEmpty) _buildMedioPagoCard(pagoActivoSeguro),
        ],
      ),
    );
  }

  Widget _buildStepperPagos() {
    final palette = _palette;
    if (_pagos.length <= 1) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < _pagos.length; index++) ...[
              Expanded(
                child: InkWell(
                  onTap: (_pagosListos.contains(index) || index <= _primerPagoPendienteIndex) ? () => _seleccionarPago(index) : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _pagosListos.contains(index)
                                ? AppColors.success
                                : (index == _pagoActivoIndex ? palette.secondary : palette.background),
                            border: Border.all(
                              color: _pagosListos.contains(index)
                                  ? AppColors.success
                                  : (index == _pagoActivoIndex ? palette.secondary : palette.cardBorder),
                              width: 1.5,
                            ),
                          ),
                          child: _pagosListos.contains(index)
                              ? Icon(Icons.check_rounded, size: 19, color: Theme.of(context).colorScheme.onPrimary)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: index == _pagoActivoIndex ? Theme.of(context).colorScheme.onSecondary : palette.textSecondary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pago ${index + 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _pagosListos.contains(index)
                                ? AppColors.success
                                : (index == _pagoActivoIndex ? palette.secondary : palette.textSecondary),
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                          ),
                        ),
                        Text(
                          _pagosListos.contains(index) ? 'Listo' : (index == _pagoActivoIndex ? 'En curso' : 'Pendiente'),
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index < _pagos.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 19),
                  child: Container(
                    width: constraints.maxWidth < 430 ? 8 : 18,
                    height: 2,
                    color: _pagosListos.contains(index) ? AppColors.success.withOpacity(0.65) : palette.cardBorder,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  void _seleccionarMedioPago(_PagoFormRowData pago, int? medioPagoId) {
    setState(() {
      _invalidarPago(pago);
      final eraEfectivo = pago.esEfectivo;
      pago.medioPagoId = medioPagoId;
      if (pago.esEfectivo) {
        _completarEfectivoConSaldoPendiente(pago);
        if (!eraEfectivo) {
          pago.efectivoManual = false;
          pago.limpiarDenominaciones();
        }
      } else {
        pago.efectivoManual = false;
        pago.limpiarDenominaciones();
      }
    });
  }

  Future<void> _mostrarOtrosMediosPago(_PagoFormRowData pago, List<MeseroMedioPagoModel> otros) async {
    final seleccionado = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = _palette;
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: palette.secondary.withOpacity(0.16)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(color: palette.cardBorder, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Otros medios de pago', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: palette.textPrimary)),
              const SizedBox(height: 4),
              Text('Selecciona una opción para este pago.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.56),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: otros.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: palette.cardBorder),
                  itemBuilder: (context, index) {
                    final medio = otros[index];
                    final selected = medio.medioPagoId == pago.medioPagoId;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: palette.secondary.withOpacity(selected ? 0.18 : 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_iconoMedioPago(medio), color: palette.secondary),
                      ),
                      title: Text(medio.nombre ?? 'Medio ${medio.medioPagoId ?? '-'}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                      subtitle: (medio.descripcion ?? '').trim().isEmpty
                          ? null
                          : Text(medio.descripcion!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary)),
                      trailing: selected ? Icon(Icons.check_circle_rounded, color: palette.secondary) : Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
                      onTap: medio.medioPagoId == null ? null : () => Navigator.of(sheetContext).pop(medio.medioPagoId),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || seleccionado == null) return;
    _seleccionarMedioPago(pago, seleccionado);
  }

  Widget _buildSelectorVisualMedioPago(_PagoFormRowData pago) {
    final palette = _palette;
    final disponibles = widget.mediosPago.where((medio) => medio.medioPagoId != null).toList(growable: false)
      ..sort((a, b) {
        final prioridad = _prioridadMedioPago(a).compareTo(_prioridadMedioPago(b));
        if (prioridad != 0) return prioridad;
        return (a.nombre ?? '').toLowerCase().compareTo((b.nombre ?? '').toLowerCase());
      });

    final destacados = <MeseroMedioPagoModel>[];
    final otros = <MeseroMedioPagoModel>[];
    for (final medio in disponibles) {
      if (destacados.length < 5 && _prioridadMedioPago(medio) < 20) {
        destacados.add(medio);
      } else {
        otros.add(medio);
      }
    }
    if (destacados.isEmpty) {
      for (final medio in disponibles.take(4)) {
        destacados.add(medio);
      }
      otros.removeWhere((medio) => destacados.any((item) => item.medioPagoId == medio.medioPagoId));
      if (otros.isEmpty && disponibles.length > destacados.length) {
        otros.addAll(disponibles.skip(destacados.length));
      }
    }

    final seleccionadoEnOtros = otros.any((medio) => medio.medioPagoId == pago.medioPagoId);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final columns = compact ? 2 : (constraints.maxWidth < 760 ? 3 : 5);
        final spacing = 8.0;
        final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        final items = <Widget>[
          for (final medio in destacados)
            _MedioPagoVisualButton(
              width: itemWidth,
              icon: _iconoMedioPago(medio),
              label: medio.nombre ?? 'Medio',
              selected: medio.medioPagoId == pago.medioPagoId,
              onTap: () => _seleccionarMedioPago(pago, medio.medioPagoId),
            ),
          if (otros.isNotEmpty)
            _MedioPagoVisualButton(
              width: itemWidth,
              icon: seleccionadoEnOtros ? _iconoMedioPago(_medioPagoById(widget.mediosPago, pago.medioPagoId) ?? otros.first) : Icons.more_horiz_rounded,
              label: seleccionadoEnOtros
                  ? (_medioPagoById(widget.mediosPago, pago.medioPagoId)?.nombre ?? 'Otro')
                  : 'Otro',
              selected: seleccionadoEnOtros,
              onTap: () => _mostrarOtrosMediosPago(pago, otros),
            ),
        ];

        return Wrap(spacing: spacing, runSpacing: spacing, children: items);
      },
    );
  }

  Widget _buildQrMedioPago(MeseroMedioPagoModel medio) {
    final palette = _palette;
    final qrValue = _qrMedioPago(medio);
    if (qrValue == null) return const SizedBox.shrink();
    final nombre = _nombreQrMedioPago(medio);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(palette.darkBackground ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.secondary.withOpacity(0.20)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final qrSize = compact
              ? (constraints.maxWidth - 28).clamp(230.0, 310.0).toDouble()
              : 270.0;
          final qr = Container(
            width: qrSize,
            height: qrSize,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.secondary.withOpacity(0.24)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _BarlyticsImage(
                value: qrValue,
                width: qrSize - 24,
                height: qrSize - 24,
                radius: 10,
                fit: BoxFit.contain,
              ),
            ),
          );

          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.secondary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.qr_code_scanner_rounded, color: palette.secondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pagar con $nombre',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'El cliente puede escanear el código sin salir del cobro.',
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.background.withOpacity(palette.darkBackground ? 0.44 : 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 18, color: palette.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Confirma la recepción del dinero antes de registrar el pago.',
                        style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                info,
                const SizedBox(height: 14),
                Center(child: qr),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: info),
              const SizedBox(width: 18),
              qr,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMedioPagoCard(int index) {
    final palette = _palette;
    final pago = _pagos[index];
    MeseroMedioPagoModel? medioSeleccionado;
    for (final medio in widget.mediosPago) {
      if (medio.medioPagoId == pago.medioPagoId) {
        medioSeleccionado = medio;
        break;
      }
    }
    final listo = _pagosListos.contains(index);
    final cobroRapido = _modoRapidoVentaDirecta;

    final valueField = TextFormField(
      controller: pago.valorController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _wholeCurrencyInputFormatters,
      textAlign: TextAlign.center,
      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 28),
      decoration: InputDecoration(
        labelText: 'Monto de este pago',
        hintText: '25.000',
        prefixIcon: const Icon(Icons.attach_money_rounded),
        suffixIcon: IconButton(
          tooltip: 'Completar con saldo pendiente',
          onPressed: () => setState(() {
            _invalidarPagoDesde(index == _pagos.length - 1 && index > 0 ? index - 1 : index);
            _completarValorPagoConSaldoPendiente(pago, sobrescribir: true);
            _sincronizarPagoRestante(index);
          }),
          icon: const Icon(Icons.auto_fix_high_rounded),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      ),
      onChanged: (_) {
        setState(() {
          _invalidarPagoDesde(index == _pagos.length - 1 && index > 0 ? index - 1 : index);
          _sincronizarPagoRestante(index);
        });
      },
      validator: (value) {
        if (pago.medioPagoId == null) return 'Selecciona un medio de pago';
        return _parse(value ?? '') <= 0 ? 'Ingresa un valor mayor a cero' : null;
      },
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.48 : 0.76),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: listo ? AppColors.success.withOpacity(0.50) : palette.secondary.withOpacity(0.34),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cobroRapido) ...[
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    medioSeleccionado == null ? Icons.payments_outlined : _iconoMedioPago(medioSeleccionado),
                    color: palette.secondary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Cómo pagó el cliente?',
                        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        medioSeleccionado?.nombre ?? 'Selecciona un medio de pago',
                        style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (listo ? AppColors.success : palette.secondary).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    listo ? Icons.check_circle_rounded : (medioSeleccionado == null ? Icons.payments_outlined : _iconoMedioPago(medioSeleccionado)),
                    color: listo ? AppColors.success : palette.secondary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pagos.length > 1 ? 'PAGO ${index + 1} DE ${_pagos.length}' : 'PAGO',
                        style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        listo ? 'Pago listo' : (medioSeleccionado?.nombre ?? 'Selecciona cómo pagará'),
                        style: TextStyle(color: listo ? AppColors.success : palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                if (_pagos.length > 1) ...[
                  IconButton(
                    tooltip: 'Eliminar este pago',
                    onPressed: () => _eliminarPagoEnPreparacion(index),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 2),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (listo ? AppColors.success : palette.secondary).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    listo ? 'LISTO ✓' : 'EN CURSO',
                    style: TextStyle(color: listo ? AppColors.success : palette.secondary, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            valueField,
            const SizedBox(height: 16),
            Text('Medio de pago', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(height: 8),
          ],
          if (cobroRapido) const SizedBox(height: 8),
          _buildSelectorVisualMedioPago(pago),
          if (medioSeleccionado != null && _qrMedioPago(medioSeleccionado) != null) ...[
            const SizedBox(height: 12),
            _buildQrMedioPago(medioSeleccionado),
          ],
          if (pago.esEfectivo) ...[
            const SizedBox(height: 14),
            _buildRegistroEfectivo(pago),
          ],
        ],
      ),
    );
  }

  Widget _buildRegistroEfectivo(_PagoFormRowData pago) {
    final palette = _palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_modoRapidoVentaDirecta) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _marcarPagoExacto(pago),
              icon: const Icon(Icons.price_check_rounded),
              label: Text('Pago exacto ${CurrencyUtils.format(_parse(pago.valorController.text))}'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.72 : 0.90),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.secondary.withOpacity(0.16)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _EfectivoModoButton(
                  label: 'Ingresar total',
                  icon: Icons.edit_rounded,
                  selected: pago.efectivoManual,
                  onTap: () => _cambiarModoEfectivo(pago, true),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _EfectivoModoButton(
                  label: 'Billetes y monedas',
                  icon: Icons.payments_rounded,
                  selected: !pago.efectivoManual,
                  onTap: () => _cambiarModoEfectivo(pago, false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (pago.efectivoManual) _buildEfectivoManual(pago) else _buildSelectorEfectivoVisual(pago),
      ],
    );
  }

  Widget _buildResumenEfectivoPos({
    required double aplicado,
    required double recibido,
    required double faltante,
    required double cambio,
  }) {
    final palette = _palette;
    final tieneVuelta = cambio > 0.009;
    final faltaDinero = faltante > 0.009;
    final accent = tieneVuelta ? AppColors.success : (faltaDinero ? palette.primary : AppColors.success);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.54 : 0.76),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: accent.withOpacity(tieneVuelta ? 0.30 : 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 470;
          final datos = Row(
            children: [
              Expanded(child: _CobroResumenDato(label: 'Debe recibir', value: CurrencyUtils.format(aplicado), color: palette.textPrimary)),
              Container(width: 1, height: 34, color: palette.cardBorder),
              Expanded(child: _CobroResumenDato(label: 'Recibido', value: CurrencyUtils.format(recibido), color: palette.textPrimary)),
            ],
          );
          final resultado = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.24)),
            ),
            child: Column(
              crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.end,
              children: [
                Text(
                  tieneVuelta
                      ? 'VUELTA'
                      : (faltaDinero ? 'FALTANTE' : (_modoRapidoVentaDirecta ? 'LISTO PARA COBRAR' : 'PAGO CUBIERTO')),
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.4),
                ),
                const SizedBox(height: 1),
                Text(
                  !tieneVuelta && !faltaDinero && _modoRapidoVentaDirecta
                      ? '✓'
                      : CurrencyUtils.format(tieneVuelta ? cambio : (faltaDinero ? faltante : 0)),
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: tieneVuelta ? 22 : 18),
                ),
              ],
            ),
          );
          if (compact) {
            return Column(children: [datos, const SizedBox(height: 10), SizedBox(width: double.infinity, child: resultado)]);
          }
          return Row(children: [Expanded(child: datos), const SizedBox(width: 12), resultado]);
        },
      ),
    );
  }

  Widget _buildEfectivoManual(_PagoFormRowData pago) {
    final palette = _palette;
    final aplicado = _parse(pago.valorController.text);
    final recibido = _parse(pago.valorRecibidoController.text);
    final faltante = (aplicado - recibido).clamp(0, double.infinity).toDouble();
    final cambio = (recibido - aplicado).clamp(0, double.infinity).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.72 : 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Cuánto entregó el cliente?', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            'Escribe únicamente el total recibido. No necesitas seleccionar billetes ni monedas.',
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: pago.valorRecibidoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _wholeCurrencyInputFormatters,
            decoration: const InputDecoration(
              labelText: 'Total recibido',
              hintText: '50.000',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            onChanged: (_) => setState(() {
              _invalidarPago(pago);
            }),
            validator: (value) {
              if (!pago.esEfectivo || !pago.efectivoManual) return null;
              final total = _parse(value ?? '');
              if (total <= 0) return 'Ingresa cuánto efectivo entregó el cliente.';
              if (total + 0.009 < _parse(pago.valorController.text)) {
                return 'El efectivo recibido no alcanza para cubrir este pago.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildResumenEfectivoPos(
            aplicado: aplicado,
            recibido: recibido,
            faltante: faltante,
            cambio: cambio,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorEfectivoVisual(_PagoFormRowData pago) {
    final palette = _palette;
    return FormField<double>(
      initialValue: pago.efectivoSeleccionado,
      validator: (_) {
        if (!pago.esEfectivo || pago.efectivoManual) return null;
        final recibido = pago.efectivoSeleccionado;
        final aplicado = _parse(pago.valorController.text);
        if (recibido <= 0) return 'Selecciona los billetes o monedas recibidos.';
        if (recibido + 0.009 < aplicado) return 'El efectivo seleccionado no alcanza para cubrir este pago.';
        return null;
      },
      builder: (field) {
        final recibido = pago.efectivoSeleccionado;
        final aplicado = _parse(pago.valorController.text);
        final faltante = (aplicado - recibido).clamp(0, double.infinity).toDouble();
        final cambio = (recibido - aplicado).clamp(0, double.infinity).toDouble();
        final tieneSeleccion = pago.denominaciones.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.72 : 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: field.hasError ? AppColors.danger.withOpacity(0.55) : palette.secondary.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
                    child: Icon(Icons.payments_rounded, color: palette.secondary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¿Con qué efectivo pagaron?', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('Toca cada billete o moneda recibido. No necesitas escribir el valor.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: tieneSeleccion ? () => _limpiarDenominaciones(pago, field: field) : null,
                    icon: const Icon(Icons.restart_alt_rounded, size: 17),
                    label: const Text('Limpiar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildResumenEfectivoPos(
                aplicado: aplicado,
                recibido: recibido,
                faltante: faltante,
                cambio: cambio,
              ),
              const SizedBox(height: 14),
              Text('Billetes', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 8),
              _buildGrupoDenominaciones(pago, _billetesColombia, field: field, monedas: false),
              const SizedBox(height: 14),
              Text('Monedas', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 8),
              _buildGrupoDenominaciones(pago, _monedasColombia, field: field, monedas: true),
              if (field.hasError) ...[
                const SizedBox(height: 9),
                Text(field.errorText!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrupoDenominaciones(
    _PagoFormRowData pago,
    List<int> valores, {
    required FormFieldState<double> field,
    required bool monedas,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 430 ? 2 : (constraints.maxWidth < 650 ? 3 : 4);
        const spacing = 8.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final valor in valores)
              _buildDenominacionEfectivo(
                pago,
                valor,
                width: width,
                monedas: monedas,
                field: field,
              ),
          ],
        );
      },
    );
  }

  Widget _buildDenominacionEfectivo(
    _PagoFormRowData pago,
    int valor, {
    required double width,
    required bool monedas,
    required FormFieldState<double> field,
  }) {
    final palette = _palette;
    final cantidad = pago.denominaciones[valor] ?? 0;
    final selected = cantidad > 0;
    final puedeDesagregar = selected && _descomposicionDenominacion(valor) != null;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _sumarDenominacion(pago, valor, field: field),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? palette.secondary.withOpacity(palette.darkBackground ? 0.18 : 0.12)
                  : palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.70),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? palette.secondary.withOpacity(0.70) : palette.cardBorder, width: selected ? 1.4 : 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: monedas ? 58 : 62,
                      width: monedas ? 58 : double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.secondary.withOpacity(selected ? 0.16 : 0.08),
                        shape: monedas ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: monedas ? null : BorderRadius.circular(10),
                        border: Border.all(color: palette.secondary.withOpacity(0.24)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            monedas ? Icons.monetization_on_rounded : Icons.local_atm_rounded,
                            size: monedas ? 18 : 20,
                            color: palette.secondary.withOpacity(selected ? 0.95 : 0.85),
                          ),
                          const SizedBox(height: 3),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              CurrencyUtils.format(valor.toDouble()),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: monedas ? 10 : 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(color: palette.secondary, borderRadius: BorderRadius.circular(999)),
                          child: Text('$cantidad', style: TextStyle(color: Theme.of(context).colorScheme.onSecondary, fontWeight: FontWeight.w900, fontSize: 10)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Quitar una',
                        onPressed: selected ? () => _restarDenominacion(pago, valor, field: field) : null,
                        icon: const Icon(Icons.remove_rounded, size: 17),
                      ),
                    ),
                    const SizedBox(width: 2),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Agregar una',
                        onPressed: () => _sumarDenominacion(pago, valor, field: field),
                        icon: const Icon(Icons.add_rounded, size: 17),
                      ),
                    ),
                    if (puedeDesagregar) ...[
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: 'Desagregar una denominación',
                          onPressed: () => _desagregarDenominacion(pago, valor, field: field),
                          icon: const Icon(Icons.call_split_rounded, size: 16),
                        ),
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

class _EfectivoModoButton extends StatelessWidget {
  const _EfectivoModoButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected ? colorScheme.secondary.withOpacity(0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? colorScheme.secondary : colorScheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? colorScheme.secondary : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
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

class _MedioPagoVisualButton extends ConsumerWidget {
  const _MedioPagoVisualButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 74),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? palette.secondary.withOpacity(palette.darkBackground ? 0.20 : 0.13)
                  : palette.surface.withOpacity(palette.darkBackground ? 0.46 : 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? palette.secondary : palette.cardBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: selected ? palette.secondary : palette.textSecondary, size: 25),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? palette.secondary : palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.check_circle_rounded, color: palette.secondary, size: 17),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MensajeCobroError extends StatelessWidget {
  const _MensajeCobroError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _CobroResumenDato extends StatelessWidget {
  const _CobroResumenDato({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.70), fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
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

class _SumarCantidadProductoDialog extends ConsumerStatefulWidget {
  const _SumarCantidadProductoDialog({required this.producto});

  final MeseroDetalleProductoModel producto;

  @override
  ConsumerState<_SumarCantidadProductoDialog> createState() => _SumarCantidadProductoDialogState();
}

class _SumarCantidadProductoDialogState extends ConsumerState<_SumarCantidadProductoDialog> {
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

  void _establecerCantidad(double value) {
    _cantidadController.text = _formatCantidadGeneral(value);
    _cantidadController.selection = TextSelection.collapsed(offset: _cantidadController.text.length);
    setState(() {});
  }

  void _sumarUno(double diferencia) {
    final actual = _parseCantidad(_cantidadController.text);
    final nuevoValor = (actual + diferencia).clamp(1.0, 999999.0).toDouble();
    _establecerCantidad(nuevoValor);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final producto = widget.producto;
    final cantidadActual = (producto.cantidad ?? 0).toDouble();
    final cantidadASumar = _parseCantidad(_cantidadController.text);
    final cantidadFinal = cantidadActual + cantidadASumar;
    final valorUnitario = producto.valorUnitario ?? 0;

    return AlertDialog(
      backgroundColor: palette.surface.withOpacity(palette.darkBackground ? 0.97 : 0.995),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.secondary.withOpacity(0.20)),
      ),
      title: Text('Sumar cantidad', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductImageThumb(value: producto.productoFoto, size: 68),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}',
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Cantidad actual: ${_formatCantidadGeneral(cantidadActual)}',
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in const <double>[1, 2, 5, 10])
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text(_formatCantidadGeneral(value)),
                      onPressed: () => _establecerCantidad(value),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    onPressed: cantidadASumar <= 1 ? null : () => _sumarUno(-1),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _cantidadController,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 10, fractionDigits: 0),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad a sumar',
                        hintText: 'Ejemplo: 5',
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
                    onPressed: () => _sumarUno(1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.background.withOpacity(palette.darkBackground ? 0.48 : 0.70),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(child: _dato('Quedará en', _formatCantidadGeneral(cantidadFinal))),
                    Expanded(
                      child: _dato(
                        'Valor agregado',
                        CurrencyUtils.format(cantidadASumar * valorUnitario),
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'La cantidad se registra en una sola operación; no es necesario pulsar + varias veces.',
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
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
          icon: const Icon(Icons.add_rounded),
          label: const Text('Sumar'),
        ),
      ],
    );
  }

  Widget _dato(String label, String value, {bool alignEnd = false}) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
      ],
    );
  }
}

class _AgregarProductosOverlayPanel extends ConsumerStatefulWidget {
  const _AgregarProductosOverlayPanel({
    required this.cuenta,
    required this.productos,
    required this.cantidadesPedidasHoy,
    required this.onConfirmar,
    this.ventaDirectaRapida = false,
    this.ventaId,
    this.onConfirmarRapido,
    this.onActualizarProductoExistente,
    this.onEliminarProductoExistente,
  });

  final MeseroCuentaModel cuenta;
  final List<MeseroProductoModel> productos;
  final Map<int, double> cantidadesPedidasHoy;
  final Future<bool> Function(Map<int, double> cantidades) onConfirmar;
  final bool ventaDirectaRapida;
  final int? ventaId;
  final Future<bool> Function(Map<int, double> cantidades, bool cobrar)? onConfirmarRapido;
  final Future<MeseroVentaModel?> Function(MeseroDetalleProductoModel producto, double cantidad)? onActualizarProductoExistente;
  final Future<MeseroVentaModel?> Function(MeseroDetalleProductoModel producto)? onEliminarProductoExistente;

  @override
  ConsumerState<_AgregarProductosOverlayPanel> createState() => _AgregarProductosOverlayPanelState();
}

class _AgregarProductosOverlayPanelState extends ConsumerState<_AgregarProductosOverlayPanel> {
  final TextEditingController _busquedaController = TextEditingController();
  final Map<int, double> _cantidades = <int, double>{};
  String? _tipoSeleccionado;
  bool _guardando = false;
  late MeseroCuentaModel _cuentaActual;

  @override
  void initState() {
    super.initState();
    _cuentaActual = widget.cuenta;
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  List<String> get _tipos {
    final idsAdiciones = _idsAdiciones(widget.productos);
    final values = widget.productos
        .where((producto) => _visibleEnCatalogoMesa(producto, idsAdiciones))
        .map((producto) => (producto.tipoProductoNombre ?? '').trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<MeseroProductoModel> get _productosFiltrados {
    final query = _busquedaController.text.trim().toLowerCase();
    final idsAdiciones = _idsAdiciones(widget.productos);
    final productos = widget.productos.where((producto) {
      if (!_visibleEnCatalogoMesa(producto, idsAdiciones)) return false;
      final tipo = (producto.tipoProductoNombre ?? '').trim();
      if (_tipoSeleccionado != null && tipo != _tipoSeleccionado) return false;
      if (query.isEmpty) return true;
      final nombre = (producto.nombre ?? '').toLowerCase();
      final descripcion = (producto.descripcion ?? '').toLowerCase();
      final marca = (producto.marcaNombre ?? '').toLowerCase();
      final categoria = tipo.toLowerCase();
      final codigo = producto.prodId?.toString() ?? '';
      return nombre.contains(query) ||
          descripcion.contains(query) ||
          marca.contains(query) ||
          categoria.contains(query) ||
          codigo.contains(query);
    }).toList(growable: false);

    // El catálogo ya llega ordenado por la cantidad pedida hoy. Los controles
    // + y - no cambian ese orden mientras el usuario arma el pedido.
    return productos;
  }

  double _cantidadActualEnCuenta(MeseroProductoModel producto) {
    final productoId = producto.prodId;
    if (productoId == null) return 0;
    return _cuentaActual.productos.fold<double>(0, (total, detalle) {
      return detalle.productoId == productoId ? total + (detalle.cantidad ?? 0) : total;
    });
  }

  double get _totalUnidades => _cantidades.values.fold<double>(0, (sum, value) => sum + value);

  int get _totalProductos => _cantidades.values.where((value) => value > 0).length;

  double get _totalValor {
    var total = 0.0;
    for (final producto in widget.productos) {
      final productoId = producto.prodId;
      if (productoId == null) continue;
      total += (_cantidades[productoId] ?? 0) * (producto.precioVenta ?? 0);
    }
    return total;
  }

  void _cambiarCantidad(MeseroProductoModel producto, double diferencia) {
    final productoId = producto.prodId;
    if (productoId == null || _guardando) return;
    final actual = _cantidades[productoId] ?? 0;
    final nueva = (actual + diferencia).clamp(0, 9999).toDouble();
    setState(() {
      if (nueva <= 0) {
        _cantidades.remove(productoId);
      } else {
        _cantidades[productoId] = nueva;
      }
    });
  }

  Future<void> _editarCantidad(MeseroProductoModel producto) async {
    final productoId = producto.prodId;
    if (productoId == null || _guardando) return;
    final actual = _cantidades[productoId] ?? 0;
    final cantidad = await showDialog<double>(
      context: context,
      builder: (dialogContext) => _CantidadAgregarDesdePanelDialog(
        producto: producto,
        cantidadInicial: actual,
      ),
    );
    if (cantidad == null || !mounted) return;
    setState(() {
      if (cantidad <= 0) {
        _cantidades.remove(productoId);
      } else {
        _cantidades[productoId] = cantidad;
      }
    });
  }

  MeseroCuentaModel? _cuentaDesdeVenta(MeseroVentaModel venta) {
    final cuentaId = _cuentaActual.cuentaId;
    for (final cuenta in venta.cuentas) {
      if (cuenta.cuentaId == cuentaId) return cuenta;
    }
    return venta.cuentas.isNotEmpty ? venta.cuentas.first : null;
  }

  Future<void> _actualizarProductoExistente(MeseroDetalleProductoModel producto, double cantidad) async {
    if (_guardando || producto.pagado == true || widget.onActualizarProductoExistente == null) return;
    setState(() => _guardando = true);
    final venta = await widget.onActualizarProductoExistente!(producto, cantidad.clamp(0, 9999).toDouble());
    if (!mounted) return;
    setState(() {
      final cuenta = venta == null ? null : _cuentaDesdeVenta(venta);
      if (cuenta != null) _cuentaActual = cuenta;
      _guardando = false;
    });
  }

  Future<void> _editarProductoExistente(MeseroDetalleProductoModel producto) async {
    if (_guardando || producto.pagado == true) return;
    final cantidad = await showDialog<double>(
      context: context,
      builder: (dialogContext) => _CantidadProductoExistenteDialog(producto: producto),
    );
    if (cantidad == null || !mounted) return;
    if (cantidad <= 0) {
      await _eliminarProductoExistente(producto);
      return;
    }
    await _actualizarProductoExistente(producto, cantidad);
  }

  Future<void> _eliminarProductoExistente(MeseroDetalleProductoModel producto) async {
    if (_guardando || producto.pagado == true || widget.onEliminarProductoExistente == null) return;
    final nombre = producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar producto de la venta'),
        content: Text('¿Quieres eliminar $nombre de esta venta directa?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _guardando = true);
    final venta = await widget.onEliminarProductoExistente!(producto);
    if (!mounted) return;
    setState(() {
      final cuenta = venta == null ? null : _cuentaDesdeVenta(venta);
      if (cuenta != null) _cuentaActual = cuenta;
      _guardando = false;
    });
  }

  Future<void> _confirmar({bool cobrar = false}) async {
    final tieneProductosActuales = _cuentaActual.productos.isNotEmpty;
    if (_guardando || (!cobrar && _cantidades.isEmpty) || (cobrar && _cantidades.isEmpty && !tieneProductosActuales)) return;
    setState(() => _guardando = true);
    final cantidades = Map<int, double>.from(_cantidades);
    final success = widget.ventaDirectaRapida && widget.onConfirmarRapido != null
        ? await widget.onConfirmarRapido!(cantidades, cobrar)
        : await widget.onConfirmar(cantidades);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final productos = _productosFiltrados;
    final nombreCuenta = _cuentaNombreVisible(_cuentaActual);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface.withOpacity(0.985),
          borderRadius: mobile
              ? const BorderRadius.vertical(top: Radius.circular(30))
              : const BorderRadius.horizontal(left: Radius.circular(30)),
          border: mobile ? null : Border.all(color: palette.secondary.withOpacity(0.18)),
          boxShadow: mobile
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.24),
                    blurRadius: 28,
                    offset: const Offset(0, -8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 36,
                    offset: const Offset(-12, 0),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mobile)
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: palette.textSecondary.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            _buildHeader(context, palette, nombreCuenta),
            if (widget.ventaDirectaRapida) _buildVentaDirectaSelectionTray(palette),
            _buildSearchAndFilters(palette),
            Divider(height: 1, color: palette.cardBorder),
            Expanded(child: _buildContenidoProductos(palette, productos)),
            _buildFooter(palette, nombreCuenta),
          ],
        ),
      ),
    );
  }

  Widget _buildVentaDirectaSelectionTray(AppPalette palette) {
    final seleccionados = widget.productos.where((producto) {
      final productoId = producto.prodId;
      return productoId != null && (_cantidades[productoId] ?? 0) > 0;
    }).toList(growable: false);
    final existentes = _cuentaActual.productos;
    final totalActual = _cuentaActual.total ?? _cuentaActual.subtotalProductos ?? 0;
    final totalProyectado = totalActual + _totalValor;
    final tieneItems = seleccionados.isNotEmpty || existentes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: palette.primary.withOpacity(palette.darkBackground ? 0.10 : 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.primary.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(palette.darkBackground ? 0.10 : 0.045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.primary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.shopping_bag_rounded, color: palette.primary, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu venta',
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      tieneItems
                          ? '${existentes.length + seleccionados.length} productos visibles en la selección'
                          : 'Toca + en un producto y aparecerá aquí inmediatamente.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.secondary.withOpacity(0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('A cobrar', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 9)),
                    const SizedBox(height: 1),
                    Text(
                      CurrencyUtils.format(totalProyectado),
                      style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tieneItems) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...existentes.map((producto) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildVentaDirectaExistingSelectionCard(palette, producto),
                      )),
                  ...seleccionados.map((producto) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildVentaDirectaPendingSelectionCard(palette, producto),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVentaDirectaExistingSelectionCard(
    AppPalette palette,
    MeseroDetalleProductoModel producto,
  ) {
    final cantidad = (producto.cantidad ?? 0).toDouble();
    final pagado = producto.pagado == true;
    final subtotal = producto.subtotal ?? cantidad * (producto.valorUnitario ?? 0);
    final nombre = producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}';

    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: pagado ? palette.cardBorder : palette.primary.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          _ProductImageThumb(value: producto.productoFoto, size: 42),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 11.5)),
                const SizedBox(height: 3),
                Text(
                  '${_formatCantidadGeneral(cantidad)} × ${CurrencyUtils.format(producto.valorUnitario)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 9.5),
                ),
                const SizedBox(height: 2),
                Text(CurrencyUtils.format(subtotal), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 10.5)),
              ],
            ),
          ),
          if (!pagado) ...[
            const SizedBox(width: 5),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 27,
                  height: 27,
                  child: IconButton.filledTonal(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: _guardando || cantidad <= 1 ? null : () => _actualizarProductoExistente(producto, cantidad - 1),
                    icon: const Icon(Icons.remove_rounded, size: 15),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 27,
                  height: 27,
                  child: IconButton.filledTonal(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: _guardando ? null : () => _actualizarProductoExistente(producto, cantidad + 1),
                    icon: const Icon(Icons.add_rounded, size: 15),
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 19),
            ),
        ],
      ),
    );
  }

  Widget _buildVentaDirectaPendingSelectionCard(
    AppPalette palette,
    MeseroProductoModel producto,
  ) {
    final productoId = producto.prodId;
    final cantidad = productoId == null ? 0.0 : (_cantidades[productoId] ?? 0);
    final subtotal = cantidad * (producto.precioVenta ?? 0);
    final nombre = producto.nombre ?? 'Producto ${productoId ?? '-'}';

    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(palette.darkBackground ? 0.10 : 0.065),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.secondary.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          _ProductImageThumb(value: producto.foto, size: 42),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 11.5))),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatCantidadGeneral(cantidad)} × ${CurrencyUtils.format(producto.precioVenta)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 9.5),
                ),
                const SizedBox(height: 2),
                Text(CurrencyUtils.format(subtotal), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 27,
                height: 27,
                child: IconButton.filledTonal(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: _guardando ? null : () => _cambiarCantidad(producto, -1),
                  icon: Icon(cantidad <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, size: 15),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 27,
                height: 27,
                child: IconButton.filledTonal(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: _guardando ? null : () => _cambiarCantidad(producto, 1),
                  icon: const Icon(Icons.add_rounded, size: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContenidoProductos(AppPalette palette, List<MeseroProductoModel> productos) {
    final existentes = _cuentaActual.productos;
    if (!widget.ventaDirectaRapida && productos.isEmpty) return _buildEmpty(palette);
    if (widget.ventaDirectaRapida && productos.isEmpty && existentes.isEmpty) return _buildEmpty(palette);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
      children: [
        if (widget.ventaDirectaRapida && existentes.isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: palette.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.shopping_cart_checkout_rounded, color: palette.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Productos en la venta', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Puedes cambiar cantidades o quitar productos antes de cobrar.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: palette.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
                child: Text('${existentes.length}', style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...existentes.map((producto) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _buildProductoExistenteRow(palette, producto),
              )),
          const SizedBox(height: 4),
          Divider(height: 24, color: palette.cardBorder),
        ],
        if (productos.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: palette.secondary, size: 19),
              const SizedBox(width: 7),
              Text('Agregar productos', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(productos.length, (index) => Padding(
                padding: EdgeInsets.only(bottom: index == productos.length - 1 ? 0 : 10),
                child: _buildProductRow(context, palette, productos[index]),
              )),
        ] else if (widget.ventaDirectaRapida && existentes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text('No hay más productos disponibles con este filtro.', textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _buildProductoExistenteRow(AppPalette palette, MeseroDetalleProductoModel producto) {
    final cantidad = (producto.cantidad ?? 0).toDouble();
    final pagado = producto.pagado == true;
    final nombre = producto.productoNombre ?? 'Producto ${producto.productoId ?? '-'}';
    final unitario = (producto.valorUnitario ?? 0) + (producto.precioAdicionalUnitario ?? 0);
    final total = producto.subtotal ?? cantidad * unitario;
    final personalizacion = _personalizacionPedidoResumen(producto);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: pagado
            ? palette.background.withOpacity(palette.darkBackground ? 0.30 : 0.48)
            : palette.primary.withOpacity(palette.darkBackground ? 0.09 : 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pagado ? palette.cardBorder : palette.primary.withOpacity(0.20)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 460;
          final info = Row(
            children: [
              _ProductImageThumb(value: producto.productoFoto, size: 48),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900))),
                        if (pagado)
                          Container(
                            margin: const EdgeInsets.only(left: 7),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
                            child: const Text('Pagado', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 9.5)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text('Unidad ${CurrencyUtils.format(unitario)}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
                        Text('Subtotal ${CurrencyUtils.format(total)}', style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 11)),
                      ],
                    ),
                    if (personalizacion.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: personalizacion
                            .map((text) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: palette.secondary.withOpacity(.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: palette.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final controls = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: palette.surface.withOpacity(0.88), borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.cardBorder)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PanelQuantityButton(
                  icon: Icons.remove_rounded,
                  enabled: !pagado && !_guardando && cantidad > 1,
                  onTap: () => _actualizarProductoExistente(producto, cantidad - 1),
                ),
                const SizedBox(width: 3),
                Material(
                  color: palette.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: !pagado && !_guardando ? () => _editarProductoExistente(producto) : null,
                    borderRadius: BorderRadius.circular(11),
                    child: SizedBox(
                      width: 62,
                      height: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_formatCantidadGeneral(cantidad), style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900, fontSize: 14)),
                          Text('cantidad', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 8.5)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                _PanelQuantityButton(
                  icon: Icons.add_rounded,
                  enabled: !pagado && !_guardando,
                  primary: true,
                  onTap: () => _actualizarProductoExistente(producto, cantidad + 1),
                ),
                const SizedBox(width: 3),
                _PanelQuantityButton(
                  icon: Icons.delete_outline_rounded,
                  enabled: !pagado && !_guardando,
                  onTap: () => _eliminarProductoExistente(producto),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }
          return Row(children: [Expanded(child: info), const SizedBox(width: 10), controls]);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppPalette palette, String nombreCuenta) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.primary, palette.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add_shopping_cart_rounded, color: palette.onPrimary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ventaDirectaRapida
                      ? 'Venta directa #${widget.ventaId ?? '-'}'
                      : 'Agregar productos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.ventaDirectaRapida
                      ? 'Selecciona los productos y cobra desde este mismo panel, sin salir de la vista de mesas.'
                      : 'Primero aparecen los productos más pedidos de hoy. Selecciona cantidades para $nombreCuenta.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Cerrar productos',
            child: IconButton.filledTonal(
              onPressed: _guardando ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: _busquedaController,
            enabled: !_guardando,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Buscar productos',
              hintText: 'Nombre, marca, categoría o código',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _busquedaController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _busquedaController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ).compactFilter(),
          ),
          if (_tipos.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _PanelFilterChip(
                    label: 'Todos',
                    selected: _tipoSeleccionado == null,
                    onTap: _guardando ? null : () => setState(() => _tipoSeleccionado = null),
                  ),
                  const SizedBox(width: 8),
                  for (final tipo in _tipos) ...[
                    _PanelFilterChip(
                      label: tipo,
                      selected: _tipoSeleccionado == tipo,
                      onTap: _guardando ? null : () => setState(() => _tipoSeleccionado = tipo),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(AppPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: palette.textSecondary, size: 44),
            const SizedBox(height: 12),
            Text(
              'No encontramos productos',
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              'Cambia la búsqueda o selecciona otra categoría.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRow(
    BuildContext context,
    AppPalette palette,
    MeseroProductoModel producto,
  ) {
    final productoId = producto.prodId;
    final cantidad = productoId == null ? 0.0 : (_cantidades[productoId] ?? 0);
    final cantidadActual = _cantidadActualEnCuenta(producto);
    final cantidadPedidaHoy = productoId == null ? 0.0 : (widget.cantidadesPedidasHoy[productoId] ?? 0);
    final selected = cantidad > 0;
    final marca = (producto.marcaNombre ?? '').trim();
    final tipo = (producto.tipoProductoNombre ?? '').trim();
    final meta = [marca, tipo].where((value) => value.isNotEmpty).join(' · ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? palette.secondary.withOpacity(0.10)
            : palette.background.withOpacity(palette.darkBackground ? 0.42 : 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? palette.secondary.withOpacity(0.34) : palette.cardBorder,
          width: selected ? 1.3 : 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductImageThumb(value: producto.foto, size: compact ? 52 : 58),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre ?? 'Producto ${producto.prodId ?? '-'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        height: 1.15,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          CurrencyUtils.format(producto.precioVenta),
                          style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        if (cantidadPedidaHoy > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.secondary.withOpacity(0.11),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: palette.secondary.withOpacity(0.18)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.trending_up_rounded, size: 12, color: palette.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Hoy: ${_formatCantidadGeneral(cantidadPedidaHoy)}',
                                  style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        if (cantidadActual > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'En cuenta: ${_formatCantidadGeneral(cantidadActual)}',
                              style: TextStyle(color: palette.primary, fontWeight: FontWeight.w800, fontSize: 10.5),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
          final controls = _buildQuantityControl(palette, producto, cantidad);

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: controls),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              controls,
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuantityControl(
    AppPalette palette,
    MeseroProductoModel producto,
    double cantidad,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.secondary.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelQuantityButton(
            icon: cantidad <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            enabled: cantidad > 0 && !_guardando,
            onTap: () => _cambiarCantidad(producto, -1),
          ),
          const SizedBox(width: 4),
          Material(
            color: cantidad > 0 ? palette.secondary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _guardando ? null : () => _editarCantidad(producto),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 42,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formatCantidadGeneral(cantidad),
                      style: TextStyle(
                        color: cantidad > 0 ? palette.secondary : palette.textSecondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'agregar',
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 8.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _PanelQuantityButton(
            icon: Icons.add_rounded,
            enabled: !_guardando,
            primary: true,
            onTap: () => _cambiarCantidad(producto, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppPalette palette, String nombreCuenta) {
    final hasSelection = _cantidades.isNotEmpty;
    final tieneProductosActuales = _cuentaActual.productos.isNotEmpty;
    final totalActual = _cuentaActual.total ?? _cuentaActual.subtotalProductos ?? 0;
    final totalProyectado = totalActual + _totalValor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(0.99),
        border: Border(top: BorderSide(color: palette.cardBorder)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, -8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ventaDirectaRapida
                          ? (hasSelection
                              ? '$_totalProductos productos seleccionados · Total ${CurrencyUtils.format(totalProyectado)}'
                              : '${_cuentaActual.productos.length} productos en la venta')
                          : (hasSelection
                              ? '$_totalProductos ${_totalProductos == 1 ? 'producto' : 'productos'} · ${_formatCantidadGeneral(_totalUnidades)} unidades'
                              : 'Selecciona los productos del pedido'),
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.ventaDirectaRapida
                          ? 'Total de la venta: ${CurrencyUtils.format(totalProyectado)}'
                          : 'Valor a agregar: ${CurrencyUtils.format(_totalValor)}',
                      style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (hasSelection)
                TextButton(
                  onPressed: _guardando ? null : () => setState(_cantidades.clear),
                  child: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: 11),
          if (widget.ventaDirectaRapida)
            LayoutBuilder(
              builder: (context, constraints) {
                final compacto = constraints.maxWidth < 520;
                final cerrar = OutlinedButton(
                  onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                );
                final guardar = FilledButton.tonalIcon(
                  onPressed: !hasSelection || _guardando ? null : () => _confirmar(),
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  label: const Text('Guardar abierta'),
                );
                final cobrar = FilledButton.icon(
                  onPressed: (!hasSelection && !tieneProductosActuales) || _guardando
                      ? null
                      : () => _confirmar(cobrar: true),
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.payments_rounded),
                  label: Text(_guardando ? 'Procesando...' : (hasSelection ? 'Agregar y cobrar' : 'Cobrar ahora')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                );

                if (compacto) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cobrar,
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(child: cerrar),
                          const SizedBox(width: 9),
                          Expanded(child: guardar),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cerrar),
                    const SizedBox(width: 9),
                    Expanded(child: guardar),
                    const SizedBox(width: 9),
                    Expanded(flex: 2, child: cobrar),
                  ],
                );
              },
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: !hasSelection || _guardando ? null : () => _confirmar(),
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Icon(Icons.add_shopping_cart_rounded),
                    label: Text(_guardando ? 'Agregando...' : 'Agregar a $nombreCuenta'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

}

class _CantidadProductoExistenteDialog extends ConsumerStatefulWidget {
  const _CantidadProductoExistenteDialog({required this.producto});

  final MeseroDetalleProductoModel producto;

  @override
  ConsumerState<_CantidadProductoExistenteDialog> createState() => _CantidadProductoExistenteDialogState();
}

class _CantidadProductoExistenteDialogState extends ConsumerState<_CantidadProductoExistenteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatCantidadGeneral(widget.producto.cantidad));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _cantidad() => double.tryParse(_controller.text.trim().replaceAll(',', '.')) ?? 0;

  void _ajustar(double diferencia) {
    final nueva = (_cantidad() + diferencia).clamp(0, 9999).toDouble();
    _controller.text = _formatCantidadGeneral(nueva);
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final cantidad = _cantidad();
    final total = cantidad *
        ((widget.producto.valorUnitario ?? 0) +
            (widget.producto.precioAdicionalUnitario ?? 0));
    return AlertDialog(
      backgroundColor: palette.surface.withOpacity(0.99),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: palette.secondary.withOpacity(0.18))),
      title: Text('Modificar cantidad', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.producto.productoNombre ?? 'Producto', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Row(
              children: [
                IconButton.filledTonal(onPressed: cantidad > 0 ? () => _ajustar(-1) : null, icon: const Icon(Icons.remove_rounded)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: InputConstraints.decimalFormatters(integerDigits: 10, fractionDigits: 0),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(onPressed: () => _ajustar(1), icon: const Icon(Icons.add_rounded)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: palette.secondary.withOpacity(0.09), borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  Expanded(child: Text('Nuevo subtotal', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700))),
                  Text(CurrencyUtils.format(total), style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            if (cantidad <= 0) ...[
              const SizedBox(height: 8),
              const Text('Cantidad 0 eliminará el producto de la venta.', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: cantidad < 0 ? null : () => Navigator.of(context).pop(cantidad), child: const Text('Guardar cantidad')),
      ],
    );
  }
}

class _PanelFilterChip extends ConsumerWidget {
  const _PanelFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Material(
      color: selected ? palette.secondary.withOpacity(0.14) : palette.background.withOpacity(0.55),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? palette.secondary.withOpacity(0.34) : palette.cardBorder,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? palette.secondary : palette.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelQuantityButton extends ConsumerWidget {
  const _PanelQuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Material(
      color: primary && enabled
          ? palette.primary
          : palette.background.withOpacity(enabled ? 0.72 : 0.34),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: enabled
                ? (primary ? palette.onPrimary : palette.textPrimary)
                : palette.textSecondary.withOpacity(0.42),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _CantidadAgregarDesdePanelDialog extends ConsumerStatefulWidget {
  const _CantidadAgregarDesdePanelDialog({
    required this.producto,
    required this.cantidadInicial,
  });

  final MeseroProductoModel producto;
  final double cantidadInicial;

  @override
  ConsumerState<_CantidadAgregarDesdePanelDialog> createState() => _CantidadAgregarDesdePanelDialogState();
}

class _CantidadAgregarDesdePanelDialogState extends ConsumerState<_CantidadAgregarDesdePanelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.cantidadInicial > 0 ? _formatCantidadGeneral(widget.cantidadInicial) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parse() {
    final raw = _controller.text.trim().replaceAll(',', '.');
    return double.tryParse(raw);
  }

  void _setQuick(double value) {
    _controller.text = _formatCantidadGeneral(value);
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final cantidad = _parse() ?? 0;
    return AlertDialog(
      backgroundColor: palette.surface.withOpacity(0.99),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: palette.secondary.withOpacity(0.18)),
      ),
      title: Text(
        'Cantidad a agregar',
        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.producto.nombre ?? 'Producto ${widget.producto.prodId ?? '-'}',
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: InputConstraints.decimalFormatters(integerDigits: 10, fractionDigits: 0),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                hintText: 'Ejemplo: 5',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in const [1.0, 2.0, 5.0, 10.0])
                  ActionChip(
                    label: Text('+${_formatCantidadGeneral(value)}'),
                    onPressed: () => _setQuick(value),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Valor aproximado',
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    CurrencyUtils.format(cantidad * (widget.producto.precioVenta ?? 0)),
                    style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: cantidad < 0 ? null : () => Navigator.of(context).pop(cantidad),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _PedidoProductoDecision {
  const _PedidoProductoDecision({
    required this.cantidad,
    required this.ingredientesExcluidos,
    required this.adiciones,
    this.observacion,
  });

  final double cantidad;
  final List<int> ingredientesExcluidos;
  final List<int> adiciones;
  final String? observacion;
}

class _PersonalizarProductoDialog extends ConsumerStatefulWidget {
  const _PersonalizarProductoDialog({
    required this.producto,
    this.initialQuantity = 1,
  });

  final MeseroProductoModel producto;
  final double initialQuantity;

  @override
  ConsumerState<_PersonalizarProductoDialog> createState() =>
      _PersonalizarProductoDialogState();
}

class _PersonalizarProductoDialogState
    extends ConsumerState<_PersonalizarProductoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cantidadController;
  final _observacionController = TextEditingController();
  final Set<int> _excluded = <int>{};
  final Set<int> _additions = <int>{};

  @override
  void initState() {
    super.initState();
    _cantidadController = TextEditingController(
      text: _formatCantidadGeneral(widget.initialQuantity),
    );
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  double get _cantidad =>
      double.tryParse(_cantidadController.text.trim().replaceAll(',', '.')) ?? 0;

  double get _adicionalUnitario {
    return widget.producto.adiciones
        .where((item) => item.id != null && _additions.contains(item.id))
        .fold<double>(0, (sum, item) => sum + (item.precioAdicional ?? 0));
  }

  double get _total =>
      _cantidad * ((widget.producto.precioVenta ?? 0) + _adicionalUnitario);

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final producto = widget.producto;
    final removibles = producto.ingredientes
        .where((item) => item.removible == true && item.id != null)
        .toList(growable: false);
    final obligatorios = producto.ingredientes
        .where((item) => item.removible != true)
        .toList(growable: false);

    return AlertDialog(
      backgroundColor:
          palette.surface.withOpacity(palette.darkBackground ? .98 : 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.cardBorder),
      ),
      title: Row(
        children: [
          _ProductImageThumb(value: producto.foto, size: 52),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre ?? 'Producto preparado',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Personaliza el pedido',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cantidadController,
                        keyboardType: TextInputType.number,
                        inputFormatters:
                            InputConstraints.decimalFormatters(integerDigits: 10, fractionDigits: 0),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final parsed = double.tryParse(
                                  (value ?? '').trim().replaceAll(',', '.')) ??
                              0;
                          return parsed <= 0
                              ? 'Ingresa una cantidad mayor a cero'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: palette.secondary.withOpacity(.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total del pedido',
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              CurrencyUtils.format(_total),
                              style: TextStyle(
                                color: palette.secondary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (removibles.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Quitar ingredientes',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Marca lo que el cliente no quiere.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ...removibles.map((item) {
                    final id = item.id!;
                    return CheckboxListTile(
                      value: _excluded.contains(id),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        'Sin ${item.nombre ?? 'ingrediente'}',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${_formatCantidadGeneral(item.cantidad ?? 0)} ${item.unidad ?? ''}',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _excluded.add(id);
                        } else {
                          _excluded.remove(id);
                        }
                      }),
                    );
                  }),
                ],
                if (obligatorios.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ingredientes base no removibles: ${obligatorios.map((e) => e.nombre ?? 'Ingrediente').join(', ')}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (producto.adiciones.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Adiciones',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ...producto.adiciones.where((item) => item.id != null).map((item) {
                    final id = item.id!;
                    return CheckboxListTile(
                      value: _additions.contains(id),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        item.nombre ?? 'Adición',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${_formatCantidadGeneral(item.cantidad ?? 0)} ${item.unidad ?? ''} · +${CurrencyUtils.format(item.precioAdicional ?? 0)}',
                        style: TextStyle(color: palette.textSecondary),
                      ),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _additions.add(id);
                        } else {
                          _additions.remove(id);
                        }
                      }),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _observacionController,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Preparación / observación',
                    hintText:
                        'Ejemplo: término medio, sin sal, salsa aparte...',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
                if (_adicionalUnitario > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Adiciones por unidad: +${CurrencyUtils.format(_adicionalUnitario)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: palette.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _PedidoProductoDecision(
                cantidad: _cantidad,
                ingredientesExcluidos: _excluded.toList(growable: false),
                adiciones: _additions.toList(growable: false),
                observacion: _observacionController.text.trim().isEmpty
                    ? null
                    : _observacionController.text.trim(),
              ),
            );
          },
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: Text('Agregar · ${CurrencyUtils.format(_total)}'),
        ),
      ],
    );
  }
}

class _CantidadProductoDialog extends ConsumerStatefulWidget {
  const _CantidadProductoDialog({required this.producto});

  final MeseroProductoModel producto;

  @override
  ConsumerState<_CantidadProductoDialog> createState() => _CantidadProductoDialogState();
}

class _CantidadProductoDialogState extends ConsumerState<_CantidadProductoDialog> {
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
    final palette = ref.watch(selectedAppPaletteProvider);
    final producto = widget.producto;
    final cantidad = _parseCantidad(_cantidadController.text);
    final precio = producto.precioVenta ?? 0;
    final total = cantidad * precio;

    return AlertDialog(
      backgroundColor: palette.surface.withOpacity(palette.darkBackground ? 0.96 : 0.99),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: palette.cardBorder)),
      title: Text('Cantidad del producto', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
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
                        Text(producto.nombre ?? 'Producto ${producto.prodId ?? '-'}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: palette.textPrimary)),
                        const SizedBox(height: 6),
                        Text(
                          producto.descripcion ?? 'Sin descripción',
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
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
                decoration: BoxDecoration(color: palette.background.withOpacity(palette.darkBackground ? 0.50 : 0.68), borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.cardBorder)),
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
                      inputFormatters: InputConstraints.decimalFormatters(integerDigits: 10, fractionDigits: 0),
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
              Text(
                'Selecciona la cantidad completa para no tener que agregar el mismo producto uno por uno.',
                style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
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
    final palette = ref.watch(selectedAppPaletteProvider);
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: TextStyle(fontWeight: FontWeight.w900, color: palette.textPrimary)),
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
                  maxLength: 10,
                  inputFormatters: InputConstraints.integerFormatters(maxValue: 2147483647),
                  decoration: const InputDecoration(
                    labelText: 'Número de mesa',
                    hintText: 'Ejemplo: 12',
                    counterText: '',
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
                  maxLength: 10,
                  inputFormatters: InputConstraints.integerFormatters(maxValue: 2147483647),
                  decoration: const InputDecoration(labelText: 'Número de mesa', counterText: ''),
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

    if (bytes.length > InputConstraints.imageMaxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La imagen es demasiado pesada. Usa una foto de máximo 2 MB.')),
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
  const _BarlyticsImage({
    required this.value,
    required this.width,
    required this.height,
    this.radius = 0,
    this.fit = BoxFit.cover,
  });

  final String value;
  final double width;
  final double height;
  final double radius;
  final BoxFit fit;

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
          return Image.memory(base64Decode(imageValue.substring(index + 1)), width: width, height: height, fit: fit);
        } catch (_) {
          return fallback;
        }
      }
    }
    return Image.network(imageValue, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => fallback);
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
                    maxLength: 10,
                    inputFormatters: InputConstraints.integerFormatters(maxValue: 2147483647),
                    decoration: const InputDecoration(
                      labelText: 'Número de cuentas',
                      hintText: 'Ejemplo: 6',
                      helperText: 'Sin límite funcional; el valor debe ser un entero válido.',
                      counterText: '',
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
                    maxLength: 10,
                    inputFormatters: InputConstraints.integerFormatters(maxValue: 2147483647),
                    decoration: const InputDecoration(
                      labelText: 'Número de cuentas',
                      hintText: 'Ejemplo: 3',
                      helperText: 'Puedes registrar las cuentas que necesites.',
                      counterText: '',
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
