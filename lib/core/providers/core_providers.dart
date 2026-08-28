import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/dio_client.dart';
import '../network/session_expiration_notifier.dart';
import '../storage/secure_storage_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) => SecureStorageService());

final sessionExpirationNotifierProvider = Provider<SessionExpirationNotifier>((ref) {
  final notifier = SessionExpirationNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final sessionExpirationNotifier = ref.watch(sessionExpirationNotifierProvider);
  return DioClient.create(storage, sessionExpirationNotifier);
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));
