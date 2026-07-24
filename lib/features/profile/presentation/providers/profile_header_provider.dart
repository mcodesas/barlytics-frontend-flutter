import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/providers/core_providers.dart';

class ProfileHeaderInfo {
  const ProfileHeaderInfo({
    this.photo,
    this.displayName,
    this.email,
  });

  final String? photo;
  final String? displayName;
  final String? email;

  String get initials {
    final words = (displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'.toUpperCase();
  }
}

final profileHeaderProvider = FutureProvider.autoDispose<ProfileHeaderInfo>((ref) async {
  final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
        ApiPaths.profile,
        (json) => Map<String, dynamic>.from(json as Map),
      );
  final data = response.data ?? const <String, dynamic>{};

  final firstName = data['primerNombre']?.toString().trim() ?? '';
  final secondName = data['segundoNombre']?.toString().trim() ?? '';
  final firstLastName = data['primerApellido']?.toString().trim() ?? '';
  final displayName = [firstName, secondName, firstLastName]
      .where((part) => part.isNotEmpty)
      .join(' ')
      .trim();
  final photo = (data['foto'] ?? data['usuaFoto'])?.toString().trim();
  final email = data['email']?.toString().trim();

  return ProfileHeaderInfo(
    photo: photo == null || photo.isEmpty ? null : photo,
    displayName: displayName.isEmpty ? null : displayName,
    email: email == null || email.isEmpty ? null : email,
  );
});
