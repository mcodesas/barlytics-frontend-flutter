import '../data/models/user_menu_item.dart';

/// Inicio es un acceso fijo del shell, no una opción que pueda duplicarse
/// desde los menús devueltos por la base de datos.
bool isStructuralHomeItem(UserMenuItem item) {
  final key = item.keyName.trim().toLowerCase();
  return item.path.trim() == '/home' ||
      key == 'home' ||
      key == 'inicio';
}

/// El grupo principal INICIO tampoco puede ocupar uno de los tres espacios
/// que la navegación del gerente reserva para Comandas, Ventas, etc.
bool isStructuralHomeBottomEntry(UserMenuItem item) =>
    isStructuralHomeItem(item) ||
    item.bottomCode.trim().toUpperCase() == 'INICIO';

List<UserMenuItem> managerBottomCandidates(List<UserMenuItem> items) =>
    items.where((item) =>
        item.path.trim().isNotEmpty &&
        !isStructuralHomeBottomEntry(item)).toList(growable: false);

List<UserMenuItem> managerMoreCandidates(List<UserMenuItem> items) =>
    items.where((item) => !isStructuralHomeItem(item))
        .toList(growable: false);
