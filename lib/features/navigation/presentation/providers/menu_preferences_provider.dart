import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/user_menu_item.dart';

const _endpoint = '/api/v1/me/menu-preferencias';

class MenuPreferenceEntry {
  const MenuPreferenceEntry({
    required this.menuId, required this.order, required this.favorite,
  });
  final int menuId;
  final int order;
  final bool favorite;

  Map<String, Object> toJson() =>
      {'menuId': menuId, 'orden': order, 'favorito': favorite};
}

class MenuPreferences {
  const MenuPreferences({
    this.visibility = 'AMBOS',
    this.entries = const <int, MenuPreferenceEntry>{},
  });
  final String visibility;
  final Map<int, MenuPreferenceEntry> entries;
  bool get showInMenu => visibility != 'INICIO';
  bool get showOnHome => visibility != 'MENU';

  factory MenuPreferences.fromJson(Object? value) {
    if (value is! Map) return const MenuPreferences();
    final data = Map<String, dynamic>.from(value);
    final entries = <int, MenuPreferenceEntry>{};
    for (final raw in data['items'] as List? ?? const []) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final id = int.tryParse('${item['menuId'] ?? ''}');
      final order = int.tryParse('${item['orden'] ?? ''}');
      if (id == null || order == null) continue;
      entries[id] = MenuPreferenceEntry(
        menuId: id, order: order, favorite: item['favorito'] == true);
    }
    final rawVisibility = (data['mostrarFavoritos'] ?? 'AMBOS').toString();
    return MenuPreferences(
      visibility: const {'MENU', 'INICIO', 'AMBOS'}.contains(rawVisibility)
          ? rawVisibility : 'AMBOS',
      entries: entries,
    );
  }
}

/// Fusiona preferencias SOLO con módulos autorizados por userMenuProvider.
/// Ni el endpoint ni las preferencias inventan rutas o permisos nuevos.
List<UserMenuItem> personalizeAuthorizedMenu(
    List<UserMenuItem> authorized, MenuPreferences preferences) {
  final result = authorized.map((item) {
    final pref = item.menuId == null ? null : preferences.entries[item.menuId];
    return item.copyWith(
      personalOrder: pref?.order,
      isFavorite: pref?.favorite ?? false,
    );
  }).toList();
  if (preferences.entries.isEmpty) return result;
  // List.sort no garantiza estabilidad: conservar el orden original en los
  // módulos nuevos y no personalizados, especialmente en roles propios.
  final originalIndex = <UserMenuItem, int>{
    for (var i = 0; i < result.length; i++) result[i]: i,
  };
  result.sort((a, b) {
    final orderA = a.personalOrder;
    final orderB = b.personalOrder;
    if (orderA == null && orderB == null) {
      return originalIndex[a]!.compareTo(originalIndex[b]!);
    }
    if (orderA == null) return 1;
    if (orderB == null) return -1;
    final order = orderA.compareTo(orderB);
    return order != 0 ? order
        : originalIndex[a]!.compareTo(originalIndex[b]!);
  });
  return result;
}

final menuPreferencesRepositoryProvider = Provider<MenuPreferencesRepository>((ref) {
  return MenuPreferencesRepository(ref.watch(apiClientProvider));
});

class MenuPreferencesRepository {
  const MenuPreferencesRepository(this._api);
  final ApiClient _api;

  Future<MenuPreferences> load() async {
    final response = await _api.get<MenuPreferences>(
      _endpoint, (json) => MenuPreferences.fromJson(json));
    return response.data ?? const MenuPreferences();
  }

  Future<MenuPreferences> save(
      List<MenuPreferenceEntry> entries, String visibility) async {
    final response = await _api.put<MenuPreferences>(
      _endpoint, {
        'mostrarFavoritos': visibility,
        'items': entries.map((entry) => entry.toJson()).toList(),
      }, (json) => MenuPreferences.fromJson(json));
    return response.data ?? const MenuPreferences();
  }

  Future<MenuPreferences> reset() async {
    final response = await _api.delete<MenuPreferences>(
      _endpoint, (json) => MenuPreferences.fromJson(json));
    return response.data ?? const MenuPreferences();
  }
}

final menuPreferencesProvider = FutureProvider<MenuPreferences>((ref) async {
  if (!ref.watch(authControllerProvider).authenticated) {
    return const MenuPreferences();
  }
  return ref.watch(menuPreferencesRepositoryProvider).load();
});
