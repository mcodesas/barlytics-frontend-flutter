import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/subscription_remote_datasource.dart';

final subscriptionRemoteDataSourceProvider = Provider<SubscriptionRemoteDataSource>(
  (ref) => SubscriptionRemoteDataSource(ref.watch(apiClientProvider)),
);
