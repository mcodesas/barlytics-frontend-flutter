import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/empresas_response_model.dart';

final empresasCrudRepositoryProvider = Provider<CrudRepository<EmpresasResponseModel>>((ref) {
  return CrudRepository<EmpresasResponseModel>(
    CrudRemoteDataSource<EmpresasResponseModel>(ref.watch(apiClientProvider), empresasConfig),
  );
});

final empresasProvider = StateNotifierProvider<CrudNotifier<EmpresasResponseModel>, CrudState<EmpresasResponseModel>>((ref) {
  return CrudNotifier<EmpresasResponseModel>(ref.watch(empresasCrudRepositoryProvider))..load();
});
