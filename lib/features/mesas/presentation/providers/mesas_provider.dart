import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/mesas_response_model.dart';

final mesasCrudRepositoryProvider = Provider<CrudRepository<MesasResponseModel>>((ref) {
  return CrudRepository<MesasResponseModel>(
    CrudRemoteDataSource<MesasResponseModel>(ref.watch(apiClientProvider), mesasConfig),
  );
});

final mesasProvider = StateNotifierProvider<CrudNotifier<MesasResponseModel>, CrudState<MesasResponseModel>>((ref) {
  return CrudNotifier<MesasResponseModel>(ref.watch(mesasCrudRepositoryProvider))..load();
});
