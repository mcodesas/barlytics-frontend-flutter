import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/regiones_response_model.dart';

final regionesCrudRepositoryProvider = Provider<CrudRepository<RegionesResponseModel>>((ref) {
  return CrudRepository<RegionesResponseModel>(
    CrudRemoteDataSource<RegionesResponseModel>(ref.watch(apiClientProvider), regionesConfig),
  );
});

final regionesProvider = StateNotifierProvider<CrudNotifier<RegionesResponseModel>, CrudState<RegionesResponseModel>>((ref) {
  return CrudNotifier<RegionesResponseModel>(ref.watch(regionesCrudRepositoryProvider))..load();
});
