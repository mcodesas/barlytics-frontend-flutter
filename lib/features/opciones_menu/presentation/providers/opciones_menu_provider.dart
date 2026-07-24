import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/opciones_menu_response_model.dart';

final opcionesmenuCrudRepositoryProvider = Provider<CrudRepository<OpcionesMenuResponseModel>>((ref) {
  return CrudRepository<OpcionesMenuResponseModel>(
    CrudRemoteDataSource<OpcionesMenuResponseModel>(ref.watch(apiClientProvider), opcionesmenuConfig),
  );
});

final opcionesmenuProvider = StateNotifierProvider<CrudNotifier<OpcionesMenuResponseModel>, CrudState<OpcionesMenuResponseModel>>((ref) {
  return CrudNotifier<OpcionesMenuResponseModel>(ref.watch(opcionesmenuCrudRepositoryProvider))..load();
});
