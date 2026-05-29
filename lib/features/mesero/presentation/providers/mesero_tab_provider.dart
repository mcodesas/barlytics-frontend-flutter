import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pestañas operativas del flujo de mesas.
///
/// Se maneja en un provider para evitar que la barra inferior navegue entre
/// rutas distintas y provoque recargas completas de mesas/productos/resumen.
enum MeseroPageMode { mesas, productos, resumen, historial, cierreCaja }

final meseroSelectedModeProvider = StateProvider<MeseroPageMode>((ref) => MeseroPageMode.mesas);
