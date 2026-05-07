import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/movimientos_response_model.dart';

final movimientosCrudRepositoryProvider = Provider<CrudRepository<MovimientosResponseModel>>((ref) {
  return CrudRepository<MovimientosResponseModel>(
    CrudRemoteDataSource<MovimientosResponseModel>(ref.watch(apiClientProvider), movimientosConfig),
  );
});

final movimientosProvider = StateNotifierProvider<CrudNotifier<MovimientosResponseModel>, CrudState<MovimientosResponseModel>>((ref) {
  return CrudNotifier<MovimientosResponseModel>(ref.watch(movimientosCrudRepositoryProvider))..load();
});
