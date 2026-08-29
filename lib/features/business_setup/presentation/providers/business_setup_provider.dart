import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/business_setup_remote_datasource.dart';
import '../../data/models/business_setup_models.dart';

final businessSetupRemoteDataSourceProvider = Provider<BusinessSetupRemoteDataSource>(
  (ref) => BusinessSetupRemoteDataSource(ref.watch(apiClientProvider)),
);

final businessSetupStatusProvider = FutureProvider<BusinessSetupStatusModel>(
  (ref) => ref.watch(businessSetupRemoteDataSourceProvider).status(),
);


/// Mantiene el modo visual guiado mientras el usuario entra a pantallas de
/// parametrización desde la ayuda / puesta en marcha. A diferencia de basarse
/// solo en `businessSetupComplete`, este estado permite volver a editar pasos ya
/// completados sin que reaparezcan los menús operativos normales.
final businessSetupGuidedModeProvider = StateProvider<bool>((ref) => false);
