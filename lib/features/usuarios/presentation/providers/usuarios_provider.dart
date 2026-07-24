import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/usuarios_response_model.dart';

final usuariosCrudRepositoryProvider = Provider<CrudRepository<UsuariosResponseModel>>((ref) {
  return CrudRepository<UsuariosResponseModel>(
    CrudRemoteDataSource<UsuariosResponseModel>(ref.watch(apiClientProvider), usuariosConfig),
  );
});

final usuariosProvider = StateNotifierProvider<CrudNotifier<UsuariosResponseModel>, CrudState<UsuariosResponseModel>>((ref) {
  return CrudNotifier<UsuariosResponseModel>(ref.watch(usuariosCrudRepositoryProvider))..load();
});
