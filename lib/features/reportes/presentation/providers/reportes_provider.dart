import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/crud/crud_notifier.dart';
import '../../../../core/crud/crud_remote_datasource.dart';
import '../../../../core/crud/crud_repository.dart';
import '../../../../core/crud/crud_state.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/models/reportes_response_model.dart';

final reportesCrudRepositoryProvider = Provider<CrudRepository<ReportesResponseModel>>((ref) {
  return CrudRepository<ReportesResponseModel>(
    CrudRemoteDataSource<ReportesResponseModel>(ref.watch(apiClientProvider), reportesConfig),
  );
});

final reportesProvider = StateNotifierProvider<CrudNotifier<ReportesResponseModel>, CrudState<ReportesResponseModel>>((ref) {
  return CrudNotifier<ReportesResponseModel>(ref.watch(reportesCrudRepositoryProvider))..load();
});
