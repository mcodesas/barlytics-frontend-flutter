import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../models/mesero_models.dart';

/// Una venta de mostrador solo puede abrir su panel si ya tiene la
/// cuenta inicial persistida. Se comparte entre apertura y reanudación.
bool cuentaDirectaLista(MeseroVentaModel venta) =>
    venta.ventaId != null && venta.cuentas.any((cuenta) => cuenta.cuentaId != null);

class MeseroRemoteDataSource {
  MeseroRemoteDataSource(this._apiClient);

  static const Duration _catalogCacheTtl = Duration(minutes: 2);

  final ApiClient _apiClient;

  List<MeseroProductoModel>? _productosCache;
  DateTime? _productosCachedAt;
  Future<List<MeseroProductoModel>>? _productosInFlight;

  List<MeseroMedioPagoModel>? _mediosPagoCache;
  DateTime? _mediosPagoCachedAt;
  Future<List<MeseroMedioPagoModel>>? _mediosPagoInFlight;

  Future<List<MeseroMesaResumenModel>> listarMesas() async {
    final response = await _apiClient.get<List<MeseroMesaResumenModel>>(
      ApiPaths.meseroMesas,
      (json) => (json as List? ?? const [])
          .map((e) => MeseroMesaResumenModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      // La pantalla POS no dibuja fotos de mesas; evitar transferir base64.
      queryParameters: const {'incluirFotos': false},
    );
    return response.data ?? const <MeseroMesaResumenModel>[];
  }

  Future<MeseroMesaResumenModel> crearMesa({required int mesaNumero, String? mesaDescripcion, String? mesaFoto}) async {
    final response = await _apiClient.post<MeseroMesaResumenModel>(
      ApiPaths.meseroCrearMesa,
      {
        'mesaNumero': mesaNumero,
        if ((mesaDescripcion ?? '').trim().isNotEmpty) 'mesaDescripcion': mesaDescripcion!.trim(),
        if ((mesaFoto ?? '').trim().isNotEmpty) 'mesaFoto': mesaFoto!.trim(),
        'mesaEstado': 'DISPONIBLE',
      },
      (json) => MeseroMesaResumenModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<MeseroMesaResumenModel> editarMesa({
    required int mesaId,
    required int mesaNumero,
    String? mesaDescripcion,
    String? mesaEstado,
    String? mesaFoto,
  }) async {
    final response = await _apiClient.put<MeseroMesaResumenModel>(
      ApiPaths.meseroMesa(mesaId),
      {
        'mesaNumero': mesaNumero,
        'mesaDescripcion': mesaDescripcion?.trim(),
        'mesaFoto': mesaFoto?.trim(),
        if ((mesaEstado ?? '').trim().isNotEmpty) 'mesaEstado': mesaEstado!.trim(),
      },
      (json) => MeseroMesaResumenModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<void> eliminarMesa(int mesaId) async {
    await _apiClient.delete<void>(
      ApiPaths.meseroMesa(mesaId),
      (_) {},
    );
  }

  Future<List<MeseroProductoModel>> listarProductos({bool forceRefresh = false}) async {
    if (!forceRefresh && _isFresh(_productosCachedAt) && _productosCache != null) {
      return _productosCache!;
    }

    final currentRequest = _productosInFlight;
    if (!forceRefresh && currentRequest != null) return currentRequest;

    final request = _fetchProductos();
    _productosInFlight = request;
    try {
      final productos = await request;
      _productosCache = productos;
      _productosCachedAt = DateTime.now();
      return productos;
    } finally {
      if (identical(_productosInFlight, request)) {
        _productosInFlight = null;
      }
    }
  }

  Future<List<MeseroProductoModel>> _fetchProductos() async {
    final response = await _apiClient.get<List<MeseroProductoModel>>(
      ApiPaths.meseroProductos,
      (json) => (json as List? ?? const [])
          .map((e) => MeseroProductoModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
    return response.data ?? const <MeseroProductoModel>[];
  }

  Future<List<MeseroMedioPagoModel>> listarMediosPago({bool forceRefresh = false}) async {
    if (!forceRefresh && _isFresh(_mediosPagoCachedAt) && _mediosPagoCache != null) {
      return _mediosPagoCache!;
    }

    final currentRequest = _mediosPagoInFlight;
    if (!forceRefresh && currentRequest != null) return currentRequest;

    final request = _fetchMediosPago();
    _mediosPagoInFlight = request;
    try {
      final medios = await request;
      _mediosPagoCache = medios;
      _mediosPagoCachedAt = DateTime.now();
      return medios;
    } finally {
      if (identical(_mediosPagoInFlight, request)) {
        _mediosPagoInFlight = null;
      }
    }
  }

  Future<List<MeseroMedioPagoModel>> _fetchMediosPago() async {
    final response = await _apiClient.get<List<MeseroMedioPagoModel>>(
      ApiPaths.meseroMediosPago,
      (json) => (json as List? ?? const [])
          .map((e) => MeseroMedioPagoModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
    return response.data ?? const <MeseroMedioPagoModel>[];
  }

  void invalidateCatalogCache() {
    _productosCache = null;
    _productosCachedAt = null;
    _mediosPagoCache = null;
    _mediosPagoCachedAt = null;
  }

  bool _isFresh(DateTime? cachedAt) {
    if (cachedAt == null) return false;
    return DateTime.now().difference(cachedAt) < _catalogCacheTtl;
  }

  Future<MeseroVentaModel> abrirVenta({
    required int mesaId,
    required bool dividirCuentas,
    required int numeroCuentas,
    String? mesaDescripcion,
    Map<int, String>? descripcionesCuentas,
  }) async {
    final response = await _apiClient.post<MeseroVentaModel>(
      ApiPaths.meseroAbrirVenta,
      {
        'mesaId': mesaId,
        'dividirCuentas': dividirCuentas,
        'numeroCuentas': numeroCuentas,
        if ((mesaDescripcion ?? '').trim().isNotEmpty) 'mesaDescripcion': mesaDescripcion!.trim(),
        if (descripcionesCuentas != null) 'descripcionesCuentas': _accountDescriptionsToJson(descripcionesCuentas),
      },
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<MeseroVentaModel> abrirVentaDirecta() async {
    final response = await _apiClient.post<MeseroVentaModel>(
      ApiPaths.meseroAbrirVentaDirecta,
      const <String, dynamic>{},
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    final venta = response.data;
    if (venta == null || venta.ventaId == null) {
      throw StateError('No se recibió el identificador de la venta directa.');
    }
    if (cuentaDirectaLista(venta)) return venta;

    // Compatibilidad con backends que responden antes de sincronizar INSERT
    // de CUENTAVENTA: una única consulta de la venta ya confirmada.
    // NO volver a ejecutar POST: se crearían ventas directas duplicadas.
    final completa = await consultarVenta(venta.ventaId!);
    if (!cuentaDirectaLista(completa)) {
      throw StateError(
        'La venta directa ${venta.ventaId} fue creada, pero aún no tiene una cuenta disponible. '
        'Puedes retomarla desde ventas directas pendientes.',
      );
    }
    return completa;
  }

  Future<List<MeseroVentaModel>> listarVentasDirectasAbiertas() async {
    final response = await _apiClient.get<List<MeseroVentaModel>>(
      ApiPaths.meseroVentasDirectasAbiertas,
      (json) => (json as List? ?? const [])
          .map((e) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
    return response.data ?? const <MeseroVentaModel>[];
  }

  Future<MeseroVentaModel> consultarVenta(int ventaId) async {
    final response = await _apiClient.get<MeseroVentaModel>(
      ApiPaths.meseroVenta(ventaId),
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  /// Mantiene compatibilidad con la pantalla actual: si no se especifican
  /// filtros ni paginación, el backend conserva el comportamiento histórico.
  /// Las nuevas vistas pueden consultar un día/página concretos sin cargar todo.
  Future<List<MeseroVentaModel>> historialVentas({
    String? desde,
    String? hasta,
    int? pagina,
    int? tamano,
  }) async {
    final response = await _apiClient.get<List<MeseroVentaModel>>(
      ApiPaths.meseroHistorialVentas,
      (json) => (json as List? ?? const [])
          .map((e) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      queryParameters: {
        if ((desde ?? '').trim().isNotEmpty) 'desde': desde!.trim(),
        if ((hasta ?? '').trim().isNotEmpty) 'hasta': hasta!.trim(),
        if (pagina != null) 'pagina': pagina,
        if (tamano != null) 'tamano': tamano,
      },
    );
    return response.data ?? const <MeseroVentaModel>[];
  }

  Future<Map<int, double>> productosMasPedidosHoy({required String fecha}) async {
    final response = await _apiClient.get<Map<int, double>>(
      ApiPaths.meseroProductosMasPedidosHoy,
      (json) {
        final values = Map<String, dynamic>.from(json as Map? ?? const <String, dynamic>{});
        final result = <int, double>{};
        for (final entry in values.entries) {
          final productoId = int.tryParse(entry.key);
          final cantidad = entry.value is num
              ? (entry.value as num).toDouble()
              : double.tryParse(entry.value?.toString() ?? '');
          if (productoId != null && cantidad != null && cantidad > 0) {
            result[productoId] = cantidad;
          }
        }
        return result;
      },
      queryParameters: {'fecha': fecha},
    );
    return response.data ?? const <int, double>{};
  }

  Future<MeseroVentaModel> cambiarNumeroCuentas({
    required int ventaId,
    required int numeroCuentas,
    Map<int, String>? descripcionesCuentas,
  }) async {
    final response = await _apiClient.put<MeseroVentaModel>(
      ApiPaths.meseroVentaCuentas(ventaId),
      {
        'numeroCuentas': numeroCuentas,
        if (descripcionesCuentas != null) 'descripcionesCuentas': _accountDescriptionsToJson(descripcionesCuentas),
      },
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<void> limpiarVentaSinConsumos(int ventaId) async {
    await _apiClient.delete<void>(
      ApiPaths.meseroLimpiarVentaSinConsumos(ventaId),
      (_) {},
    );
  }

  Future<void> cancelarVentaDirecta(int ventaId) async {
    await _apiClient.delete<void>(
      ApiPaths.meseroCancelarVentaDirecta(ventaId),
      (_) {},
    );
  }

  Future<MeseroVentaModel> eliminarCuenta(int cuentaId) async {
    final response = await _apiClient.delete<MeseroVentaModel>(
      ApiPaths.meseroEliminarCuenta(cuentaId),
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<MeseroVentaModel> agregarProducto({
    required int cuentaId,
    required int productoId,
    int? precioId,
    double cantidad = 1,
    List<int> ingredientesExcluidos = const <int>[],
    List<int> adiciones = const <int>[],
    String? observacion,
  }) async {
    final response = await _apiClient.post<MeseroVentaModel>(
      ApiPaths.meseroAgregarProductoCuenta(cuentaId),
      {
        'prodId': productoId,
        if (precioId != null) 'precId': precioId,
        'cantidad': cantidad,
        if (ingredientesExcluidos.isNotEmpty) 'ingredientesExcluidos': ingredientesExcluidos,
        if (adiciones.isNotEmpty) 'adiciones': adiciones,
        if ((observacion ?? '').trim().isNotEmpty) 'observacion': observacion!.trim(),
      },
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<MeseroVentaModel> actualizarCantidadProductoCuenta({
    required int cuentaId,
    required int detalleId,
    required double cantidad,
  }) async {
    final response = await _apiClient.put<MeseroVentaModel>(
      ApiPaths.meseroActualizarCantidadProductoCuenta(cuentaId, detalleId),
      {'cantidad': cantidad},
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<MeseroVentaModel> aplicarDescuento({
    required String alcance,
    required int id,
    int? cuentaId,
    required String tipo,
    required double valor,
    String motivo = '',
  }) async {
    final path = switch (alcance) {
      'VENTA' => '/api/v1/mesero/ventas/$id/descuento',
      'CUENTA' => '/api/v1/mesero/cuentas/$id/descuento',
      'PRODUCTO' => '/api/v1/mesero/cuentas/$cuentaId/productos/$id/descuento',
      _ => throw ArgumentError.value(alcance, 'alcance'),
    };
    if (alcance == 'PRODUCTO' && cuentaId == null) {
      throw StateError('Selecciona una cuenta.');
    }
    final response = await _apiClient.put<MeseroVentaModel>(
      path,
      {'tipo': tipo, 'valor': valor, 'motivo': motivo.trim()},
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<MeseroVentaModel> eliminarProductoCuenta({
    required int cuentaId,
    required int detalleId,
  }) async {
    final response = await _apiClient.delete<MeseroVentaModel>(
      ApiPaths.meseroEliminarProductoCuenta(cuentaId, detalleId),
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<MeseroVentaModel> moverProductoCuenta({
    required int cuentaOrigenId,
    required int detalleId,
    required int cuentaDestinoId,
  }) async {
    final response = await _apiClient.put<MeseroVentaModel>(
      ApiPaths.meseroMoverProductoCuenta(cuentaOrigenId, detalleId, cuentaDestinoId),
      const <String, dynamic>{},
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<MeseroVentaModel> eliminarPagoCuenta({
    required int cuentaId,
    required int pagoId,
  }) async {
    final response = await _apiClient.delete<MeseroVentaModel>(
      ApiPaths.meseroEliminarPagoCuenta(cuentaId, pagoId),
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<void> cambiarMedioPagoCuenta({
    required int pagoId,
    required int medioPagoId,
  }) async {
    await _apiClient.put<Map<String, dynamic>>(
      ApiPaths.pagoCambiarMedioPago(pagoId),
      {'medioPagoId': medioPagoId},
      (json) => Map<String, dynamic>.from(json as Map),
    );
  }

  Future<MeseroVentaModel> registrarPagosCuenta({
    required int cuentaId,
    required double propina,
    required List<Map<String, dynamic>> pagos,
  }) async {
    final response = await _apiClient.put<MeseroVentaModel>(
      ApiPaths.meseroPagarCuenta(cuentaId),
      {
        'propina': propina,
        'pagos': pagos,
      },
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  /// Anula venta finalizada. No borra el histórico, concilia inventario y caja.
  Future<Map<String, dynamic>> anularVentaFinalizada(
      int ventaId, String motivo) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/mesero/ventas/$ventaId/anular',
      {'motivo': motivo.trim()},
      (json) => Map<String, dynamic>.from(json as Map),
    );
    return response.data ?? const <String, dynamic>{};
  }

  /// Anula la venta original y devuelve nueva venta editable, sin pagos.
  Future<Map<String, dynamic>> corregirVentaFinalizada(
      int ventaId, String motivo) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/mesero/ventas/$ventaId/corregir',
      {'motivo': motivo.trim()},
      (json) => Map<String, dynamic>.from(json as Map),
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> auditoriaAnulacionVenta(int ventaId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/mesero/ventas/$ventaId/anulacion',
      (json) => Map<String, dynamic>.from(json as Map),
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<MeseroVentaModel> finalizarVenta(int ventaId) async {
    final response = await _apiClient.post<MeseroVentaModel>(
      ApiPaths.meseroFinalizarVenta(ventaId),
      const <String, dynamic>{},
      (json) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<CierreCajaResumenModel> consultarCierreCaja({String? fecha}) async {
    final response = await _apiClient.get<CierreCajaResumenModel>(
      ApiPaths.meseroCierreCajaResumen,
      (json) => CierreCajaResumenModel.fromJson(Map<String, dynamic>.from(json as Map)),
      queryParameters: fecha == null ? null : {'fecha': fecha},
    );
    return response.data!;
  }

  Future<CierreCajaResumenModel> guardarBaseInicialCierreCaja({
    required String fecha,
    required double valorBase,
  }) async {
    final response = await _apiClient.put<CierreCajaResumenModel>(
      ApiPaths.meseroCierreCajaBaseInicial,
      {
        'fecha': fecha,
        'valorBase': valorBase,
      },
      (json) => CierreCajaResumenModel.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    return response.data!;
  }

  Future<CierreCajaResumenModel> registrarCierreCaja({
    required String fecha,
    required List<Map<String, dynamic>> mediosPago,
    double valorBase = 0,
    List<Map<String, dynamic>> gastos = const <Map<String, dynamic>>[],
    String? observacion,
  }) async {
    final response = await _apiClient.post<CierreCajaResumenModel>(
      ApiPaths.meseroCierreCaja,
      {
        'fecha': fecha,
        'mediosPago': mediosPago,
        'valorBase': valorBase,
        'gastos': gastos,
        if ((observacion ?? '').trim().isNotEmpty) 'observacion': observacion!.trim(),
      },
      (json) => CierreCajaResumenModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<CierreCajaResumenModel> actualizarCierreCaja({
    required int cierreCajaId,
    required String fecha,
    required List<Map<String, dynamic>> mediosPago,
    double valorBase = 0,
    List<Map<String, dynamic>> gastos = const <Map<String, dynamic>>[],
    String? observacion,
  }) async {
    final response = await _apiClient.put<CierreCajaResumenModel>(
      ApiPaths.meseroCierreCajaById(cierreCajaId),
      {
        'fecha': fecha,
        'mediosPago': mediosPago,
        'valorBase': valorBase,
        'gastos': gastos,
        if ((observacion ?? '').trim().isNotEmpty) 'observacion': observacion!.trim(),
      },
      (json) => CierreCajaResumenModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<CierreCajaResumenModel> conciliarVentasPosteriores({
    required int cierreCajaId,
    required List<int> ventaIds,
    required String motivo,
  }) async {
    final response = await _apiClient.post<CierreCajaResumenModel>(
      ApiPaths.meseroCierreCajaConciliarVentas(cierreCajaId),
      {'ventaIds': ventaIds, 'motivo': motivo.trim()},
      (json) => CierreCajaResumenModel.fromJson(
        Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<SalidaCajaOpcionesModel> opcionesSalidaCaja() async {
    final response = await _apiClient.get<SalidaCajaOpcionesModel>(
      ApiPaths.meseroCierreCajaSalidaOpciones,
      (json) => SalidaCajaOpcionesModel.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    return response.data ?? const SalidaCajaOpcionesModel();
  }

  Future<SalidaCajaModel> registrarSalidaCaja({
    required String fecha,
    required String tipo,
    required double valor,
    String? categoria,
    String? descripcion,
    int? gastoId,
    int? pedidoId,
    int? medioPagoId,
  }) async {
    final response = await _apiClient.post<SalidaCajaModel>(
      ApiPaths.meseroCierreCajaSalidas,
      {
        'fecha': fecha,
        'tipo': tipo,
        'valor': valor,
        if ((categoria ?? '').trim().isNotEmpty) 'categoria': categoria!.trim(),
        if ((descripcion ?? '').trim().isNotEmpty) 'descripcion': descripcion!.trim(),
        if (gastoId != null) 'gastoId': gastoId,
        if (pedidoId != null) 'pedidoId': pedidoId,
        if (medioPagoId != null) 'medioPagoId': medioPagoId,
      },
      (json) => SalidaCajaModel.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
    return response.data!;
  }

  Future<SalidaCajaModel> actualizarSalidaCaja({
    required int salidaId,
    required String fecha,
    required String tipo,
    required double valor,
    String? categoria,
    String? descripcion,
    int? gastoId,
    int? pedidoId,
    int? medioPagoId,
  }) async {
    final response = await _apiClient.put<SalidaCajaModel>(
      ApiPaths.meseroCierreCajaSalidaById(salidaId),
      {
        'fecha': fecha,
        'tipo': tipo,
        'valor': valor,
        if ((categoria ?? '').trim().isNotEmpty) 'categoria': categoria!.trim(),
        if ((descripcion ?? '').trim().isNotEmpty) 'descripcion': descripcion!.trim(),
        if (gastoId != null) 'gastoId': gastoId,
        if (pedidoId != null) 'pedidoId': pedidoId,
        if (medioPagoId != null) 'medioPagoId': medioPagoId,
      },
      (json) => SalidaCajaModel.fromJson(Map<String, dynamic>.from(json as Map)),
    );
    return response.data!;
  }

  Future<void> anularSalidaCaja(int salidaId) async {
    await _apiClient.delete<void>(
      ApiPaths.meseroCierreCajaSalidaById(salidaId),
      (_) {},
    );
  }

  Future<String> descargarReporteCierreCaja({String? fecha}) async {
    final response = await _apiClient.get<String>(
      ApiPaths.meseroCierreCajaReporte,
      (json) => json?.toString() ?? '',
      queryParameters: fecha == null ? null : {'fecha': fecha},
    );
    return response.data ?? '';
  }

  Map<String, String> _accountDescriptionsToJson(Map<int, String> values) {
    return values.map((key, value) => MapEntry(key.toString(), value.trim()));
  }
}
