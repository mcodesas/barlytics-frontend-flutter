import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/telemetry/error_telemetry.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/public/presentation/pages/public_landing_page.dart';
import '../../features/eventos/presentation/evento_publico_page.dart';
import '../../features/eventos/presentation/eventos_admin_page.dart';
import '../../features/menu_digital/presentation/menu_digital_admin_page.dart';
import '../../features/menu_digital/presentation/menu_digital_public_page.dart';
import '../../features/public/presentation/pages/public_registration_page.dart';
import '../../features/subscription/presentation/pages/subscription_activation_page.dart';
import '../../features/subscription/presentation/pages/subscription_plans_admin_page.dart';
import '../../features/business_setup/presentation/pages/business_setup_page.dart';
import '../../features/business_setup/presentation/pages/business_setup_operational_parameters_page.dart';
import '../../features/business_setup/presentation/widgets/business_setup_flow_shell.dart';
import '../../features/business_setup/presentation/providers/business_setup_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/navigation/presentation/providers/active_role_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/navigation/presentation/pages/personalizar_menu_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/tesoreria/presentation/pages/tesoreria_page.dart';
import '../../features/deportes/presentation/pages/agenda_deportiva_page.dart';
import '../../features/admin_support/presentation/pages/admin_support_page.dart';
import '../../features/error_center/presentation/pages/error_center_page.dart';
import '../../features/admin_support/presentation/pages/admin_data_explorer_page.dart';
import '../../features/admin_support/presentation/pages/admin_audit_page.dart';
import '../../features/admin_support/presentation/pages/admin_diagnostics_page.dart';
import '../../features/admin_support/presentation/pages/admin_support_workspace_page.dart';
import '../../features/admin_support/presentation/pages/product_catalog_sync_page.dart';
import '../../features/admin_support/presentation/pages/master_catalog_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reportes/presentation/pages/reportes_page.dart';
import '../../features/pedidos_compra/presentation/pages/pedidos_compra_page.dart';
import '../../features/gastos_fijos/presentation/pages/gastos_fijos_page.dart';
import '../../features/tablas_parametricas/presentation/pages/tablas_parametricas_page.dart';
import '../../features/mesero/presentation/pages/mesero_page.dart';
import '../../features/comandas/presentation/pages/comandas_page.dart';
import '../../features/mesero/presentation/providers/mesero_tab_provider.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/dynamic_crud_detail_page.dart';
import '../../core/widgets/dynamic_crud_form_page.dart';
import '../../core/widgets/dynamic_crud_list_page.dart';
import 'module_registry.dart';
import '../../features/ciudades/presentation/pages/ciudades_list_page.dart';
import '../../features/ciudades/presentation/pages/ciudades_form_page.dart';
import '../../features/ciudades/presentation/pages/ciudades_detail_page.dart';
import '../../features/cuentas_venta/presentation/pages/cuentas_venta_list_page.dart';
import '../../features/cuentas_venta/presentation/pages/cuentas_venta_form_page.dart';
import '../../features/cuentas_venta/presentation/pages/cuentas_venta_detail_page.dart';
import '../../features/detalle_cuenta_venta/presentation/pages/detalle_cuenta_venta_list_page.dart';
import '../../features/detalle_cuenta_venta/presentation/pages/detalle_cuenta_venta_form_page.dart';
import '../../features/detalle_cuenta_venta/presentation/pages/detalle_cuenta_venta_detail_page.dart';
import '../../features/empresas/presentation/pages/empresas_list_page.dart';
import '../../features/empresas/presentation/pages/empresas_form_page.dart';
import '../../features/empresas/presentation/pages/empresas_detail_page.dart';
import '../../features/empresas/presentation/pages/empresa_sucursales_wizard_page.dart';
import '../../features/inventario/presentation/pages/inventario_list_page.dart';
import '../../features/inventario/presentation/pages/inventario_admin_page.dart';
import '../../features/inventario/presentation/pages/inventario_form_page.dart';
import '../../features/inventario/presentation/pages/inventario_detail_page.dart';
import '../../features/marcas/presentation/pages/marcas_list_page.dart';
import '../../features/marcas/presentation/pages/marcas_form_page.dart';
import '../../features/marcas/presentation/pages/marcas_detail_page.dart';
import '../../features/medios_pago/presentation/pages/medios_pago_list_page.dart';
import '../../features/menus/presentation/pages/menus_list_page.dart';
import '../../features/menus/presentation/pages/menus_form_page.dart';
import '../../features/menus/presentation/pages/menus_detail_page.dart';
import '../../features/mesas/presentation/pages/mesas_list_page.dart';
import '../../features/mesas/presentation/pages/mesas_form_page.dart';
import '../../features/mesas/presentation/pages/mesas_detail_page.dart';
import '../../features/monedas/presentation/pages/monedas_list_page.dart';
import '../../features/monedas/presentation/pages/monedas_form_page.dart';
import '../../features/monedas/presentation/pages/monedas_detail_page.dart';
import '../../features/movimientos/presentation/pages/movimientos_list_page.dart';
import '../../features/movimientos/presentation/pages/movimientos_form_page.dart';
import '../../features/movimientos/presentation/pages/movimientos_detail_page.dart';
import '../../features/opciones_menu/presentation/pages/opciones_menu_list_page.dart';
import '../../features/opciones_menu/presentation/pages/opciones_menu_form_page.dart';
import '../../features/opciones_menu/presentation/pages/opciones_menu_detail_page.dart';
import '../../features/pagos/presentation/pages/pagos_list_page.dart';
import '../../features/pagos/presentation/pages/pagos_form_page.dart';
import '../../features/pagos/presentation/pages/pagos_detail_page.dart';
import '../../features/paises/presentation/pages/paises_list_page.dart';
import '../../features/paises/presentation/pages/paises_form_page.dart';
import '../../features/paises/presentation/pages/paises_detail_page.dart';
import '../../features/parametros/presentation/pages/parametros_list_page.dart';
import '../../features/parametros/presentation/pages/parametros_form_page.dart';
import '../../features/parametros/presentation/pages/parametros_detail_page.dart';
import '../../features/precios/presentation/pages/precios_list_page.dart';
import '../../features/precios/presentation/pages/precios_form_page.dart';
import '../../features/precios/presentation/pages/precios_detail_page.dart';
import '../../features/productos/presentation/pages/productos_list_page.dart';
import '../../features/productos/presentation/pages/productos_form_page.dart';
import '../../features/productos/presentation/pages/productos_detail_page.dart';
import '../../features/regiones/presentation/pages/regiones_list_page.dart';
import '../../features/regiones/presentation/pages/regiones_form_page.dart';
import '../../features/regiones/presentation/pages/regiones_detail_page.dart';
import '../../features/roles/presentation/pages/roles_list_page.dart';
import '../../features/roles/presentation/pages/roles_form_page.dart';
import '../../features/roles/presentation/pages/roles_detail_page.dart';
import '../../features/roles_personalizados/presentation/pages/roles_personalizados_page.dart';
import '../../features/sucursales/presentation/pages/sucursales_list_page.dart';
import '../../features/sucursales/presentation/pages/sucursales_form_page.dart';
import '../../features/sucursales/presentation/pages/sucursales_detail_page.dart';
import '../../features/tipos_producto/presentation/pages/tipos_producto_list_page.dart';
import '../../features/tipos_producto/presentation/pages/tipos_producto_form_page.dart';
import '../../features/tipos_producto/presentation/pages/tipos_producto_detail_page.dart';
import '../../features/usuarios/presentation/pages/usuarios_list_page.dart';
import '../../features/usuarios/presentation/pages/usuarios_form_page.dart';
import '../../features/usuarios/presentation/pages/usuarios_detail_page.dart';
import '../../features/usuarios/presentation/pages/usuario_roles_page.dart';
import '../../features/ventas/presentation/pages/ventas_list_page.dart';
import '../../features/ventas/presentation/pages/ventas_form_page.dart';
import '../../features/ventas/presentation/pages/ventas_detail_page.dart';
import '../../features/zonas_horarias/presentation/pages/zonas_horarias_list_page.dart';
import '../../features/zonas_horarias/presentation/pages/zonas_horarias_form_page.dart';
import '../../features/zonas_horarias/presentation/pages/zonas_horarias_detail_page.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: _resolveInitialLocation(),
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);

      // Durante la restauración inicial no se toma ninguna decisión de acceso.
      // BarLyticsApp mantiene visible el loader de marca hasta conocer si existe
      // una sesión válida, evitando el destello temporal de Login.
      if (authState.restoringSession) return null;

      final path = state.uri.path;
      ErrorTelemetry.instance.navigation(path);
      final matchedLocation = state.matchedLocation;
      final isLandingRoute = path == '/' || matchedLocation == '/';
      final isRegistrationRoute = path == '/registro' || matchedLocation == '/registro';
      final isLoginRoute = path == '/login' || matchedLocation == '/login';
      final isSubscriptionRoute = path == '/activar-suscripcion' || matchedLocation == '/activar-suscripcion';
      final isBusinessSetupRoute = path == '/configurar-negocio' || matchedLocation == '/configurar-negocio';
      final isSubscriptionPlanAdminRoute = path == '/planes_suscripcion' || matchedLocation == '/planes_suscripcion';
      final activeRoles = ref.read(activeRolesProvider);
      final isGlobalAdmin = activeRoles.any(_isGlobalAdminRole);
      final isPlatformAdminRoute = _isPlatformAdminRoute(path);
      final isSetupConfigurationRoute = _isBusinessSetupConfigurationRoute(path);
      final isForgotPasswordRoute = path == '/forgot-password' || matchedLocation == '/forgot-password';
      final isResetPasswordRoute = path == '/reset-password' || matchedLocation == '/reset-password';
      // La landing comercial pertenece exclusivamente a Flutter Web.
      // En Android, iOS, Windows, macOS y Linux la aplicación instalada
      // comienza en autenticación y solo conserva las rutas públicas
      // necesarias para acceso, registro y recuperación de contraseña.
      final isEventPublic = path.startsWith('/evento/');
      final isDigitalMenuPublic = path.startsWith('/carta/');
      final isPublicRoute = isEventPublic || isDigitalMenuPublic || (kIsWeb && isLandingRoute) ||
          isRegistrationRoute ||
          isLoginRoute ||
          isForgotPasswordRoute ||
          isResetPasswordRoute;

      if (!authState.authenticated && !isPublicRoute) return '/login';

      // Planes comerciales y soporte global son funciones exclusivas del
      // administrador de plataforma. Un GERENTE no puede entrar por URL directa.
      if (authState.authenticated && isPlatformAdminRoute && !isGlobalAdmin) {
        if (!authState.subscriptionActive) return '/activar-suscripcion';
        return authState.businessSetupComplete ? '/home' : '/configurar-negocio';
      }

      // Una sesión con suscripción pendiente solo puede entrar a la activación.
      // El backend aplica la misma regla para impedir saltarse este control.
      if (authState.authenticated && !authState.subscriptionActive && !isEventPublic && !isDigitalMenuPublic && !isSubscriptionRoute && !isResetPasswordRoute && !(isSubscriptionPlanAdminRoute && isGlobalAdmin)) {
        return '/activar-suscripcion';
      }

      // Después del pago, el GERENTE debe completar la parametrización esencial.
      // Se permiten las rutas que forman parte del propio asistente para reutilizar
      // los formularios existentes de empresa, sucursal, catálogo e inventario.
      if (authState.authenticated &&
          authState.subscriptionActive &&
          !authState.businessSetupComplete &&
          !isEventPublic && !isDigitalMenuPublic && !isBusinessSetupRoute &&
          !isSetupConfigurationRoute &&
          !isResetPasswordRoute) {
        return '/configurar-negocio';
      }
      final isInventario = activeRoles.any((role) {
        final normalized = normalizeRoleName(role);
        return const {'INVENTARIO', 'INVENTORY', 'BODEGA', 'ALMACEN'}.contains(normalized);
      });
      final canUseMesero = activeRoles.any((role) {
        final normalized = normalizeRoleName(role);
        return const {'MESERO', 'MESERA', 'CAJERO', 'CAJERA', 'VENDEDOR', 'VENDEDORA', 'VENTAS', 'SELLER', 'GERENTE', 'MANAGER', 'SUPERVISOR', 'ADMIN', 'ADMINISTRADOR', 'SUPERADMIN', 'SUPER_ADMIN'}.contains(normalized);
      });
      final inventoryOnly = activeRoles.isNotEmpty && activeRoles.every((role) {
        final normalized = normalizeRoleName(role);
        return const {'INVENTARIO', 'INVENTORY', 'BODEGA', 'ALMACEN'}.contains(normalized);
      });
      final movementsOnly = activeRoles.isNotEmpty && activeRoles.every((role) {
        final normalized = normalizeRoleName(role);
        return const {'MOVIMIENTOS', 'MOVIMIENTO'}.contains(normalized);
      });
      final pricesOnly = activeRoles.isNotEmpty && activeRoles.every((role) {
        return normalizeRoleName(role) == 'PRECIOS';
      });
      final commandsOnly = activeRoles.isNotEmpty && activeRoles.every((role) {
        final normalized = normalizeRoleName(role);
        return const {'COCINA', 'BARRA', 'COMANDAS'}.contains(normalized);
      });
      final restrictedOperationalOnly = activeRoles.isNotEmpty && activeRoles.every((role) {
        final normalized = normalizeRoleName(role);
        return const {
          'INVENTARIO',
          'INVENTORY',
          'BODEGA',
          'ALMACEN',
          'MOVIMIENTOS',
          'MOVIMIENTO',
          'PRECIOS',
        }.contains(normalized);
      });
      final hasMovementRole = activeRoles.any((role) {
        final normalized = normalizeRoleName(role);
        return const {'MOVIMIENTOS', 'MOVIMIENTO'}.contains(normalized);
      });
      final hasPriceRole = activeRoles.any((role) => normalizeRoleName(role) == 'PRECIOS');

      // Estos roles son deliberadamente operativos. Si son los únicos roles
      // activos, no deben poder abrir por URL módulos administrativos que no
      // aparecen en su menú.
      if (authState.authenticated && !isDigitalMenuPublic && inventoryOnly) {
        final allowed = path == '/home' || path == '/profile' || path == '/personalizar_menu' || path.startsWith('/inventario');
        if (!allowed) return '/inventario';
      }
      if (authState.authenticated && !isDigitalMenuPublic && movementsOnly) {
        final allowed = path == '/home' || path == '/profile' || path == '/personalizar_menu' || path == '/productos' || path.startsWith('/movimientos');
        if (!allowed) return '/movimientos';
      }
      if (authState.authenticated && !isDigitalMenuPublic && pricesOnly) {
        final allowed = path == '/home' || path == '/profile' || path == '/personalizar_menu' || path.startsWith('/precios');
        if (!allowed) return '/precios';
      }
      if (authState.authenticated && !isDigitalMenuPublic && commandsOnly) {
        final allowed = path == '/home' || path == '/profile' || path == '/personalizar_menu' || path.startsWith('/comandas');
        if (!allowed) return '/comandas';
      }
      if (authState.authenticated && !isDigitalMenuPublic &&
          restrictedOperationalOnly &&
          !inventoryOnly &&
          !movementsOnly &&
          !pricesOnly) {
        final allowed = path == '/home' ||
            path == '/profile' ||
            path == '/personalizar_menu' ||
            (isInventario && path.startsWith('/inventario')) ||
            (hasMovementRole && (path == '/productos' || path.startsWith('/movimientos'))) ||
            (hasPriceRole && path.startsWith('/precios'));
        if (!allowed) {
          if (hasMovementRole) return '/movimientos';
          if (isInventario) return '/inventario';
          return '/precios';
        }
      }

      // Solo una vista exclusivamente de Inventario se mantiene fuera de Mesas.
      // Si el usuario activa Mesero/Gerente o usa Todos, Vender / Mesas funciona.
      if (authState.authenticated && isInventario && !canUseMesero && path.startsWith('/mesero')) {
        return '/productos';
      }

      // Login y olvidé contraseña no se muestran cuando ya hay sesión activa.
      // Reset password sí se permite porque puede abrirse desde un enlace externo.
      // No se usa Uri.base dentro del redirect para no forzar de nuevo #/login en web.
      if (authState.authenticated && (isLoginRoute || isForgotPasswordRoute || isRegistrationRoute || isLandingRoute)) {
        if (!authState.subscriptionActive) return '/activar-suscripcion';
        return authState.businessSetupComplete ? '/home' : '/configurar-negocio';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/evento/entrada/:token', builder: (context,state) => EventoEntradaPublicaPage(token: state.pathParameters['token']!)),
      GoRoute(path: '/evento/:slug', builder: (context,state) => EventoPublicoPage(slug: state.pathParameters['slug']!)),
      GoRoute(path: '/eventos', builder: (context,state) => const AppScaffold(child: EventosAdminPage())),
      GoRoute(path: '/carta/:slug', builder: (context, state) =>
          MenuDigitalPublicPage(slug: state.pathParameters['slug']!)),
      GoRoute(path: '/menu_digital', builder: (context, state) =>
          const AppScaffold(child: MenuDigitalAdminPage())),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            kIsWeb ? const PublicLandingPage() : const LoginPage(),
      ),
      GoRoute(path: '/registro', builder: (context, state) => PublicRegistrationPage(planCode: state.uri.queryParameters['plan'])),
      GoRoute(path: '/activar-suscripcion', builder: (context, state) => const SubscriptionActivationPage()),
      GoRoute(path: '/configurar-negocio', builder: (context, state) => const BusinessSetupPage()),
      GoRoute(
        path: '/parametros-operativos',
        builder: (context, state) => _setupAwareScaffold(
          ref,
          state,
          const BusinessSetupOperationalParametersPage(),
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordPage()),
      GoRoute(path: '/reset-password', builder: (context, state) => ResetPasswordPage(code: _recoveryCodeFromState(state))),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/personalizar_menu', builder: (context, state) =>
          const AppScaffold(child: PersonalizarMenuPage())),
      GoRoute(path: '/soporte_global', builder: (context, state) => AppScaffold(child: const AdminSupportPage())),
      GoRoute(path: '/centro_errores', builder: (context, state) =>
          const AppScaffold(child: ErrorCenterPage())),
      GoRoute(
        path: '/explorador_datos',
        builder: (context, state) => AppScaffold(
          child: AdminDataExplorerPage(initialTable: state.uri.queryParameters['table']),
        ),
      ),
      GoRoute(path: '/auditoria_soporte', builder: (context, state) => AppScaffold(child: const AdminAuditPage())),
      GoRoute(path: '/diagnostico_sistema', builder: (context, state) => AppScaffold(child: const AdminDiagnosticsPage())),
      GoRoute(path: '/soporte_clientes', builder: (context, state) => AppScaffold(child: const AdminSupportWorkspacePage(type: AdminSupportWorkspaceType.clients))),
      GoRoute(path: '/soporte_accesos', builder: (context, state) => AppScaffold(child: const AdminSupportWorkspacePage(type: AdminSupportWorkspaceType.access))),
      GoRoute(path: '/soporte_operacion', builder: (context, state) => AppScaffold(child: const AdminSupportWorkspacePage(type: AdminSupportWorkspaceType.operations))),
      GoRoute(path: '/soporte_configuracion', builder: (context, state) => AppScaffold(child: const AdminSupportWorkspacePage(type: AdminSupportWorkspaceType.configuration))),
      GoRoute(path: '/soporte_mantenimiento', builder: (context, state) => AppScaffold(child: const AdminSupportWorkspacePage(type: AdminSupportWorkspaceType.maintenance))),
      GoRoute(path: '/sincronizar_catalogo', builder: (context, state) => AppScaffold(child: const ProductCatalogSyncPage())),
      GoRoute(path: '/catalogo_maestro', builder: (context, state) => AppScaffold(child: const MasterCatalogPage())),
      GoRoute(path: '/profile', builder: (context, state) => _setupAwareScaffold(ref, state, const ProfilePage())),
      GoRoute(path: '/dashboard', builder: (context, state) => const AppScaffold(child: DashboardPage())),
      GoRoute(path: '/tesoreria', builder: (context, state) => const AppScaffold(child: TesoreriaPage())),
      GoRoute(path: '/agenda_deportiva', builder: (context, state) => const AppScaffold(child: AgendaDeportivaPage())),
      GoRoute(path: '/reportes', builder: (context, state) => AppScaffold(child: const ReportesPage())),
      GoRoute(
        path: '/reporte_resumen_ejecutivo',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_resumen_ejecutivo'),
        ),
      ),
      GoRoute(
        path: '/reporte_ventas_fecha',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_ventas_fecha'),
        ),
      ),
      GoRoute(
        path: '/reporte_ventas_medio_pago',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_ventas_medio_pago'),
        ),
      ),
      GoRoute(
        path: '/reporte_stock_actual',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_stock_actual'),
        ),
      ),
      GoRoute(path: '/ganancias', builder: (context, state) => AppScaffold(child: const ReportesPage.ganancias())),
      GoRoute(path: '/gastos_fijos', builder: (context, state) => const AppScaffold(child: GastosFijosPage())),
      GoRoute(path: '/proximo_pedido', builder: (context, state) => AppScaffold(child: const ReportesPage.proximoPedido())),
      GoRoute(path: '/pedidos-compra', builder: (context, state) => const AppScaffold(child: PedidosCompraPage())),
      GoRoute(path: '/proveedores-pedidos', builder: (context, state) => const AppScaffold(child: PedidosCompraPage.proveedores())),
      GoRoute(path: '/pedidos_compra', builder: (context, state) => const AppScaffold(child: PedidosCompraPage())),
      GoRoute(path: '/proveedores_pedidos', builder: (context, state) => const AppScaffold(child: PedidosCompraPage.proveedores())),
      GoRoute(
        path: '/reporte_cruce_conteo',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_cruce_conteo'),
        ),
      ),
      GoRoute(
        path: '/reporte_productos_mas_vendidos',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_productos_mas_vendidos'),
        ),
      ),
      GoRoute(
        path: '/reporte_movimientos_inventario',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_movimientos_inventario'),
        ),
      ),
      GoRoute(
        path: '/reporte_rotacion_inventario',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_rotacion_inventario'),
        ),
      ),
      GoRoute(
        path: '/reporte_alertas_inventario',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_alertas_inventario'),
        ),
      ),
      GoRoute(
        path: '/reporte_salidas_responsable',
        builder: (context, state) => AppScaffold(
          child: const ReportesPage.reporte(keyName: 'reporte_salidas_responsable'),
        ),
      ),
      GoRoute(path: '/tablas_parametricas', builder: (context, state) => _setupAwareScaffold(ref, state, const TablasParametricasPage())),
      GoRoute(path: '/comandas', builder: (context, state) => AppScaffold(child: const ComandasPage())),
      GoRoute(path: '/mesero', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.mesas))),
      GoRoute(path: '/mesero/productos', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.productos))),
      GoRoute(path: '/mesero/resumen', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.resumen))),
      GoRoute(path: '/mesero/historial', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.historial))),
      GoRoute(path: '/mesero/cierre-caja', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.cierreCaja))),
      GoRoute(path: '/historial_ventas', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.historial))),
      GoRoute(path: '/cierre_caja', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.cierreCaja))),
      GoRoute(path: '/administrar_mesas', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.mesas))),

      GoRoute(
        path: '/ciudades',
        builder: (context, state) => _setupAwareScaffold(ref, state, const CiudadesListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const CiudadesFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, CiudadesDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, CiudadesFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/cuentas_venta',
        builder: (context, state) => AppScaffold(child: const CuentasVentaListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const CuentasVentaFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: CuentasVentaDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: CuentasVentaFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/detalle_cuenta_venta',
        builder: (context, state) => AppScaffold(child: const DetalleCuentaVentaListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const DetalleCuentaVentaFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: DetalleCuentaVentaDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: DetalleCuentaVentaFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/empresas',
        builder: (context, state) => _setupAwareScaffold(ref, state, const EmpresasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const EmpresasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, EmpresasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, EmpresasFormPage(id: state.pathParameters['id']))),
          GoRoute(path: ':id/sucursales-wizard', builder: (context, state) => _setupAwareScaffold(ref, state, EmpresaSucursalesWizardPage(empresaId: state.pathParameters['id']!))),
        ],
      ),

      GoRoute(
        path: '/inventario',
        builder: (context, state) => _setupAwareScaffold(ref, state, const InventarioListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const InventarioFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, InventarioDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, InventarioFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/inventario_admin',
        builder: (context, state) =>
            _setupAwareScaffold(ref, state, const InventarioAdminPage()),
      ),

      GoRoute(
        path: '/marcas',
        builder: (context, state) => _setupAwareScaffold(ref, state, const MarcasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const MarcasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, MarcasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, MarcasFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/medios_pago',
        builder: (context, state) => _setupAwareScaffold(ref, state, const MediosPagoListPage()),
      ),

      GoRoute(
        path: '/menus',
        builder: (context, state) => AppScaffold(child: const MenusListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const MenusFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: MenusDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: MenusFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/mesas',
        builder: (context, state) => _setupAwareScaffold(ref, state, const MesasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const MesasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, MesasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, MesasFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/monedas',
        builder: (context, state) => _setupAwareScaffold(ref, state, const MonedasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const MonedasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, MonedasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, MonedasFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/movimientos',
        builder: (context, state) => AppScaffold(child: const MovimientosListPage()),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (context, state) => AppScaffold(
              child: MovimientosFormPage(
                initialValues: <String, dynamic>{
                  for (final entry in state.uri.queryParameters.entries)
                    if (entry.value.trim().isNotEmpty) entry.key: entry.value,
                },
              ),
            ),
          ),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: MovimientosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: MovimientosFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/opciones_menu',
        builder: (context, state) => AppScaffold(child: const OpcionesMenuListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const OpcionesMenuFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: OpcionesMenuDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: OpcionesMenuFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/pagos',
        builder: (context, state) => AppScaffold(child: const PagosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const PagosFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: PagosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: PagosFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/paises',
        builder: (context, state) => _setupAwareScaffold(ref, state, const PaisesListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const PaisesFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, PaisesDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, PaisesFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/planes_suscripcion',
        builder: (context, state) => AppScaffold(child: const SubscriptionPlansAdminPage()),
      ),

      GoRoute(
        path: '/parametros',
        builder: (context, state) => _setupAwareScaffold(ref, state, const ParametrosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const ParametrosFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, ParametrosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, ParametrosFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/precios',
        builder: (context, state) => _setupAwareScaffold(ref, state, const PreciosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const PreciosFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, PreciosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, PreciosFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/productos',
        builder: (context, state) => _setupAwareScaffold(ref, state, const ProductosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const ProductosFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, ProductosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, ProductosFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/regiones',
        builder: (context, state) => _setupAwareScaffold(ref, state, const RegionesListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const RegionesFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, RegionesDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, RegionesFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/roles',
        builder: (context, state) => AppScaffold(child: const RolesListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const RolesFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: RolesDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: RolesFormPage(id: state.pathParameters['id']))),
        ],
      ),


      GoRoute(
        path: '/roles_personalizados',
        builder: (context, state) => _setupAwareScaffold(ref, state, const RolesPersonalizadosPage()),
      ),

      GoRoute(
        path: '/sucursales',
        builder: (context, state) => _setupAwareScaffold(ref, state, const SucursalesListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const SucursalesFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, SucursalesDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, SucursalesFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/tipos_movimiento',
        builder: (context, state) => AppScaffold(
          child: DynamicCrudListPage<Map<String, dynamic>>(config: tiposmovimientoConfig),
        ),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (context, state) => AppScaffold(
              child: DynamicCrudFormPage<Map<String, dynamic>>(config: tiposmovimientoConfig),
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => AppScaffold(
              child: DynamicCrudDetailPage<Map<String, dynamic>>(
                config: tiposmovimientoConfig,
                id: state.pathParameters['id']!,
              ),
            ),
          ),
          GoRoute(
            path: ':id/editar',
            builder: (context, state) => AppScaffold(
              child: DynamicCrudFormPage<Map<String, dynamic>>(
                config: tiposmovimientoConfig,
                id: state.pathParameters['id'],
              ),
            ),
          ),
        ],
      ),

      GoRoute(
        path: '/tipos_producto',
        builder: (context, state) => _setupAwareScaffold(ref, state, const TiposProductoListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const TiposProductoFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, TiposProductoDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, TiposProductoFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/usuarios',
        builder: (context, state) => _setupAwareScaffold(ref, state, const UsuariosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const UsuariosFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, UsuariosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, UsuariosFormPage(id: state.pathParameters['id']))),
          GoRoute(path: ':id/roles', builder: (context, state) => _setupAwareScaffold(ref, state, UsuarioRolesPage(usuarioId: state.pathParameters['id']!))),
        ],
      ),

      GoRoute(
        path: '/ventas',
        builder: (context, state) => AppScaffold(child: const VentasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const VentasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: VentasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: VentasFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/zonas_horarias',
        builder: (context, state) => _setupAwareScaffold(ref, state, const ZonasHorariasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => _setupAwareScaffold(ref, state, const ZonasHorariasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => _setupAwareScaffold(ref, state, ZonasHorariasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => _setupAwareScaffold(ref, state, ZonasHorariasFormPage(id: state.pathParameters['id']))),
        ],
      ),

    ],
  );
});



Widget _setupAwareScaffold(ProviderRef<GoRouter> ref, GoRouterState state, Widget child) {
  final authState = ref.read(authControllerProvider);
  final path = state.uri.path;
  final guidedHelpMode = ref.read(businessSetupGuidedModeProvider);
  final inGuidedSetup = authState.authenticated &&
      authState.subscriptionActive &&
      (!authState.businessSetupComplete || guidedHelpMode) &&
      path != '/configurar-negocio' &&
      _isBusinessSetupConfigurationRoute(path);

  if (inGuidedSetup) {
    return BusinessSetupFlowShell(location: path, child: child);
  }

  return AppScaffold(child: child);
}


bool _isGlobalAdminRole(String role) {
  final normalized = role.toUpperCase().trim().replaceFirst(RegExp(r'^ROLE_'), '');
  return normalized == 'ADMIN' ||
      normalized == 'ADMINISTRADOR' ||
      normalized == 'SUPERADMIN' ||
      normalized == 'SUPER_ADMIN';
}


bool _isPlatformAdminRoute(String path) {
  return path.startsWith('/centro_errores') ||
      path.startsWith('/planes_suscripcion') ||
      path.startsWith('/catalogo_maestro') ||
      path.startsWith('/soporte_global') ||
      path.startsWith('/soporte_clientes') ||
      path.startsWith('/soporte_accesos') ||
      path.startsWith('/soporte_operacion') ||
      path.startsWith('/soporte_configuracion') ||
      path.startsWith('/soporte_mantenimiento') ||
      path.startsWith('/explorador_datos') ||
      path.startsWith('/auditoria_soporte') ||
      path.startsWith('/diagnostico_sistema');
}

bool _isBusinessSetupConfigurationRoute(String path) {
  const prefixes = <String>[
    '/configurar-negocio',
    '/profile',
    '/empresas',
    '/sucursales',
    '/medios_pago',
    '/productos',
    '/precios',
    '/inventario',
    '/marcas',
    '/tipos_producto',
    '/tablas_parametricas',
    '/monedas',
    '/paises',
    '/regiones',
    '/ciudades',
    '/zonas_horarias',
    '/tipos_identificacion',
    '/parametros-operativos',
    '/parametros',
    '/usuarios',
    '/roles_personalizados',
    '/mesas',
  ];
  return prefixes.any(path.startsWith);
}

String _resolveInitialLocation() {
  // Las aplicaciones instalables no exponen el sitio comercial. Su punto de
  // entrada es siempre Login; GoRouter se encargará de llevar una sesión ya
  // autenticada a suscripción, puesta en marcha o inicio según corresponda.
  if (!kIsWeb) return '/login';

  final normalizedHashLocation = _normalizedHashPublicLocation(Uri.base);
  if (normalizedHashLocation != null) return normalizedHashLocation;

  final currentUri = Uri.base;

  // PSE retorna a una URL HTTP sin fragmento porque Mercado Pago rechaza
  // callback_url con #. Si el banco/Mercado Pago agrega datos del pago al
  // query string, restauramos la ruta hash interna de activación conservando
  // todos esos parámetros para sincronizar el estado.
  final paymentReturn = currentUri.queryParameters.containsKey('payment_id') ||
      currentUri.queryParameters.containsKey('collection_id') ||
      currentUri.queryParameters.containsKey('external_reference') ||
      currentUri.queryParameters.containsKey('status');
  if (currentUri.path == '/' && paymentReturn) {
    return currentUri.hasQuery ? '/activar-suscripcion?${currentUri.query}' : '/activar-suscripcion';
  }

  if (currentUri.path == '/reset-password') {
    return currentUri.hasQuery ? '/reset-password?${currentUri.query}' : '/reset-password';
  }
  if (currentUri.path == '/forgot-password') return '/forgot-password';
  if (currentUri.path == '/login') return '/login';
  if (currentUri.path == '/registro') return '/registro';
  if (currentUri.path == '/activar-suscripcion') {
    return currentUri.hasQuery ? '/activar-suscripcion?${currentUri.query}' : '/activar-suscripcion';
  }
  if (currentUri.path == '/') return '/';

  return '/';
}

String? _normalizedHashPublicLocation(Uri uri) {
  final fragment = uri.fragment.trim();
  if (fragment.isEmpty) return null;

  final parsedFragment = Uri.tryParse(fragment.startsWith('/') ? fragment : '/$fragment');
  if (parsedFragment == null) return null;

  if (parsedFragment.path == '/reset-password') {
    return parsedFragment.hasQuery ? '/reset-password?${parsedFragment.query}' : '/reset-password';
  }
  if (parsedFragment.path == '/forgot-password') return '/forgot-password';
  if (parsedFragment.path == '/login') return '/login';
  if (parsedFragment.path == '/registro') return '/registro';
  if (parsedFragment.path == '/activar-suscripcion') {
    return parsedFragment.hasQuery ? '/activar-suscripcion?${parsedFragment.query}' : '/activar-suscripcion';
  }
  if (parsedFragment.path == '/') return '/';

  return null;
}

String _recoveryCodeFromState(GoRouterState state) {
  final queryCode = state.uri.queryParameters['code'];
  if (queryCode != null && queryCode.trim().isNotEmpty) return queryCode;

  final fragment = Uri.base.fragment.trim();
  if (fragment.isEmpty) return '';

  final parsedFragment = Uri.tryParse(fragment.startsWith('/') ? fragment : '/$fragment');
  if (parsedFragment == null) return '';

  return parsedFragment.queryParameters['code'] ?? '';
}

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
    ref.listen(selectedRolesProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}
