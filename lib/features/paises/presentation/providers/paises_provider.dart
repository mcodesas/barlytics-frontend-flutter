import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/paises_response_model.dart';

final paisesCrudRepositoryProvider = Provider<CrudRepository<PaisesResponseModel>>((ref) {
  return CrudRepository<PaisesResponseModel>(
    CrudRemoteDataSource<PaisesResponseModel>(ref.watch(apiClientProvider), paisesConfig),
  );
});

final paisesProvider = StateNotifierProvider<CrudNotifier<PaisesResponseModel>, CrudState<PaisesResponseModel>>((ref) {
  return CrudNotifier<PaisesResponseModel>(ref.watch(paisesCrudRepositoryProvider))..load();
});
