import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/tipos_producto_response_model.dart';

final tiposproductoCrudRepositoryProvider = Provider<CrudRepository<TiposProductoResponseModel>>((ref) {
  return CrudRepository<TiposProductoResponseModel>(
    CrudRemoteDataSource<TiposProductoResponseModel>(ref.watch(apiClientProvider), tiposproductoConfig),
  );
});

final tiposproductoProvider = StateNotifierProvider<CrudNotifier<TiposProductoResponseModel>, CrudState<TiposProductoResponseModel>>((ref) {
  return CrudNotifier<TiposProductoResponseModel>(ref.watch(tiposproductoCrudRepositoryProvider))..load();
});
