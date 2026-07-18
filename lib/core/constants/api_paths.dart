/// Rutas REST centralizadas obtenidas desde la colección Postman.
class ApiPaths {
  static const authLogin = '/api/v1/auth/login';
  static const authLogout = '/api/v1/auth/logout';
  static const authForgotPassword = '/api/v1/auth/forgot-password';
  static const authPasswordRecoveryValidate = '/api/v1/auth/password-recovery/validate';
  static const authResetPassword = '/api/v1/auth/reset-password';
  static const authMe = '/api/v1/auth/me';
  static const authMeMenus = '/api/v1/auth/me/menus';
  static const profile = '/api/v1/profile';
  static const me = '/api/v1/me';
  static const ciudades = '/api/v1/ciudades';
  static const cuentasventa = '/api/v1/cuentasventa';
  static const detallecuentaventa = '/api/v1/detallecuentaventa';
  static const empresas = '/api/v1/empresas';
  static const inventario = '/api/v1/inventario';
  static const marcas = '/api/v1/marcas';
  static const mediospago = '/api/v1/mediospago';
  static const menus = '/api/v1/menus';
  static const mesas = '/api/v1/mesas';
  static const monedas = '/api/v1/monedas';
  static const movimientos = '/api/v1/movimientos';
  static const opcionesmenu = '/api/v1/opcionesmenu';
  static const pagos = '/api/v1/pagos';
  static const paises = '/api/v1/paises';
  static const parametros = '/api/v1/parametros';
  static const precios = '/api/v1/precios';
  static const productos = '/api/v1/productos';
  static const regiones = '/api/v1/regiones';
  static const reportes = '/api/v1/reportes';
  static const roles = '/api/v1/roles';
  static const sucursales = '/api/v1/sucursales';
  static const tiposidentificacion = '/api/v1/tiposidentificacion';
  static const tiposproducto = '/api/v1/tiposproducto';
  static const usuarios = '/api/v1/usuarios';
  static const ventas = '/api/v1/ventas';
  static const zonashorarias = '/api/v1/zonashorarias';

  static const meseroMesas = '/api/v1/mesero/mesas';
  static const meseroCrearMesa = '/api/v1/mesero/mesas';
  static const meseroProductos = '/api/v1/mesero/productos';
  static const meseroMediosPago = '/api/v1/mesero/medios-pago';
  static const meseroAbrirVenta = '/api/v1/mesero/ventas/abrir';
  static const meseroHistorialVentas = '/api/v1/mesero/ventas/historial';
  static const meseroCierreCajaResumen = '/api/v1/mesero/cierre-caja/resumen';
  static const meseroCierreCaja = '/api/v1/mesero/cierre-caja';
  static const meseroCierreCajaReporte = '/api/v1/mesero/cierre-caja/reporte';
  static String meseroCierreCajaById(Object id) => '/api/v1/mesero/cierre-caja/$id';
  static String meseroMesa(Object id) => '/api/v1/mesero/mesas/$id';
  static String meseroVenta(Object id) => '/api/v1/mesero/ventas/$id';
  static String meseroVentaCuentas(Object id) => '/api/v1/mesero/ventas/$id/cuentas';
  static String meseroLimpiarVentaSinConsumos(Object id) => '/api/v1/mesero/ventas/$id/cuentas-vacias';
  static String meseroAgregarProductoCuenta(Object cuentaId) => '/api/v1/mesero/cuentas/$cuentaId/productos';
  static String meseroActualizarCantidadProductoCuenta(Object cuentaId, Object detalleId) =>
      '/api/v1/mesero/cuentas/$cuentaId/productos/$detalleId/cantidad';
  static String meseroEliminarProductoCuenta(Object cuentaId, Object detalleId) => '/api/v1/mesero/cuentas/$cuentaId/productos/$detalleId';
  static String meseroMoverProductoCuenta(Object cuentaId, Object detalleId, Object cuentaDestinoId) =>
      '/api/v1/mesero/cuentas/$cuentaId/productos/$detalleId/mover/$cuentaDestinoId';
  static String meseroPagarCuenta(Object cuentaId) => '/api/v1/mesero/cuentas/$cuentaId/pagos';
  static String meseroEliminarCuenta(Object cuentaId) => '/api/v1/mesero/cuentas/$cuentaId';
  static String meseroFinalizarVenta(Object ventaId) => '/api/v1/mesero/ventas/$ventaId/finalizar';
}
