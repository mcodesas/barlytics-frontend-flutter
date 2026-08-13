import '../../../../core/constants/api_paths.dart';
import '../../../../core/network/api_client.dart';
import '../models/mesero_models.dart';

class MeseroRemoteDataSource {
  MeseroRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MeseroMesaResumenModel>> listarMesas() async {
    final response = await _apiClient.get<List<MeseroMesaResumenModel>>(
      ApiPaths.meseroMesas,
      (json) => (json as List? ?? const [])
          .map((e) => MeseroMesaResumenModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
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

  Future<List<MeseroProductoModel>> listarProductos() async {
    final response = await _apiClient.get<List<MeseroProductoModel>>(
      ApiPaths.meseroProductos,
      (json) => (json as List? ?? const [])
          .map((e) => MeseroProductoModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
    return response.data ?? const <MeseroProductoModel>[];
  }

  Future<List<MeseroMedioPagoModel>> listarMediosPago() async {
    final response = await _apiClient.get<List<MeseroMedioPagoModel>>(
      ApiPaths.meseroMediosPago,
      (json) => (json as List? ?? const [])
          .map((e) => MeseroMedioPagoModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
    return response.data ?? const <MeseroMedioPagoModel>[];
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
    return response.data!;
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

  Future<List<MeseroVentaModel>> historialVentas() async {
    final response = await _apiClient.get<List<MeseroVentaModel>>(
      ApiPaths.meseroHistorialVentas,
      (json) => (json as List? ?? const [])
          .map((e) => MeseroVentaModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
    return response.data ?? const <MeseroVentaModel>[];
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
  }) async {
    final response = await _apiClient.post<MeseroVentaModel>(
      ApiPaths.meseroAgregarProductoCuenta(cuentaId),
      {
        'prodId': productoId,
        if (precioId != null) 'precId': precioId,
        'cantidad': cantidad,
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
