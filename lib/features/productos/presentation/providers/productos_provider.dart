import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/productos_response_model.dart';
import '../../data/datasources/productos_setup_remote_datasource.dart';

final productosSetupRemoteDataSourceProvider = Provider<ProductosSetupRemoteDataSource>(
  (ref) => ProductosSetupRemoteDataSource(ref.watch(apiClientProvider)),
);

final productosCrudRepositoryProvider = Provider<CrudRepository<ProductosResponseModel>>((ref) {
  return CrudRepository<ProductosResponseModel>(
    CrudRemoteDataSource<ProductosResponseModel>(ref.watch(apiClientProvider), productosConfig),
  );
});

final productosProvider = StateNotifierProvider<CrudNotifier<ProductosResponseModel>, CrudState<ProductosResponseModel>>((ref) {
  return CrudNotifier<ProductosResponseModel>(ref.watch(productosCrudRepositoryProvider))..load();
});

enum ProductosSortOption {
  nombreAsc,
  inventarioAsc,
  inventarioDesc,
  ventasAyerAsc,
  ventasAyerDesc;

  String get label => switch (this) {
        ProductosSortOption.nombreAsc => 'Nombre A-Z',
        ProductosSortOption.inventarioAsc => 'Menor inventario',
        ProductosSortOption.inventarioDesc => 'Mayor inventario',
        ProductosSortOption.ventasAyerAsc => 'Menor venta ayer',
        ProductosSortOption.ventasAyerDesc => 'Mayor venta ayer',
      };

  String get sortBy => switch (this) {
        ProductosSortOption.nombreAsc => 'nombre',
        ProductosSortOption.inventarioAsc => 'inventario',
        ProductosSortOption.inventarioDesc => 'inventario',
        ProductosSortOption.ventasAyerAsc => 'ventasAyer',
        ProductosSortOption.ventasAyerDesc => 'ventasAyer',
      };

  String get direction => switch (this) {
        ProductosSortOption.inventarioDesc => 'DESC',
        ProductosSortOption.ventasAyerDesc => 'DESC',
        _ => 'ASC',
      };
}


enum ProductosQuickFilter {
  all,
  lowStock,
  outOfStock,
  expiringSoon,
  soldYesterday;

  String get label => switch (this) {
        ProductosQuickFilter.all => 'Todos',
        ProductosQuickFilter.lowStock => 'Stock bajo',
        ProductosQuickFilter.outOfStock => 'Sin stock',
        ProductosQuickFilter.expiringSoon => 'Vence pronto',
        ProductosQuickFilter.soldYesterday => 'Salida ayer',
      };

  String? get queryValue => switch (this) {
        ProductosQuickFilter.all => null,
        ProductosQuickFilter.lowStock => 'LOW_STOCK',
        ProductosQuickFilter.outOfStock => 'OUT_OF_STOCK',
        ProductosQuickFilter.expiringSoon => 'EXPIRING_SOON',
        ProductosQuickFilter.soldYesterday => 'SOLD_YESTERDAY',
      };
}

enum ProductosPriceStatus {
  all,
  withPrice,
  withoutPrice;

  String? get queryValue => switch (this) {
        ProductosPriceStatus.all => null,
        ProductosPriceStatus.withPrice => 'WITH_PRICE',
        ProductosPriceStatus.withoutPrice => 'WITHOUT_PRICE',
      };
}

class ProductosPagedState {
  const ProductosPagedState({
    this.items = const [],
    this.loading = false,
    this.failure,
    this.page = 0,
    this.size = 20,
    this.totalElements = 0,
    this.totalPages = 0,
    this.first = true,
    this.last = true,
    this.query = '',
    this.tipoId,
    this.marcaId,
    this.sucursalId,
    this.sortOption = ProductosSortOption.nombreAsc,
    this.quickFilter = ProductosQuickFilter.all,
    this.priceStatus = ProductosPriceStatus.all,
  });

  final List<ProductosResponseModel> items;
  final bool loading;
  final Failure? failure;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
  final String query;
  final int? tipoId;
  final int? marcaId;
  final int? sucursalId;
  final ProductosSortOption sortOption;
  final ProductosQuickFilter quickFilter;
  final ProductosPriceStatus priceStatus;

  ProductosPagedState copyWith({
    List<ProductosResponseModel>? items,
    bool? loading,
    Failure? failure,
    int? page,
    int? size,
    int? totalElements,
    int? totalPages,
    bool? first,
    bool? last,
    String? query,
    int? tipoId,
    bool clearTipoId = false,
    int? marcaId,
    bool clearMarcaId = false,
    int? sucursalId,
    bool clearSucursalId = false,
    ProductosSortOption? sortOption,
    ProductosQuickFilter? quickFilter,
    ProductosPriceStatus? priceStatus,
  }) {
    return ProductosPagedState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      failure: failure,
      page: page ?? this.page,
      size: size ?? this.size,
      totalElements: totalElements ?? this.totalElements,
      totalPages: totalPages ?? this.totalPages,
      first: first ?? this.first,
      last: last ?? this.last,
      query: query ?? this.query,
      tipoId: clearTipoId ? null : (tipoId ?? this.tipoId),
      marcaId: clearMarcaId ? null : (marcaId ?? this.marcaId),
      sucursalId: clearSucursalId ? null : (sucursalId ?? this.sucursalId),
      sortOption: sortOption ?? this.sortOption,
      quickFilter: quickFilter ?? this.quickFilter,
      priceStatus: priceStatus ?? this.priceStatus,
    );
  }
}

class ProductosPagedNotifier extends StateNotifier<ProductosPagedState> {
  ProductosPagedNotifier(
    this._repository,
    this._apiClient, {
    bool autoLoad = true,
  }) : super(const ProductosPagedState()) {
    if (autoLoad) load();
  }

  final CrudRepository<ProductosResponseModel> _repository;
  final dynamic _apiClient;

  Future<void> load({
    int? page,
    int? size,
    String? query,
    int? tipoId,
    bool clearTipoId = false,
    int? marcaId,
    bool clearMarcaId = false,
    int? sucursalId,
    bool clearSucursalId = false,
    ProductosSortOption? sortOption,
    ProductosQuickFilter? quickFilter,
    ProductosPriceStatus? priceStatus,
  }) async {
    final nextState = state.copyWith(
      page: page,
      size: size,
      query: query,
      tipoId: tipoId,
      clearTipoId: clearTipoId,
      marcaId: marcaId,
      clearMarcaId: clearMarcaId,
      sucursalId: sucursalId,
      clearSucursalId: clearSucursalId,
      sortOption: sortOption,
      quickFilter: quickFilter,
      priceStatus: priceStatus,
    );
    state = nextState.copyWith(loading: true);

    try {
      final response = await _apiClient.get<ProductosPageResponseModel>(
        '/api/v1/productos/page',
        (json) => ProductosPageResponseModel.fromJson(Map<String, dynamic>.from(json as Map)),
        queryParameters: <String, dynamic>{
          'page': nextState.page,
          'size': nextState.size,
          'sortBy': nextState.sortOption.sortBy,
          'direction': nextState.sortOption.direction,
          if (nextState.query.trim().isNotEmpty) 'q': nextState.query.trim(),
          if (nextState.tipoId != null) 'tipoId': nextState.tipoId,
          if (nextState.marcaId != null) 'marcaId': nextState.marcaId,
          if (nextState.sucursalId != null) 'sucursalId': nextState.sucursalId,
          if (nextState.quickFilter.queryValue != null) 'quickFilter': nextState.quickFilter.queryValue,
          if (nextState.priceStatus.queryValue != null) 'priceStatus': nextState.priceStatus.queryValue,
        },
      );
      final pageData = response.data ?? const ProductosPageResponseModel();
      state = nextState.copyWith(
        items: pageData.content,
        loading: false,
        page: pageData.page,
        size: pageData.size,
        totalElements: pageData.totalElements,
        totalPages: pageData.totalPages,
        first: pageData.first,
        last: pageData.last,
      );
    } catch (error) {
      state = nextState.copyWith(loading: false, failure: ErrorMapper.map(error));
    }
  }

  Future<void> refresh() => load();

  Future<void> nextPage() async {
    if (state.last || state.loading) return;
    await load(page: state.page + 1);
  }

  Future<void> previousPage() async {
    if (state.first || state.loading) return;
    await load(page: state.page - 1);
  }

  Future<void> changeSize(int size) => load(page: 0, size: size);

  Future<bool> remove(Object id) async {
    state = state.copyWith(loading: true);
    try {
      await _repository.delete(id);
      final nextPage = state.items.length <= 1 && state.page > 0 ? state.page - 1 : state.page;
      await load(page: nextPage);
      return true;
    } catch (error) {
      state = state.copyWith(loading: false, failure: ErrorMapper.map(error));
      return false;
    }
  }
}

final productosPagedProvider = StateNotifierProvider<ProductosPagedNotifier, ProductosPagedState>((ref) {
  final repository = ref.watch(productosCrudRepositoryProvider);
  final apiClient = ref.watch(apiClientProvider);
  return ProductosPagedNotifier(repository, apiClient);
});
