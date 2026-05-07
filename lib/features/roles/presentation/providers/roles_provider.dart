import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/roles_response_model.dart';

final rolesCrudRepositoryProvider = Provider<CrudRepository<RolesResponseModel>>((ref) {
  return CrudRepository<RolesResponseModel>(
    CrudRemoteDataSource<RolesResponseModel>(ref.watch(apiClientProvider), rolesConfig),
  );
});

final rolesProvider = StateNotifierProvider<CrudNotifier<RolesResponseModel>, CrudState<RolesResponseModel>>((ref) {
  return CrudNotifier<RolesResponseModel>(ref.watch(rolesCrudRepositoryProvider))..load();
});
