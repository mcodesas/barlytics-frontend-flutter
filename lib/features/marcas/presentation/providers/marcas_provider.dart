import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/marcas_response_model.dart';

final marcasCrudRepositoryProvider = Provider<CrudRepository<MarcasResponseModel>>((ref) {
  return CrudRepository<MarcasResponseModel>(
    CrudRemoteDataSource<MarcasResponseModel>(ref.watch(apiClientProvider), marcasConfig),
  );
});

final marcasProvider = StateNotifierProvider<CrudNotifier<MarcasResponseModel>, CrudState<MarcasResponseModel>>((ref) {
  return CrudNotifier<MarcasResponseModel>(ref.watch(marcasCrudRepositoryProvider))..load();
});
