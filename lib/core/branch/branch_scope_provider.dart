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
    state = state.copyWith(loading: true, clearFailure: true);
    try {
      final response = await _ref.read(apiClientProvider).get<List<SucursalesResponseModel>>(
            '/api/v1/sucursales/mis-sucursales',
            (json) => (json as List? ?? const <dynamic>[])
                .map((item) => SucursalesResponseModel.fromJson(
                      Map<String, dynamic>.from(item as Map),
                    ))
                .toList(growable: false),
          );
      final branches = (response.data ?? const <SucursalesResponseModel>[])
          .where((branch) => branch.sucuId != null && branch.sucuEstado != 0)
          .toList(growable: false)
        ..sort((a, b) => (a.sucuNombre ?? '').compareTo(b.sucuNombre ?? ''));

      final storedRaw = await _ref.read(secureStorageProvider).read(StorageKeys.sucursalId);
      final storedId = int.tryParse(storedRaw ?? '');
      final storedAllowed = branches.any((branch) => branch.sucuId == storedId);
      final activeId = storedAllowed ? storedId : (branches.isEmpty ? null : branches.first.sucuId);

      if (activeId != null) {
        await _ref.read(secureStorageProvider).write(StorageKeys.sucursalId, '$activeId');
      }

      state = BranchScopeState(
        branches: branches,
        activeBranchId: activeId,
        loading: false,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        failure: ErrorMapper.map(error),
      );
    }
  }

  Future<void> select(int branchId) async {
    if (!state.branches.any((branch) => branch.sucuId == branchId)) return;
    if (state.activeBranchId == branchId) return;
    await _ref.read(secureStorageProvider).write(StorageKeys.sucursalId, '$branchId');
    state = state.copyWith(activeBranchId: branchId, clearFailure: true);
  }
}

final branchScopeProvider = StateNotifierProvider<BranchScopeNotifier, BranchScopeState>((ref) {
  return BranchScopeNotifier(ref);
});
