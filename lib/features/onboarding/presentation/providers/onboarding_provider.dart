import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/onboarding_remote_datasource.dart';
import '../../data/models/onboarding_models.dart';

final onboardingRemoteDataSourceProvider = Provider<OnboardingRemoteDataSource>(
  (ref) => OnboardingRemoteDataSource(ref.watch(apiClientProvider)),
);

final onboardingCatalogsProvider = FutureProvider<PublicOnboardingCatalogsModel>(
  (ref) => ref.watch(onboardingRemoteDataSourceProvider).catalogs(),
);
