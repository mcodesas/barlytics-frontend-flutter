import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/zonas_horarias_response_model.dart';

final zonashorariasCrudRepositoryProvider = Provider<CrudRepository<ZonasHorariasResponseModel>>((ref) {
  return CrudRepository<ZonasHorariasResponseModel>(
    CrudRemoteDataSource<ZonasHorariasResponseModel>(ref.watch(apiClientProvider), zonashorariasConfig),
  );
});

final zonashorariasProvider = StateNotifierProvider<CrudNotifier<ZonasHorariasResponseModel>, CrudState<ZonasHorariasResponseModel>>((ref) {
  return CrudNotifier<ZonasHorariasResponseModel>(ref.watch(zonashorariasCrudRepositoryProvider))..load();
});
