import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/medios_pago_response_model.dart';

final mediospagoCrudRepositoryProvider = Provider<CrudRepository<MediosPagoResponseModel>>((ref) {
  return CrudRepository<MediosPagoResponseModel>(
    CrudRemoteDataSource<MediosPagoResponseModel>(ref.watch(apiClientProvider), mediospagoConfig),
  );
});

final mediospagoProvider = StateNotifierProvider<CrudNotifier<MediosPagoResponseModel>, CrudState<MediosPagoResponseModel>>((ref) {
  return CrudNotifier<MediosPagoResponseModel>(ref.watch(mediospagoCrudRepositoryProvider))..load();
});
