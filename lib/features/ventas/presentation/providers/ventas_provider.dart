import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/ventas_response_model.dart';

final ventasCrudRepositoryProvider = Provider<CrudRepository<VentasResponseModel>>((ref) {
  return CrudRepository<VentasResponseModel>(
    CrudRemoteDataSource<VentasResponseModel>(ref.watch(apiClientProvider), ventasConfig),
  );
});

final ventasProvider = StateNotifierProvider<CrudNotifier<VentasResponseModel>, CrudState<VentasResponseModel>>((ref) {
  return CrudNotifier<VentasResponseModel>(ref.watch(ventasCrudRepositoryProvider))..load();
});
