import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reportes/presentation/pages/reportes_page.dart';
import '../../features/mesero/presentation/pages/mesero_page.dart';
import '../../features/mesero/presentation/providers/mesero_tab_provider.dart';
import '../../core/widgets/app_scaffold.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: _resolveInitialLocation(),
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final path = state.uri.path;
      final matchedLocation = state.matchedLocation;
      final isLoginRoute = path == '/login' || matchedLocation == '/login';
      final isForgotPasswordRoute = path == '/forgot-password' || matchedLocation == '/forgot-password';
      final isResetPasswordRoute = path == '/reset-password' || matchedLocation == '/reset-password';
      final isPublicRoute = isLoginRoute || isForgotPasswordRoute || isResetPasswordRoute;

      if (!authState.authenticated && !isPublicRoute) return '/login';

      // Login y olvidé contraseña no se muestran cuando ya hay sesión activa.
      // Reset password sí se permite porque puede abrirse desde un enlace externo.
      // No se usa Uri.base dentro del redirect para no forzar de nuevo #/login en web.
      if (authState.authenticated && (isLoginRoute || isForgotPasswordRoute)) {
        final isOperativoMesa = authState.roles.any((role) {
          final normalized = role.toUpperCase();
          return normalized.contains('MESERO') || normalized.contains('CAJERO') || normalized.contains('INVENTARIO') || normalized.contains('INVENTORY') || normalized.contains('BODEGA') || normalized.contains('ALMACEN') || normalized.contains('ALMACÉN');
        });
        if (isOperativoMesa) {
          final isInventario = authState.roles.any((role) {
            final normalized = role.toUpperCase();
            return normalized.contains('INVENTARIO') || normalized.contains('INVENTORY') || normalized.contains('BODEGA') || normalized.contains('ALMACEN') || normalized.contains('ALMACÉN');
          });
          return isInventario ? '/productos' : '/mesero';
        }
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => _normalizedHashPublicLocation(Uri.base) ?? '/login'),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordPage()),
      GoRoute(path: '/reset-password', builder: (context, state) => ResetPasswordPage(code: _recoveryCodeFromState(state))),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/profile', builder: (context, state) => AppScaffold(child: const ProfilePage())),
      GoRoute(path: '/reportes', builder: (context, state) => AppScaffold(child: const ReportesPage())),
      GoRoute(path: '/mesero', builder: (context, state) => AppScaffold(child: const MeseroPage())),
      GoRoute(path: '/mesero/productos', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.productos))),
      GoRoute(path: '/mesero/resumen', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.resumen))),
      GoRoute(path: '/mesero/historial', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.historial))),
      GoRoute(path: '/mesero/cierre-caja', builder: (context, state) => AppScaffold(child: const MeseroPage(initialMode: MeseroPageMode.cierreCaja))),

      GoRoute(
        path: '/ciudades',
        builder: (context, state) => AppScaffold(child: const CiudadesListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const CiudadesFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: CiudadesDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: CiudadesFormPage(id: state.pathParameters['id']))),
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
        builder: (context, state) => AppScaffold(child: const EmpresasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const EmpresasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: EmpresasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: EmpresasFormPage(id: state.pathParameters['id']))),
          GoRoute(path: ':id/sucursales-wizard', builder: (context, state) => AppScaffold(child: EmpresaSucursalesWizardPage(empresaId: state.pathParameters['id']!))),
        ],
      ),

      GoRoute(
        path: '/inventario',
        builder: (context, state) => AppScaffold(child: const InventarioListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const InventarioFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: InventarioDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: InventarioFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/marcas',
        builder: (context, state) => AppScaffold(child: const MarcasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const MarcasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: MarcasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: MarcasFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/medios_pago',
        builder: (context, state) => AppScaffold(child: const MediosPagoListPage()),
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
        builder: (context, state) => AppScaffold(child: const MesasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const MesasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: MesasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: MesasFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/monedas',
        builder: (context, state) => AppScaffold(child: const MonedasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const MonedasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: MonedasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: MonedasFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/movimientos',
        builder: (context, state) => AppScaffold(child: const MovimientosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const MovimientosFormPage())),
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
        builder: (context, state) => AppScaffold(child: const PaisesListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const PaisesFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: PaisesDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: PaisesFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/parametros',
        builder: (context, state) => AppScaffold(child: const ParametrosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const ParametrosFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: ParametrosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: ParametrosFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/precios',
        builder: (context, state) => AppScaffold(child: const PreciosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const PreciosFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: PreciosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: PreciosFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/productos',
        builder: (context, state) => AppScaffold(child: const ProductosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const ProductosFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: ProductosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: ProductosFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/regiones',
        builder: (context, state) => AppScaffold(child: const RegionesListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const RegionesFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: RegionesDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: RegionesFormPage(id: state.pathParameters['id']))),
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
        path: '/sucursales',
        builder: (context, state) => AppScaffold(child: const SucursalesListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const SucursalesFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: SucursalesDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: SucursalesFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/tipos_producto',
        builder: (context, state) => AppScaffold(child: const TiposProductoListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const TiposProductoFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: TiposProductoDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: TiposProductoFormPage(id: state.pathParameters['id']))),
        ],
      ),

      GoRoute(
        path: '/usuarios',
        builder: (context, state) => AppScaffold(child: const UsuariosListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const UsuariosFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: UsuariosDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: UsuariosFormPage(id: state.pathParameters['id']))),
          GoRoute(path: ':id/roles', builder: (context, state) => AppScaffold(child: UsuarioRolesPage(usuarioId: state.pathParameters['id']!))),
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
        builder: (context, state) => AppScaffold(child: const ZonasHorariasListPage()),
        routes: [
          GoRoute(path: 'nuevo', builder: (context, state) => AppScaffold(child: const ZonasHorariasFormPage())),
          GoRoute(path: ':id', builder: (context, state) => AppScaffold(child: ZonasHorariasDetailPage(id: state.pathParameters['id']!))),
          GoRoute(path: ':id/editar', builder: (context, state) => AppScaffold(child: ZonasHorariasFormPage(id: state.pathParameters['id']))),
        ],
      ),

    ],
  );
});


String _resolveInitialLocation() {
  final normalizedHashLocation = _normalizedHashPublicLocation(Uri.base);
  if (normalizedHashLocation != null) return normalizedHashLocation;

  final currentUri = Uri.base;
  if (currentUri.path == '/reset-password') {
    return currentUri.hasQuery ? '/reset-password?${currentUri.query}' : '/reset-password';
  }
  if (currentUri.path == '/forgot-password') return '/forgot-password';
  if (currentUri.path == '/login') return '/login';

  return '/login';
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
  }
  final Ref ref;
}
