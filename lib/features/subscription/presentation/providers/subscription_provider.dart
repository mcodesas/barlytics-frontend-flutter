import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/subscription_remote_datasource.dart';
import '../../data/models/subscription_models.dart';

final subscriptionRemoteDataSourceProvider = Provider<SubscriptionRemoteDataSource>(
  (ref) => SubscriptionRemoteDataSource(ref.watch(apiClientProvider)),
);

final planCapabilitiesProvider = FutureProvider<PlanCapabilitiesModel>((ref) {
  return ref.watch(subscriptionRemoteDataSourceProvider).capabilities();
});

final subscriptionCurrentProvider = FutureProvider.autoDispose<SubscriptionModel>((ref) {
  return ref.watch(subscriptionRemoteDataSourceProvider).current();
});
