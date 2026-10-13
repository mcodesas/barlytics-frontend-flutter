import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../productos/data/models/productos_response_model.dart';
import '../../data/models/inventario_response_model.dart';

class InventarioConteoState {
  const InventarioConteoState({
    this.productos = const <ProductosResponseModel>[],
    this.registrosHoy = const <int, InventarioResponseModel>{},
    this.ultimosConteos = const <int, InventarioResponseModel>{},
    this.conteosPendientes = const <int, InventarioResponseModel>{},
    this.ultimoConteoEn,
    this.guardandoProductos = const <int>{},
    this.loading = false,
    this.failure,
    this.sucursalId,
    this.actualizadoEn,
  });

  final List<ProductosResponseModel> productos;
  final Map<int, InventarioResponseModel> registrosHoy;
  final Map<int, InventarioResponseModel> ultimosConteos;
  final Map<int, InventarioResponseModel> conteosPendientes;
  final DateTime? ultimoConteoEn;
  final Set<int> guardandoProductos;
  final bool loading;
  final Failure? failure;
  final int? sucursalId;
  final DateTime? actualizadoEn;

  InventarioConteoState copyWith({
    List<ProductosResponseModel>? productos,
    Map<int, InventarioResponseModel>? registrosHoy,
    Map<int, InventarioResponseModel>? ultimosConteos,
    Map<int, InventarioResponseModel>? conteosPendientes,
    DateTime? ultimoConteoEn,
    Set<int>? guardandoProductos,
    bool? loading,
    Failure? failure,
    bool clearFailure = false,
    int? sucursalId,
    DateTime? actualizadoEn,
  }) {
    return InventarioConteoState(
      productos: productos ?? this.productos,
      registrosHoy: registrosHoy ?? this.registrosHoy,
      ultimosConteos: ultimosConteos ?? this.ultimosConteos,
      conteosPendientes: conteosPendientes ?? this.conteosPendientes,
      ultimoConteoEn: ultimoConteoEn ?? this.ultimoConteoEn,
      guardandoProductos: guardandoProductos ?? this.guardandoProductos,
      loading: loading ?? this.loading,
      failure: clearFailure ? null : (failure ?? this.failure),
      sucursalId: sucursalId ?? this.sucursalId,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }
}

class InventarioConteoNotifier extends StateNotifier<InventarioConteoState> {
  InventarioConteoNotifier(this._apiClient, this._initialSucursalId)
      : super(InventarioConteoState(sucursalId: _initialSucursalId)) {
    load(sucursalId: _initialSucursalId);
  }

  final ApiClient _apiClient;
  final int? _initialSucursalId;

  Future<void> load({int? sucursalId}) async {
    final selectedSucursalId =
        sucursalId ?? state.sucursalId ?? _initialSucursalId;

    if (selectedSucursalId == null) {
      state = const InventarioConteoState(
        failure: ValidationFailure(
          'Selecciona una sucursal antes de iniciar el conteo de inventario.',
        ),
      );
      return;
    }

    final branchChanged = state.sucursalId != selectedSucursalId;
    state = branchChanged
        ? InventarioConteoState(
            loading: true,
            sucursalId: selectedSucursalId,
          )
        : state.copyWith(
            loading: true,
            sucursalId: selectedSucursalId,
            clearFailure: true,
          );

    try {
      final productos = await _loadAllProducts(selectedSucursalId);
      final registros = await _loadInventoryRecords(selectedSucursalId);
      final estadosConciliacion =
          await _loadReconciliationStatuses(selectedSucursalId);
      final registrosHoy = _latestRecordsToday(registros);
      final ultimosConteos = _latestPhysicalCounts(registros);
      final conteosPendientes = <int, InventarioResponseModel>{
        for (final entry in ultimosConteos.entries)
          if (entry.value.invtOrigen == 'CONTEO_FISICO' &&
              (entry.value.invtDiferencia ?? 0).abs() > 0.0001 &&
              estadosConciliacion[entry.value.invtId] == 'PENDIENTE')
            entry.key: entry.value,
      };
      final ultimoConteoEn = _latestCountDate(ultimosConteos.values);

      state = InventarioConteoState(
        productos: productos,
        registrosHoy: registrosHoy,
        ultimosConteos: ultimosConteos,
        conteosPendientes: conteosPendientes,
        ultimoConteoEn: ultimoConteoEn,
        sucursalId: selectedSucursalId,
        actualizadoEn: DateTime.now(),
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        failure: ErrorMapper.map(error),
      );
    }
  }

  Future<bool> registrarConteo({
    required ProductosResponseModel producto,
    required double cantidad,
  }) async {
    final productId = producto.prodId;
    final sucursalId = state.sucursalId ?? producto.sucuId;
    if (productId == null || sucursalId == null || cantidad < 0) return false;

    if (producto.sucuId != null && producto.sucuId != sucursalId) {
      state = state.copyWith(
        failure: const ValidationFailure(
          'El producto no pertenece a la sucursal activa. Actualiza la lista e inténtalo nuevamente.',
        ),
      );
      return false;
    }

    state = state.copyWith(
      guardandoProductos: {...state.guardandoProductos, productId},
      clearFailure: true,
    );

    try {
      final previousRecord = state.registrosHoy[productId];
      final payload = <String, dynamic>{
        'prodId': productId,
        'sucuId': sucursalId,
        'invtCantidad': cantidad,
        'invtFecha': DateTime.now().toIso8601String(),
      };
      final response = previousRecord?.invtId == null
          ? await _apiClient.post<InventarioResponseModel>(
              '/api/v1/inventario',
              payload,
              (json) => InventarioResponseModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ),
            )
          : await _apiClient.put<InventarioResponseModel>(
              '/api/v1/inventario/${previousRecord!.invtId}',
              payload,
              (json) => InventarioResponseModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ),
            );

      final saved = response.data ??
          InventarioResponseModel(
            invtId: previousRecord?.invtId,
            prodId: productId,
            sucuId: sucursalId,
            invtCantidad: cantidad,
            invtFecha: DateTime.now().toIso8601String(),
            invtOrigen: previousRecord?.invtOrigen ?? 'CONTEO_FISICO',
            invtCantidadEsperada: previousRecord?.invtCantidadEsperada,
            invtDiferencia: previousRecord?.invtCantidadEsperada == null
                ? null
                : cantidad - previousRecord!.invtCantidadEsperada!,
          );

      final updatedRecords = <int, InventarioResponseModel>{
        ...state.registrosHoy,
        productId: saved,
      };
      final updatedLastCounts = <int, InventarioResponseModel>{
        ...state.ultimosConteos,
        productId: saved,
      };
      final updatedPending = <int, InventarioResponseModel>{
        ...state.conteosPendientes,
      };
      if (saved.invtOrigen == 'CONTEO_FISICO' &&
          (saved.invtDiferencia ?? 0).abs() > 0.0001) {
        updatedPending[productId] = saved;
      } else {
        updatedPending.remove(productId);
      }

      final updatedProducts = state.productos
          .map(
            (item) => item.prodId == productId
                ? _productWithInventory(item, cantidad)
                : item,
          )
          .toList(growable: false);
      final saving = {...state.guardandoProductos}..remove(productId);
      final savedDate = DateTime.tryParse(saved.invtFecha ?? '');

      state = state.copyWith(
        productos: updatedProducts,
        registrosHoy: updatedRecords,
        ultimosConteos: updatedLastCounts,
        conteosPendientes: updatedPending,
        ultimoConteoEn: savedDate ?? state.ultimoConteoEn,
        guardandoProductos: saving,
        actualizadoEn: DateTime.now(),
        clearFailure: true,
      );
      return true;
    } catch (error) {
      final saving = {...state.guardandoProductos}..remove(productId);
      state = state.copyWith(
        guardandoProductos: saving,
        failure: ErrorMapper.map(error),
      );
      return false;
    }
  }

  Future<bool> sincronizarDiferencias({
    required List<InventarioResponseModel> registros,
    required String motivo,
    required String observacion,
  }) async {
    if (registros.isEmpty) return true;
    state = state.copyWith(loading: true, clearFailure: true);
    try {
      for (final registro in registros) {
        if (registro.invtId == null) continue;
        await _apiClient.post<Object?>(
          '/api/v1/inventario/sincronizar-conteo',
          <String, dynamic>{
            'invtId': registro.invtId,
            'motivo': motivo,
            'observacion': observacion,
          },
          (json) => json,
        );
      }
      await load(sucursalId: state.sucursalId);
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }

  Future<List<ProductosResponseModel>> _loadAllProducts(int sucursalId) async {
    final items = <ProductosResponseModel>[];
    var page = 0;
    var last = false;

    while (!last) {
      final response = await _apiClient.get<ProductosPageResponseModel>(
        '/api/v1/productos/page',
        (json) => ProductosPageResponseModel.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
        queryParameters: <String, dynamic>{
          'page': page,
          'size': 100,
          'sucursalId': sucursalId,
          'sortBy': 'nombre',
          'direction': 'ASC',
        },
      );
      final result = response.data ?? const ProductosPageResponseModel();
      items.addAll(
        result.content.where(
          (product) => product.sucuId == null || product.sucuId == sucursalId,
        ),
      );
      last = result.last || result.content.isEmpty;
      page += 1;
      if (page > 100) break;
    }

    items.sort(
      (a, b) => (a.prodNombre ?? '').toLowerCase().compareTo(
            (b.prodNombre ?? '').toLowerCase(),
          ),
    );
    return items;
  }

  Future<List<InventarioResponseModel>> _loadInventoryRecords(
    int sucursalId,
  ) async {
    final response = await _apiClient.get<List<InventarioResponseModel>>(
      '/api/v1/inventario/sucursal/$sucursalId',
      (json) => (json as List? ?? const <Object>[])
          .whereType<Map>()
          .map(
            (item) => InventarioResponseModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((item) => item.sucuId == null || item.sucuId == sucursalId)
          .toList(growable: false),
    );
    return response.data ?? const <InventarioResponseModel>[];
  }

  Future<Map<int, String>> _loadReconciliationStatuses(
    int sucursalId,
  ) async {
    final response = await _apiClient.get<List<Map<String, dynamic>>>(
      '/api/v1/inventario/administracion',
      (json) => (json as List? ?? const <Object>[])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      queryParameters: <String, dynamic>{
        'sucursalId': sucursalId,
      },
    );

    final result = <int, String>{};
    for (final row in response.data ?? const <Map<String, dynamic>>[]) {
      final rawId = row['conteo_id'];
      final id = rawId is num
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '');
      if (id == null) continue;
      result[id] = (row['estado']?.toString() ?? '').trim().toUpperCase();
    }
    return result;
  }

  Map<int, InventarioResponseModel> _latestPhysicalCounts(
    List<InventarioResponseModel> records,
  ) {
    final result = <int, InventarioResponseModel>{};

    for (final record in records) {
      if (!(record.invtOrigen ?? '').startsWith('CONTEO_FISICO')) continue;
      final productId = record.prodId;
      final date = DateTime.tryParse(record.invtFecha ?? '');
      if (productId == null || date == null) continue;

      final current = result[productId];
      final currentDate = DateTime.tryParse(current?.invtFecha ?? '');
      if (current == null ||
          currentDate == null ||
          date.isAfter(currentDate) ||
          (date.isAtSameMomentAs(currentDate) &&
              (record.invtId ?? 0) > (current.invtId ?? 0))) {
        result[productId] = record;
      }
    }
    return result;
  }

  DateTime? _latestCountDate(
    Iterable<InventarioResponseModel> records,
  ) {
    DateTime? latest;
    for (final record in records) {
      final date = DateTime.tryParse(record.invtFecha ?? '');
      if (date == null) continue;
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    return latest;
  }

  Map<int, InventarioResponseModel> _latestRecordsToday(
    List<InventarioResponseModel> records,
  ) {
    final today = DateTime.now();
    final result = <int, InventarioResponseModel>{};

    for (final record in records) {
      if (!(record.invtOrigen ?? '').startsWith('CONTEO_FISICO')) continue;
      final productId = record.prodId;
      final date = DateTime.tryParse(record.invtFecha ?? '');
      if (productId == null || date == null || !_sameDay(today, date)) continue;

      final current = result[productId];
      final currentDate = DateTime.tryParse(current?.invtFecha ?? '');
      if (current == null ||
          currentDate == null ||
          date.isAfter(currentDate) ||
          (date.isAtSameMomentAs(currentDate) &&
              (record.invtId ?? 0) > (current.invtId ?? 0))) {
        result[productId] = record;
      }
    }
    return result;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  ProductosResponseModel _productWithInventory(
    ProductosResponseModel product,
    double inventory,
  ) {
    return ProductosResponseModel(
      prodId: product.prodId,
      sucuId: product.sucuId,
      tpprId: product.tpprId,
      mrcaId: product.mrcaId,
      prodNombre: product.prodNombre,
      prodDescripcion: product.prodDescripcion,
      prodFoto: product.prodFoto,
      prodFechaVencimiento: product.prodFechaVencimiento,
      prodCompraPorCantidad: product.prodCompraPorCantidad,
      prodCantidadCompra: product.prodCantidadCompra,
      prodPresentacionCompra: product.prodPresentacionCompra,
      inventarioActual: inventory,
      ventasAyer: product.ventasAyer,
      prodCreadoPor: product.prodCreadoPor,
      prodFechaCambio: product.prodFechaCambio,
    );
  }
}

final inventarioConteoProvider = StateNotifierProvider.autoDispose<
    InventarioConteoNotifier, InventarioConteoState>((ref) {
  final activeBranchId = ref.watch(
    branchScopeProvider.select((state) => state.activeBranchId),
  );
  return InventarioConteoNotifier(
    ref.watch(apiClientProvider),
    activeBranchId,
  );
});
