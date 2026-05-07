import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/productos_response_model.dart';

final productosCrudRepositoryProvider = Provider<CrudRepository<ProductosResponseModel>>((ref) {
  return CrudRepository<ProductosResponseModel>(
    CrudRemoteDataSource<ProductosResponseModel>(ref.watch(apiClientProvider), productosConfig),
  );
});

final productosProvider = StateNotifierProvider<CrudNotifier<ProductosResponseModel>, CrudState<ProductosResponseModel>>((ref) {
  return CrudNotifier<ProductosResponseModel>(ref.watch(productosCrudRepositoryProvider))..load();
});
