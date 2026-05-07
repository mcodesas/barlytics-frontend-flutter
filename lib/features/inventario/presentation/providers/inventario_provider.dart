import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/inventario_response_model.dart';

final inventarioCrudRepositoryProvider = Provider<CrudRepository<InventarioResponseModel>>((ref) {
  return CrudRepository<InventarioResponseModel>(
    CrudRemoteDataSource<InventarioResponseModel>(ref.watch(apiClientProvider), inventarioConfig),
  );
});

final inventarioProvider = StateNotifierProvider<CrudNotifier<InventarioResponseModel>, CrudState<InventarioResponseModel>>((ref) {
  return CrudNotifier<InventarioResponseModel>(ref.watch(inventarioCrudRepositoryProvider))..load();
});
