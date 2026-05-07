import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/pagos_response_model.dart';

final pagosCrudRepositoryProvider = Provider<CrudRepository<PagosResponseModel>>((ref) {
  return CrudRepository<PagosResponseModel>(
    CrudRemoteDataSource<PagosResponseModel>(ref.watch(apiClientProvider), pagosConfig),
  );
});

final pagosProvider = StateNotifierProvider<CrudNotifier<PagosResponseModel>, CrudState<PagosResponseModel>>((ref) {
  return CrudNotifier<PagosResponseModel>(ref.watch(pagosCrudRepositoryProvider))..load();
});
