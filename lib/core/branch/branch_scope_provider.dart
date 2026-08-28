import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sucursales/data/models/sucursales_response_model.dart';
import '../constants/storage_keys.dart';
import '../errors/error_mapper.dart';
import '../errors/failure.dart';
import '../providers/core_providers.dart';

class BranchScopeState {
  const BranchScopeState({
    this.branches = const <SucursalesResponseModel>[],
    this.activeBranchId,
    this.loading = false,
    this.failure,
  });

  final List<SucursalesResponseModel> branches;
  final int? activeBranchId;
  final bool loading;
  final Failure? failure;

  SucursalesResponseModel? get activeBranch {
    for (final branch in branches) {
      if (branch.sucuId == activeBranchId) return branch;
    }
    return null;
  }

  BranchScopeState copyWith({
    List<SucursalesResponseModel>? branches,
    int? activeBranchId,
    bool clearActiveBranch = false,
    bool? loading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return BranchScopeState(
      branches: branches ?? this.branches,
      activeBranchId: clearActiveBranch ? null : (activeBranchId ?? this.activeBranchId),
      loading: loading ?? this.loading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class BranchScopeNotifier extends StateNotifier<BranchScopeState> {
  BranchScopeNotifier(this._ref) : super(const BranchScopeState()) {
    load();
  }

  final Ref _ref;

  Future<void> load() async {
    if (!mounted) return;

    final apiClient = _ref.read(apiClientProvider);
    final secureStorage = _ref.read(secureStorageProvider);

    state = state.copyWith(loading: true, clearFailure: true);
    try {
      final response = await apiClient.get<List<SucursalesResponseModel>>(
        '/api/v1/sucursales/mis-sucursales',
        (json) => (json as List? ?? const <dynamic>[])
            .map((item) => SucursalesResponseModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false),
      );
      if (!mounted) return;

      final branches = (response.data ?? const <SucursalesResponseModel>[])
          .where((branch) => branch.sucuId != null && branch.sucuEstado != 0)
          .toList(growable: false)
        ..sort((a, b) => (a.sucuNombre ?? '').compareTo(b.sucuNombre ?? ''));

      final storedRaw = await secureStorage.read(StorageKeys.sucursalId);
      if (!mounted) return;

      final storedId = int.tryParse(storedRaw ?? '');
      final storedAllowed = branches.any((branch) => branch.sucuId == storedId);
      final activeId = storedAllowed ? storedId : (branches.isEmpty ? null : branches.first.sucuId);

      if (activeId != null) {
        await secureStorage.write(StorageKeys.sucursalId, '$activeId');
        if (!mounted) return;
      }

      state = BranchScopeState(
        branches: branches,
        activeBranchId: activeId,
        loading: false,
      );
    } catch (error) {
      // Una operación asíncrona puede terminar después de que el provider
      // haya sido destruido (por navegación, logout o hot restart).
      // En ese caso no debemos leer ni escribir `state`.
      if (!mounted) return;

      state = state.copyWith(
        loading: false,
        failure: ErrorMapper.map(error),
      );
    }
  }

  Future<void> select(int branchId) async {
    if (!mounted) return;

    final currentState = state;
    if (!currentState.branches.any((branch) => branch.sucuId == branchId)) return;
    if (currentState.activeBranchId == branchId) return;

    final secureStorage = _ref.read(secureStorageProvider);
    await secureStorage.write(StorageKeys.sucursalId, '$branchId');
    if (!mounted) return;

    state = state.copyWith(activeBranchId: branchId, clearFailure: true);
  }
}

final branchScopeProvider = StateNotifierProvider<BranchScopeNotifier, BranchScopeState>((ref) {
  return BranchScopeNotifier(ref);
});
