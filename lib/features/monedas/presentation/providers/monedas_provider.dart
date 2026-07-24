import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/monedas_response_model.dart';

final monedasCrudRepositoryProvider = Provider<CrudRepository<MonedasResponseModel>>((ref) {
  return CrudRepository<MonedasResponseModel>(
    CrudRemoteDataSource<MonedasResponseModel>(ref.watch(apiClientProvider), monedasConfig),
  );
});

final monedasProvider = StateNotifierProvider<CrudNotifier<MonedasResponseModel>, CrudState<MonedasResponseModel>>((ref) {
  return CrudNotifier<MonedasResponseModel>(ref.watch(monedasCrudRepositoryProvider))..load();
});
