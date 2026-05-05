import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/detalle_cuenta_venta_response_model.dart';

final detallecuentaventaCrudRepositoryProvider = Provider<CrudRepository<DetalleCuentaVentaResponseModel>>((ref) {
  return CrudRepository<DetalleCuentaVentaResponseModel>(
    CrudRemoteDataSource<DetalleCuentaVentaResponseModel>(ref.watch(apiClientProvider), detallecuentaventaConfig),
  );
});

final detallecuentaventaProvider = StateNotifierProvider<CrudNotifier<DetalleCuentaVentaResponseModel>, CrudState<DetalleCuentaVentaResponseModel>>((ref) {
  return CrudNotifier<DetalleCuentaVentaResponseModel>(ref.watch(detallecuentaventaCrudRepositoryProvider))..load();
});
