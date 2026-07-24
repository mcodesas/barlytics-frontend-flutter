import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/precios_response_model.dart';

final preciosCrudRepositoryProvider = Provider<CrudRepository<PreciosResponseModel>>((ref) {
  return CrudRepository<PreciosResponseModel>(
    CrudRemoteDataSource<PreciosResponseModel>(ref.watch(apiClientProvider), preciosConfig),
  );
});

final preciosProvider = StateNotifierProvider<CrudNotifier<PreciosResponseModel>, CrudState<PreciosResponseModel>>((ref) {
  return CrudNotifier<PreciosResponseModel>(ref.watch(preciosCrudRepositoryProvider))..load();
});
