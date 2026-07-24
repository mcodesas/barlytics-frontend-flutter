import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/menus_response_model.dart';

final menusCrudRepositoryProvider = Provider<CrudRepository<MenusResponseModel>>((ref) {
  return CrudRepository<MenusResponseModel>(
    CrudRemoteDataSource<MenusResponseModel>(ref.watch(apiClientProvider), menusConfig),
  );
});

final menusProvider = StateNotifierProvider<CrudNotifier<MenusResponseModel>, CrudState<MenusResponseModel>>((ref) {
  return CrudNotifier<MenusResponseModel>(ref.watch(menusCrudRepositoryProvider))..load();
});
