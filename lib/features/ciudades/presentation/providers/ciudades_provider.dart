import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/ciudades_response_model.dart';

final ciudadesCrudRepositoryProvider = Provider<CrudRepository<CiudadesResponseModel>>((ref) {
  return CrudRepository<CiudadesResponseModel>(
    CrudRemoteDataSource<CiudadesResponseModel>(ref.watch(apiClientProvider), ciudadesConfig),
  );
});

final ciudadesProvider = StateNotifierProvider<CrudNotifier<CiudadesResponseModel>, CrudState<CiudadesResponseModel>>((ref) {
  return CrudNotifier<CiudadesResponseModel>(ref.watch(ciudadesCrudRepositoryProvider))..load();
});
