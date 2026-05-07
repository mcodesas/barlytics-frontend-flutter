import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/parametros_response_model.dart';

final parametrosCrudRepositoryProvider = Provider<CrudRepository<ParametrosResponseModel>>((ref) {
  return CrudRepository<ParametrosResponseModel>(
    CrudRemoteDataSource<ParametrosResponseModel>(ref.watch(apiClientProvider), parametrosConfig),
  );
});

final parametrosProvider = StateNotifierProvider<CrudNotifier<ParametrosResponseModel>, CrudState<ParametrosResponseModel>>((ref) {
  return CrudNotifier<ParametrosResponseModel>(ref.watch(parametrosCrudRepositoryProvider))..load();
});
