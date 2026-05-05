import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/sucursales_response_model.dart';

final sucursalesCrudRepositoryProvider = Provider<CrudRepository<SucursalesResponseModel>>((ref) {
  return CrudRepository<SucursalesResponseModel>(
    CrudRemoteDataSource<SucursalesResponseModel>(ref.watch(apiClientProvider), sucursalesConfig),
  );
});

final sucursalesProvider = StateNotifierProvider<CrudNotifier<SucursalesResponseModel>, CrudState<SucursalesResponseModel>>((ref) {
  return CrudNotifier<SucursalesResponseModel>(ref.watch(sucursalesCrudRepositoryProvider))..load();
});
