import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Los roles personalizados mantienen su nombre e ID real de PostgreSQL.
/// Nunca se usan estos nombres para convertirlos en autoridades JWT.
class UserAssignedRole {
  const UserAssignedRole({
    required this.roleId,
    required this.name,
    required this.type,
  });

  final int roleId;
  final String name;
  final String type;

  bool get isCustom => type.trim().toUpperCase() == 'PERSONALIZADO';
  String get selectionKey => isCustom
      ? customRoleSelectionKey(roleId)
      : systemRoleSelectionKey(roleId);

  factory UserAssignedRole.fromJson(Map<String, dynamic> json) {
    final rawId = json['roleId'];
    return UserAssignedRole(
      roleId: rawId is num ? rawId.toInt() : int.parse(rawId.toString()),
      name: json['roleNombre']?.toString().trim() ?? '',
      type: json['roleTipo']?.toString() ?? 'PREDEFINIDO',
    );
  }
}

const systemRoleSelectionPrefix = 'SYSTEM_ROLE_ID:';
String systemRoleSelectionKey(int id) => '$systemRoleSelectionPrefix$id';

int? systemRoleIdFromSelection(String value) {
  if (!value.startsWith(systemRoleSelectionPrefix)) return null;
  return int.tryParse(value.substring(systemRoleSelectionPrefix.length));
}

const customRoleSelectionPrefix = 'CUSTOM_ROLE_ID:';
String customRoleSelectionKey(int id) => '$customRoleSelectionPrefix$id';

int? customRoleIdFromSelection(String value) {
  if (!value.startsWith(customRoleSelectionPrefix)) return null;
  return int.tryParse(value.substring(customRoleSelectionPrefix.length));
}

final userAssignedRolesProvider = FutureProvider<List<UserAssignedRole>>((ref) async {
  if (!ref.watch(authControllerProvider).authenticated) return const [];
  final response = await ref.watch(apiClientProvider).get<List<UserAssignedRole>>(
    '/api/v1/me/roles/visibles',
    (json) => (json as List? ?? const <Object?>[])
        .whereType<Map>()
        .map((item) => UserAssignedRole.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );
  return response.data ?? const [];
});
