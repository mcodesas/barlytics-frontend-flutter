import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pestañas operativas del flujo de mesas.
///
/// Se maneja en un provider para evitar que la barra inferior navegue entre
/// rutas distintas y provoque recargas completas de mesas/productos/resumen.
enum MeseroPageMode { mesas, productos, resumen, historial, cierreCaja }

final meseroSelectedModeProvider = StateProvider<MeseroPageMode>((ref) => MeseroPageMode.mesas);


/// Convierte un destino explícito del menú en la vista de Mesero que debe
/// mostrarse. El provider puede conservar Cierre de caja o Historial de una
/// navegación anterior, aunque la URL ya haya cambiado a /mesero.
MeseroPageMode? meseroModeForMenuPath(String path) => switch (path) {
      '/mesero' || '/administrar_mesas' => MeseroPageMode.mesas,
      '/mesero/productos' => MeseroPageMode.productos,
      '/mesero/resumen' => MeseroPageMode.resumen,
      '/mesero/historial' || '/historial_ventas' => MeseroPageMode.historial,
      '/mesero/cierre-caja' || '/cierre_caja' => MeseroPageMode.cierreCaja,
      _ => null,
    };

/// Sincroniza las pestañas antes de cambiar de ruta desde cualquier menú.
/// También funciona si el destino es la misma URL actual (/mesero).
void selectMeseroModeForMenuPath(WidgetRef ref, String path) {
  final mode = meseroModeForMenuPath(path);
  if (mode == null) return;
  ref.read(meseroSelectedModeProvider.notifier).state = mode;
}
