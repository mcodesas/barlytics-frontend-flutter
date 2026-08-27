import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Representa la apariencia visual de un módulo funcional.
class ModuleVisual {
  const ModuleVisual({
    required this.icon,
    required this.color,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String description;
}

/// Mapa visual reutilizable para menús, tarjetas, tablas y formularios.
class ModuleVisuals {
  static ModuleVisual byKey(String key) {
    switch (key) {
      case 'soporte_global':
        return const ModuleVisual(icon: Icons.help_outline_rounded, color: Color(0xFF2563EB), description: 'Centro global para atender cualquier cliente');
      case 'soporte_clientes':
        return const ModuleVisual(icon: Icons.business_center_rounded, color: Color(0xFF2563EB), description: 'Alta y soporte guiado de clientes y sucursales');
      case 'soporte_accesos':
        return const ModuleVisual(icon: Icons.security_rounded, color: Color(0xFF7C3AED), description: 'Usuarios, roles, permisos y recuperación de accesos');
      case 'soporte_operacion':
        return const ModuleVisual(icon: Icons.analytics_rounded, color: Color(0xFF0F766E), description: 'Ventas, pagos, inventario y caja');
      case 'soporte_configuracion':
        return const ModuleVisual(icon: Icons.tune_rounded, color: Color(0xFFB45309), description: 'Parámetros, catálogos y configuración técnica');
      case 'soporte_mantenimiento':
        return const ModuleVisual(icon: Icons.sync_rounded, color: Color(0xFFBE123C), description: 'Integridad, auditoría y mantenimiento seguro');
      case 'explorador_datos':
        return const ModuleVisual(icon: Icons.storage_rounded, color: Color(0xFF7C3AED), description: 'Todas las tablas y registros con auditoría');
      case 'auditoria_soporte':
        return const ModuleVisual(icon: Icons.history_rounded, color: Color(0xFF0F766E), description: 'Historial de cambios administrativos');
      case 'diagnostico_sistema':
        return const ModuleVisual(icon: Icons.monitor_heart_rounded, color: Color(0xFFDC2626), description: 'Integridad, permisos y secuencias');
      case 'sincronizar_catalogo':
        return const ModuleVisual(icon: Icons.sync_alt_rounded, color: Color(0xFF0F766E), description: 'Copia productos y costos entre empresas o sucursales sin inventario');
      case 'usuarios':
        return const ModuleVisual(icon: Icons.people_alt_rounded, color: AppColors.secondary, description: 'Personas, accesos y datos de contacto');
      case 'roles':
        return const ModuleVisual(icon: Icons.admin_panel_settings_rounded, color: AppColors.tertiary, description: 'Perfiles y permisos del sistema');
      case 'roles_personalizados':
        return const ModuleVisual(icon: Icons.add_moderator_rounded, color: Color(0xFF7C3AED), description: 'Permisos configurables por empresa o sucursal');
      case 'empresas':
        return const ModuleVisual(icon: Icons.storefront_rounded, color: AppColors.accent, description: 'Negocios o tenants registrados');
      case 'sucursales':
        return const ModuleVisual(icon: Icons.location_city_rounded, color: AppColors.info, description: 'Sedes o puntos de operación');
      case 'productos':
        return const ModuleVisual(icon: Icons.local_bar_rounded, color: Color(0xFF38BDF8), description: 'Productos disponibles para venta');
      case 'inventario':
        return const ModuleVisual(icon: Icons.inventory_2_rounded, color: AppColors.success, description: 'Stock y existencias por sucursal');
      case 'movimientos':
        return const ModuleVisual(icon: Icons.swap_horiz_rounded, color: Color(0xFF0D9488), description: 'Entradas, salidas y ajustes');
      case 'mesas':
        return const ModuleVisual(icon: Icons.table_restaurant_rounded, color: Color(0xFF0EA5E9), description: 'Mesas y estado operativo');
      case 'ventas':
        return const ModuleVisual(icon: Icons.point_of_sale_rounded, color: Color(0xFF2563EB), description: 'Consumos y ventas por mesa');
      case 'mesero':
        return const ModuleVisual(icon: Icons.room_service_rounded, color: Color(0xFFF59E0B), description: 'Operación rápida de mesas y cuentas');
      case 'cuentas_venta':
        return const ModuleVisual(icon: Icons.receipt_long_rounded, color: Color(0xFF4F46E5), description: 'Cuentas asociadas a ventas');
      case 'detalle_cuenta_venta':
        return const ModuleVisual(icon: Icons.playlist_add_check_rounded, color: Color(0xFF0284C7), description: 'Productos cobrados por cuenta');
      case 'pagos':
        return const ModuleVisual(icon: Icons.payments_rounded, color: Color(0xFF059669), description: 'Pagos y recaudos');
      case 'medios_pago':
        return const ModuleVisual(icon: Icons.credit_card_rounded, color: Color(0xFF10B981), description: 'Medios de pago aceptados');
      case 'precios':
        return const ModuleVisual(icon: Icons.sell_rounded, color: Color(0xFF06B6D4), description: 'Precios vigentes e históricos');
      case 'marcas':
        return const ModuleVisual(icon: Icons.verified_rounded, color: Color(0xFF6366F1), description: 'Marcas y fabricantes');
      case 'tipos_producto':
        return const ModuleVisual(icon: Icons.category_rounded, color: Color(0xFF9333EA), description: 'Categorías de productos');
      case 'tipos_movimiento':
        return const ModuleVisual(icon: Icons.sync_alt_rounded, color: Color(0xFF0D9488), description: 'Define cuáles movimientos aumentan, disminuyen o ajustan inventario');
      case 'planes_suscripcion':
        return const ModuleVisual(icon: Icons.workspace_premium_rounded, color: Color(0xFF06B6D4), description: 'Planes, precios, promociones y Mercado Pago');
      case 'parametros':
        return const ModuleVisual(icon: Icons.tune_rounded, color: Color(0xFF64748B), description: 'Configuración funcional del sistema');
      case 'paises':
        return const ModuleVisual(icon: Icons.public_rounded, color: Color(0xFF0EA5E9), description: 'Catálogo de países');
      case 'regiones':
        return const ModuleVisual(icon: Icons.map_rounded, color: Color(0xFF22C55E), description: 'Regiones, departamentos o estados');
      case 'ciudades':
        return const ModuleVisual(icon: Icons.location_on_rounded, color: Color(0xFF14B8A6), description: 'Ciudades y municipios');
      case 'monedas':
        return const ModuleVisual(icon: Icons.attach_money_rounded, color: Color(0xFF14B8A6), description: 'Monedas de operación');
      case 'menus':
        return const ModuleVisual(icon: Icons.menu_open_rounded, color: Color(0xFF475569), description: 'Menús funcionales');
      case 'opciones_menu':
        return const ModuleVisual(icon: Icons.fact_check_rounded, color: Color(0xFF6D28D9), description: 'Opciones y permisos por rol');
      case 'zonas_horarias':
        return const ModuleVisual(icon: Icons.schedule_rounded, color: Color(0xFF0891B2), description: 'Zonas horarias del sistema');
      case 'reportes':
        return const ModuleVisual(icon: Icons.query_stats_rounded, color: Color(0xFF8B5CF6), description: 'Indicadores y reportes operativos');
      case 'ganancias':
        return const ModuleVisual(icon: Icons.trending_up_rounded, color: AppColors.success, description: 'Ganancia bruta, margen y rentabilidad');
      case 'proximo_pedido':
        return const ModuleVisual(icon: Icons.local_shipping_rounded, color: Color(0xFFF59E0B), description: 'Reposición sugerida por stock mínimo y máximo');
      default:
        return const ModuleVisual(icon: Icons.apps_rounded, color: AppColors.secondary, description: 'Módulo operativo');
    }
  }
}
