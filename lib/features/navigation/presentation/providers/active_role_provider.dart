import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import 'user_assigned_roles_provider.dart';

/// null = Todos los roles. Un Set no vacío = solo esos roles activos en la UI.
final selectedRolesProvider = StateProvider<Set<String>?>((ref) => null);

String normalizeRoleName(String value) => value
    .toUpperCase()
    .trim()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceFirst(RegExp(r'^ROLE_'), '')
    .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

final activeRolesProvider = Provider<List<String>>((ref) {
  final assigned = ref.watch(authControllerProvider).roles;
  final selected = ref.watch(selectedRolesProvider);
  if (selected == null || assigned.length <= 1) return assigned;
  final selectedNormalized = selected.map(normalizeRoleName).toSet();
  final customSelected = selected.any((key) => customRoleIdFromSelection(key) != null);
  final filtered = assigned
      .where((role) => selectedNormalized.contains(normalizeRoleName(role)) ||
          (customSelected && normalizeRoleName(role) == 'PERSONALIZADO'))
      .toList(growable: false);
  return filtered.isEmpty ? assigned : filtered;
});

bool roleMatches(String role, Iterable<String> selected) {
  final normalized = normalizeRoleName(role);
  return selected.any((value) => normalizeRoleName(value) == normalized);
}
