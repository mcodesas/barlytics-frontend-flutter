import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/cuentas_venta_response_model.dart';

final cuentasventaCrudRepositoryProvider = Provider<CrudRepository<CuentasVentaResponseModel>>((ref) {
  return CrudRepository<CuentasVentaResponseModel>(
    CrudRemoteDataSource<CuentasVentaResponseModel>(ref.watch(apiClientProvider), cuentasventaConfig),
  );
});

final cuentasventaProvider = StateNotifierProvider<CrudNotifier<CuentasVentaResponseModel>, CrudState<CuentasVentaResponseModel>>((ref) {
  return CrudNotifier<CuentasVentaResponseModel>(ref.watch(cuentasventaCrudRepositoryProvider))..load();
});
