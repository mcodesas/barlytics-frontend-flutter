import '../../core/crud/crud_field.dart';
import '../../core/crud/crud_module_config.dart';
import '../../features/ciudades/data/models/ciudades_request_model.dart';
import '../../features/ciudades/data/models/ciudades_response_model.dart';
import '../../features/cuentas_venta/data/models/cuentas_venta_request_model.dart';
import '../../features/cuentas_venta/data/models/cuentas_venta_response_model.dart';
import '../../features/detalle_cuenta_venta/data/models/detalle_cuenta_venta_request_model.dart';
import '../../features/detalle_cuenta_venta/data/models/detalle_cuenta_venta_response_model.dart';
import '../../features/empresas/data/models/empresas_request_model.dart';
import '../../features/empresas/data/models/empresas_response_model.dart';
import '../../features/inventario/data/models/inventario_request_model.dart';
import '../../features/inventario/data/models/inventario_response_model.dart';
import '../../features/marcas/data/models/marcas_request_model.dart';
import '../../features/marcas/data/models/marcas_response_model.dart';
import '../../features/medios_pago/data/models/medios_pago_request_model.dart';
import '../../features/medios_pago/data/models/medios_pago_response_model.dart';
import '../../features/menus/data/models/menus_request_model.dart';
import '../../features/menus/data/models/menus_response_model.dart';
import '../../features/mesas/data/models/mesas_request_model.dart';
import '../../features/mesas/data/models/mesas_response_model.dart';
import '../../features/monedas/data/models/monedas_request_model.dart';
import '../../features/monedas/data/models/monedas_response_model.dart';
import '../../features/movimientos/data/models/movimientos_request_model.dart';
import '../../features/movimientos/data/models/movimientos_response_model.dart';
import '../../features/opciones_menu/data/models/opciones_menu_request_model.dart';
import '../../features/opciones_menu/data/models/opciones_menu_response_model.dart';
import '../../features/pagos/data/models/pagos_request_model.dart';
import '../../features/pagos/data/models/pagos_response_model.dart';
import '../../features/paises/data/models/paises_request_model.dart';
import '../../features/paises/data/models/paises_response_model.dart';
import '../../features/parametros/data/models/parametros_request_model.dart';
import '../../features/parametros/data/models/parametros_response_model.dart';
import '../../features/precios/data/models/precios_request_model.dart';
import '../../features/precios/data/models/precios_response_model.dart';
import '../../features/productos/data/models/productos_request_model.dart';
import '../../features/productos/data/models/productos_response_model.dart';
import '../../features/regiones/data/models/regiones_request_model.dart';
import '../../features/regiones/data/models/regiones_response_model.dart';
import '../../features/reportes/data/models/reportes_request_model.dart';
import '../../features/reportes/data/models/reportes_response_model.dart';
import '../../features/roles/data/models/roles_request_model.dart';
import '../../features/roles/data/models/roles_response_model.dart';
import '../../features/sucursales/data/models/sucursales_request_model.dart';
import '../../features/sucursales/data/models/sucursales_response_model.dart';
import '../../features/tipos_producto/data/models/tipos_producto_request_model.dart';
import '../../features/tipos_producto/data/models/tipos_producto_response_model.dart';
import '../../features/usuarios/data/models/usuarios_request_model.dart';
import '../../features/usuarios/data/models/usuarios_response_model.dart';
import '../../features/ventas/data/models/ventas_request_model.dart';
import '../../features/ventas/data/models/ventas_response_model.dart';
import '../../features/zonas_horarias/data/models/zonas_horarias_request_model.dart';
import '../../features/zonas_horarias/data/models/zonas_horarias_response_model.dart';


const _lookupCiudades = CrudLookupConfig(endpoint: '/api/v1/ciudades', idField: 'ciudId', displayFields: ['ciudNombre', 'ciudCodigoDane']);
const _lookupCuentasVenta = CrudLookupConfig(endpoint: '/api/v1/cuentasventa', idField: 'cuveId', displayFields: ['cuevNumero', 'cuevDescripcion', 'cuevTotal']);
const _lookupEmpresas = CrudLookupConfig(endpoint: '/api/v1/empresas', idField: 'emprId', displayFields: ['empreNombreComercial', 'emprRazonSocial', 'emprIdentificacion']);
const _lookupMarcas = CrudLookupConfig(endpoint: '/api/v1/marcas', idField: 'mrcaId', displayFields: ['mrcaNombre', 'mrcaIdentificacion']);
const _lookupMediosPago = CrudLookupConfig(endpoint: '/api/v1/mediospago', idField: 'mepaId', displayFields: ['mepaNombre', 'mepaDescripcion']);
const _lookupMenus = CrudLookupConfig(endpoint: '/api/v1/menus', idField: 'menuId', displayFields: ['menuNombre', 'menuParametro']);
const _lookupMesas = CrudLookupConfig(endpoint: '/api/v1/mesas', idField: 'mesaId', displayFields: ['mesaNumero', 'mesaEstado']);
const _lookupMonedas = CrudLookupConfig(endpoint: '/api/v1/monedas', idField: 'moneId', displayFields: ['moneCodigoiso', 'moneNombre', 'moneSimbolo']);
const _lookupPaises = CrudLookupConfig(endpoint: '/api/v1/paises', idField: 'paisId', displayFields: ['paisNombre', 'paisCodigo']);
const _lookupPrecios = CrudLookupConfig(endpoint: '/api/v1/precios', idField: 'precId', displayFields: ['precId', 'prodId', 'precValorVenta']);
const _lookupProductos = CrudLookupConfig(endpoint: '/api/v1/productos', idField: 'prodId', displayFields: ['prodNombre', 'prodDescripcion', 'sucuId']);
const _lookupRegiones = CrudLookupConfig(endpoint: '/api/v1/regiones', idField: 'regiId', displayFields: ['regiNombre', 'regiCodigo']);
const _lookupRoles = CrudLookupConfig(endpoint: '/api/v1/roles', idField: 'roleId', displayFields: ['roleNombre', 'roleDescripcion']);
const _lookupSucursales = CrudLookupConfig(endpoint: '/api/v1/sucursales', idField: 'sucuId', displayFields: ['sucuNombre', 'sucuCodigoInterno']);
const _lookupTiposProducto = CrudLookupConfig(endpoint: '/api/v1/tiposproducto', idField: 'tpprId', displayFields: ['tpprNombre', 'tpprDescripcion']);
const _lookupVentas = CrudLookupConfig(endpoint: '/api/v1/ventas', idField: 'ventId', displayFields: ['ventId', 'ventEstado', 'ventFecha']);
const _lookupTiposIdentificacion = CrudLookupConfig(endpoint: '/api/v1/tiposidentificacion', idField: 'tiidId', displayFields: ['tiidNombre', 'tiidDescripcion']);
const _lookupTiposUsuario = CrudLookupConfig(endpoint: '/api/v1/tiposusuario', idField: 'tiusId', displayFields: ['tiusNombre', 'tiusDescripcion']);
const _lookupTiposMovimiento = CrudLookupConfig(endpoint: '/api/v1/tiposmovimiento', idField: 'timoId', displayFields: ['timoNombre', 'timoDescripcion']);
const _lookupTiposAutenticacion = CrudLookupConfig(endpoint: '/api/v1/tiposautenticacion', idField: 'tiauId', displayFields: ['tiauNombre', 'tiauDescripcion']);
const _lookupUsuarios = CrudLookupConfig(endpoint: '/api/v1/usuarios', idField: 'usuaId', displayFields: ['usuaPrimerNombre', 'usuaPrimerApellido', 'usuaEmail']);
const _lookupZonasHorarias = CrudLookupConfig(endpoint: '/api/v1/zonashorarias', idField: 'zohoId', displayFields: ['zohoNombre', 'zohoAbreviatura', 'zohoOffsetOut']);

final ciudadesConfig = CrudModuleConfig<CiudadesResponseModel>(
  key: 'ciudades',
  title: 'Ciudades',
  basePath: '/api/v1/ciudades',
  idField: 'ciudId',
  fields: const [
    CrudField(name: 'ciudId', label: 'Ciud Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'regiId', label: 'Región', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupRegiones),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupZonasHorarias),
    CrudField(name: 'ciudNombre', label: 'Ciudad', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'ciudCodigoDane', label: 'Código DANE', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'ciudCodigoPostal', label: 'Código postal', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'ciudEstado', label: 'Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'ciudRegistradoPor', label: 'Registrado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'ciudFechaCambio', label: 'Fecha de cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'ciudCodigoDane', label: 'Código DANE', type: CrudFieldType.text, required: true),
    CrudField(name: 'ciudCodigoPostal', label: 'Código postal', type: CrudFieldType.text, required: true),
    CrudField(name: 'ciudEstado', label: 'Estado', type: CrudFieldType.number, required: true),
    CrudField(name: 'ciudNombre', label: 'Ciudad', type: CrudFieldType.text, required: true),
    CrudField(name: 'regiId', label: 'Región', type: CrudFieldType.number, required: true, lookup: _lookupRegiones),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, lookup: _lookupZonasHorarias),
  ],
  fromJson: CiudadesResponseModel.fromJson,
  toJson: (CiudadesResponseModel model) => model.toJson(),
);

final cuentasventaConfig = CrudModuleConfig<CuentasVentaResponseModel>(
  key: 'cuentas_venta',
  title: 'Cuentas de venta',
  basePath: '/api/v1/cuentasventa',
  idField: 'cuveId',
  fields: const [
    CrudField(name: 'cuveId', label: 'Cuve Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'ventId', label: 'Venta', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupVentas),
    CrudField(name: 'cuevNumero', label: 'Cuenta', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'cuevDescripcion', label: 'Descripción', type: CrudFieldType.text, required: false, readOnly: false),
    CrudField(name: 'cuevTotal', label: 'Total', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'cuevPropina', label: 'Propina', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'cuevEstado', label: 'Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'cuevRegistradoPor', label: 'Cuev Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'cuevFechaCambio', label: 'Cuev Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'cuevEstado', label: 'Estado', type: CrudFieldType.number, required: true),
    CrudField(name: 'cuevNumero', label: 'Cuenta', type: CrudFieldType.number, required: true),
    CrudField(name: 'cuevDescripcion', label: 'Descripción', type: CrudFieldType.text, required: false),
    CrudField(name: 'cuevPropina', label: 'Propina', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'cuevTotal', label: 'Total', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'ventId', label: 'Venta', type: CrudFieldType.number, required: true, lookup: _lookupVentas),
  ],
  fromJson: CuentasVentaResponseModel.fromJson,
  toJson: (CuentasVentaResponseModel model) => model.toJson(),
);

final detallecuentaventaConfig = CrudModuleConfig<DetalleCuentaVentaResponseModel>(
  key: 'detalle_cuenta_venta',
  title: 'Productos por cuenta',
  basePath: '/api/v1/detallecuentaventa',
  idField: 'decvId',
  fields: const [
    CrudField(name: 'decvId', label: 'Decv Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'cuveId', label: 'Cuenta de venta', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupCuentasVenta),
    CrudField(name: 'precId', label: 'Precio', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupPrecios),
    CrudField(name: 'decvCantidad', label: 'Decv Cantidad', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'decvSubtotal', label: 'Decv Subtotal', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'decvFechaCambio', label: 'Decv Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
    CrudField(name: 'decvRegistradoPor', label: 'Decv Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'cuveId', label: 'Cuenta de venta', type: CrudFieldType.number, required: true, lookup: _lookupCuentasVenta),
    CrudField(name: 'decvCantidad', label: 'Decv Cantidad', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'decvSubtotal', label: 'Decv Subtotal', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'precId', label: 'Precio', type: CrudFieldType.number, required: true, lookup: _lookupPrecios),
  ],
  fromJson: DetalleCuentaVentaResponseModel.fromJson,
  toJson: (DetalleCuentaVentaResponseModel model) => model.toJson(),
);

final empresasConfig = CrudModuleConfig<EmpresasResponseModel>(
  key: 'empresas',
  title: 'Empresas',
  basePath: '/api/v1/empresas',
  idField: 'emprId',
  fields: const [
    CrudField(name: 'emprId', label: 'Empr Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'tiidId', label: 'Tipo de identificación', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupTiposIdentificacion),
    CrudField(name: 'paisIdtelefono', label: 'País teléfono', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupPaises),
    CrudField(name: 'ciudId', label: 'Ciudad', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupCiudades),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupZonasHorarias),
    CrudField(name: 'empreNombreComercial', label: 'Nombre comercial', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'emprRazonSocial', label: 'Razón social', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'emprIdentificacion', label: 'Identificación', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'emprDireccion', label: 'Empr Direccion', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'emprCodigoPostal', label: 'Empr Codigo Postal', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'emprTelefono', label: 'Empr Telefono', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'emprCorreoElectronico', label: 'Correo electrónico', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'emprSitioWeb', label: 'Sitio web', type: CrudFieldType.text, required: false, readOnly: false),
    CrudField(name: 'emprLogo', label: 'Logo', type: CrudFieldType.text, required: false, readOnly: false),
    CrudField(name: 'emprEstado', label: 'Empr Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'emprRegistradoPor', label: 'Empr Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'emprFechaCambio', label: 'Empr Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'ciudId', label: 'Ciudad', type: CrudFieldType.number, required: true, lookup: _lookupCiudades),
    CrudField(name: 'emprCorreoElectronico', label: 'Correo electrónico', type: CrudFieldType.text, required: true),
    CrudField(name: 'emprDireccion', label: 'Empr Direccion', type: CrudFieldType.text, required: true),
    CrudField(name: 'emprEstado', label: 'Empr Estado', type: CrudFieldType.number, required: true),
    CrudField(name: 'emprIdentificacion', label: 'Identificación', type: CrudFieldType.text, required: true),
    CrudField(name: 'emprRazonSocial', label: 'Razón social', type: CrudFieldType.text, required: true),
    CrudField(name: 'emprTelefono', label: 'Empr Telefono', type: CrudFieldType.text, required: true),
    CrudField(name: 'empreNombreComercial', label: 'Nombre comercial', type: CrudFieldType.text, required: true),
    CrudField(name: 'paisIdtelefono', label: 'País teléfono', type: CrudFieldType.number, required: true, lookup: _lookupPaises),
    CrudField(name: 'tiidId', label: 'Tipo de identificación', type: CrudFieldType.number, required: true, lookup: _lookupTiposIdentificacion),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, lookup: _lookupZonasHorarias),
    CrudField(name: 'emprCodigoPostal', label: 'Empr Codigo Postal', type: CrudFieldType.text, required: true),
    CrudField(name: 'emprSitioWeb', label: 'Sitio web', type: CrudFieldType.text, required: false),
    CrudField(name: 'emprLogo', label: 'Logo', type: CrudFieldType.text, required: false),
  ],
  fromJson: EmpresasResponseModel.fromJson,
  toJson: (EmpresasResponseModel model) => model.toJson(),
);

final inventarioConfig = CrudModuleConfig<InventarioResponseModel>(
  key: 'inventario',
  title: 'Conteo de inventario',
  basePath: '/api/v1/inventario',
  idField: 'invtId',
  fields: const [
    CrudField(name: 'invtId', label: 'Invt Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'prodId', label: 'Producto', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupProductos),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupSucursales),
    CrudField(name: 'invtCantidad', label: 'Invt Cantidad', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'invtFecha', label: 'Invt Fecha', type: CrudFieldType.dateTime, required: true, readOnly: false),
    CrudField(name: 'invtRegistradoPor', label: 'Invt Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'invtFechaCambio', label: 'Invt Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'invtCantidad', label: 'Invt Cantidad', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'invtFecha', label: 'Invt Fecha', type: CrudFieldType.dateTime, required: true),
    CrudField(name: 'prodId', label: 'Producto', type: CrudFieldType.number, required: true, lookup: _lookupProductos),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, lookup: _lookupSucursales),
  ],
  fromJson: InventarioResponseModel.fromJson,
  toJson: (InventarioResponseModel model) => model.toJson(),
);

final marcasConfig = CrudModuleConfig<MarcasResponseModel>(
  key: 'marcas',
  title: 'Parametrización de marcas',
  basePath: '/api/v1/marcas',
  idField: 'mrcaId',
  fields: const [
    CrudField(name: 'mrcaId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'mrcaNombre', label: 'Marca', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'mrcaIdentificacion', label: 'Identificación', type: CrudFieldType.text, required: false, readOnly: false),
    CrudField(name: 'mrcaLogo', label: 'Logo', type: CrudFieldType.image, required: false, readOnly: false),
    CrudField(name: 'mrcaCreadoPor', label: 'Creado por', type: CrudFieldType.text, required: true, readOnly: true),
    CrudField(name: 'mrcaFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'mrcaNombre', label: 'Marca', type: CrudFieldType.text, required: true),
    CrudField(name: 'mrcaIdentificacion', label: 'Identificación', type: CrudFieldType.text, required: false),
    CrudField(name: 'mrcaLogo', label: 'Logo', type: CrudFieldType.image, required: false),
  ],
  fromJson: MarcasResponseModel.fromJson,
  toJson: (MarcasResponseModel model) => model.toJson(),
);

final mediospagoConfig = CrudModuleConfig<MediosPagoResponseModel>(
  key: 'medios_pago',
  title: 'Medios de pago por sucursal',
  basePath: '/api/v1/mediospago',
  idField: 'mepaId',
  allowCreate: false,
  allowDelete: false,
  fields: const [
    CrudField(name: 'mepaId', label: 'Medio Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'sucursalMedioPagoId', label: 'Configuración Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'sucuId', label: 'Sucursal Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'mepaNombre', label: 'Medio de pago', type: CrudFieldType.text, required: true, readOnly: true),
    CrudField(name: 'mepaDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true, readOnly: true),
    CrudField(name: 'mepaEstado', label: 'Activo en mi sucursal', type: CrudFieldType.boolean, required: true, readOnly: false),
    CrudField(name: 'mepaQr', label: 'QR de mi sucursal', type: CrudFieldType.image, required: false, readOnly: false),
    CrudField(name: 'mepaRegistradoPor', label: 'Actualizado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'mepaFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: false, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'mepaNombre', label: 'Medio de pago', type: CrudFieldType.text, required: true, readOnly: true),
    CrudField(name: 'mepaDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true, readOnly: true),
    CrudField(name: 'mepaEstado', label: 'Activo en mi sucursal', type: CrudFieldType.boolean, required: true),
    CrudField(name: 'mepaQr', label: 'QR de mi sucursal', type: CrudFieldType.image, required: false),
  ],
  fromJson: MediosPagoResponseModel.fromJson,
  toJson: (MediosPagoResponseModel model) => model.toJson(),
);

final menusConfig = CrudModuleConfig<MenusResponseModel>(
  key: 'menus',
  title: 'Menús',
  basePath: '/api/v1/menus',
  idField: 'menuId',
  fields: const [
    CrudField(name: 'menuId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'menuNombre', label: 'Menú', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'menuDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'menuParametro', label: 'Parámetro de navegación', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'menuGrupoCodigo', label: 'Código de grupo', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'menuGrupoNombre', label: 'Grupo', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'menuGrupoIcono', label: 'Icono del grupo', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'menuGrupoOrden', label: 'Orden del grupo', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'menuOrden', label: 'Orden dentro del grupo', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'menuVisible', label: 'Visible (1 sí / 0 no)', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'menuBottomCodigo', label: 'Código inferior', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'menuBottomNombre', label: 'Nombre inferior', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'menuBottomIcono', label: 'Icono inferior', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'menuBottomOrden', label: 'Orden inferior', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'menuBottomVisible', label: 'Acceso inferior (1 sí / 0 no)', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'menuBottomPrincipal', label: 'Destino principal inferior (1 sí / 0 no)', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'menuRegistradoPor', label: 'Registrado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'menuFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'menuDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true),
    CrudField(name: 'menuNombre', label: 'Menú', type: CrudFieldType.text, required: true),
    CrudField(name: 'menuParametro', label: 'Parámetro de navegación', type: CrudFieldType.text, required: true),
    CrudField(name: 'menuGrupoCodigo', label: 'Código de grupo', type: CrudFieldType.text, required: true),
    CrudField(name: 'menuGrupoNombre', label: 'Grupo', type: CrudFieldType.text, required: true),
    CrudField(name: 'menuGrupoIcono', label: 'Icono del grupo', type: CrudFieldType.text, required: true),
    CrudField(name: 'menuGrupoOrden', label: 'Orden del grupo', type: CrudFieldType.number, required: true),
    CrudField(name: 'menuOrden', label: 'Orden dentro del grupo', type: CrudFieldType.number, required: true),
    CrudField(name: 'menuVisible', label: 'Visible (1 sí / 0 no)', type: CrudFieldType.number, required: true),
    CrudField(name: 'menuBottomCodigo', label: 'Código inferior', type: CrudFieldType.text, required: true),
    CrudField(name: 'menuBottomNombre', label: 'Nombre inferior', type: CrudFieldType.text, required: true),
    CrudField(name: 'menuBottomIcono', label: 'Icono inferior', type: CrudFieldType.text, required: true),
    CrudField(name: 'menuBottomOrden', label: 'Orden inferior', type: CrudFieldType.number, required: true),
    CrudField(name: 'menuBottomVisible', label: 'Acceso inferior (1 sí / 0 no)', type: CrudFieldType.number, required: true),
    CrudField(name: 'menuBottomPrincipal', label: 'Destino principal inferior (1 sí / 0 no)', type: CrudFieldType.number, required: true),
  ],
  fromJson: MenusResponseModel.fromJson,
  toJson: (MenusResponseModel model) => model.toJson(),
);

final mesasConfig = CrudModuleConfig<MesasResponseModel>(
  key: 'mesas',
  title: 'Mesas',
  basePath: '/api/v1/mesas',
  idField: 'mesaId',
  fields: const [
    CrudField(name: 'mesaId', label: 'Mesa Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupSucursales),
    CrudField(name: 'mesaNumero', label: 'Mesa', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'mesaEstado', label: 'Mesa Estado', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'mesaDescripcion', label: 'Descripción', type: CrudFieldType.text, required: false, readOnly: false),
    CrudField(name: 'mesaFoto', label: 'Foto', type: CrudFieldType.image, required: false, readOnly: false),
    CrudField(name: 'mesaRegistradoPor', label: 'Mesa Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'mesaFechaCambio', label: 'Mesa Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'mesaEstado', label: 'Mesa Estado', type: CrudFieldType.text, required: true),
    CrudField(name: 'mesaNumero', label: 'Mesa', type: CrudFieldType.number, required: true),
    CrudField(name: 'mesaDescripcion', label: 'Descripción', type: CrudFieldType.text, required: false),
    CrudField(name: 'mesaFoto', label: 'Foto de la mesa', type: CrudFieldType.image, required: false),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, lookup: _lookupSucursales),
  ],
  fromJson: MesasResponseModel.fromJson,
  toJson: (MesasResponseModel model) => model.toJson(),
);

final monedasConfig = CrudModuleConfig<MonedasResponseModel>(
  key: 'monedas',
  title: 'Monedas',
  basePath: '/api/v1/monedas',
  idField: 'moneId',
  fields: const [
    CrudField(name: 'moneId', label: 'Mone Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'moneCodigoiso', label: 'Mone Codigoiso', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'moneNombre', label: 'Moneda', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'moneSimbolo', label: 'Mone Simbolo', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'moneDecimales', label: 'Mone Decimales', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'moneEstado', label: 'Mone Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'moneRegistradoPor', label: 'Mone Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'moneFechaCambio', label: 'Mone Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'moneCodigoiso', label: 'Mone Codigoiso', type: CrudFieldType.text, required: true),
    CrudField(name: 'moneDecimales', label: 'Mone Decimales', type: CrudFieldType.number, required: true),
    CrudField(name: 'moneEstado', label: 'Mone Estado', type: CrudFieldType.number, required: true),
    CrudField(name: 'moneNombre', label: 'Moneda', type: CrudFieldType.text, required: true),
    CrudField(name: 'moneSimbolo', label: 'Mone Simbolo', type: CrudFieldType.text, required: true),
  ],
  fromJson: MonedasResponseModel.fromJson,
  toJson: (MonedasResponseModel model) => model.toJson(),
);

final movimientosConfig = CrudModuleConfig<MovimientosResponseModel>(
  key: 'movimientos',
  title: 'Movimientos de inventario',
  basePath: '/api/v1/movimientos',
  idField: 'moviId',
  fields: const [
    CrudField(name: 'moviId', label: 'Movi Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'prodId', label: 'Producto', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupProductos),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupSucursales),
    CrudField(name: 'timoId', label: 'Tipo de movimiento', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupTiposMovimiento),
    CrudField(name: 'moviCantidadCapturada', label: 'Cantidad registrada', type: CrudFieldType.decimal, required: true, readOnly: true),
    CrudField(name: 'moviUnidad', label: 'Unidad de captura', type: CrudFieldType.text, required: true, readOnly: true, options: {
      'UNIDAD': 'Unidad',
      'PRESENTACION_COMPRA': 'Paquete, caja o presentación de compra',
    }),
    CrudField(name: 'moviFactorConversion', label: 'Unidades por presentación', type: CrudFieldType.decimal, required: true, readOnly: true),
    CrudField(name: 'moviCantidadInventario', label: 'Unidades aplicadas al inventario', type: CrudFieldType.decimal, required: true, readOnly: true),
    CrudField(name: 'moviMotivo', label: 'Movi Motivo', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'moviReferencia', label: 'Referencia', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'moviOperacion', label: 'Sentido aplicado', type: CrudFieldType.text, required: true, readOnly: true, options: {'ENTRADA': 'Entrada · aumenta inventario', 'SALIDA': 'Salida · disminuye inventario'}),
    CrudField(name: 'moviRegistradoPor', label: 'Movi Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'moviFechaCambio', label: 'Movi Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'moviCantidad', label: 'Cantidad a registrar', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'moviUnidad', label: 'Registrar cantidad como', type: CrudFieldType.text, required: true, options: {
      'UNIDAD': 'Unidades individuales',
      'PRESENTACION_COMPRA': 'Paquetes, cajas o presentación de compra',
    }),
    CrudField(name: 'moviMotivo', label: 'Movi Motivo', type: CrudFieldType.text, required: true),
    CrudField(name: 'moviReferencia', label: 'Referencia', type: CrudFieldType.text, required: true),
    CrudField(name: 'moviOperacion', label: 'Sentido (obligatorio solo para ajustes)', type: CrudFieldType.text, required: false, options: {'ENTRADA': 'Entrada · aumentar inventario', 'SALIDA': 'Salida · disminuir inventario'}),
    CrudField(name: 'prodId', label: 'Producto', type: CrudFieldType.number, required: true, lookup: _lookupProductos),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, lookup: _lookupSucursales),
    CrudField(name: 'timoId', label: 'Tipo de movimiento', type: CrudFieldType.number, required: true, lookup: _lookupTiposMovimiento),
  ],
  fromJson: MovimientosResponseModel.fromJson,
  toJson: (MovimientosResponseModel model) => model.toJson(),
);

final opcionesmenuConfig = CrudModuleConfig<OpcionesMenuResponseModel>(
  key: 'opciones_menu',
  title: 'Opciones de menú',
  basePath: '/api/v1/opcionesmenu',
  idField: 'opmeId',
  fields: const [
    CrudField(name: 'opmeId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'menuId', label: 'Menú', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupMenus),
    CrudField(name: 'roleId', label: 'Rol', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupRoles),
    CrudField(name: 'opmeNombre', label: 'Opción', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'opmeDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'opmeCodigotraduccion', label: 'Código de traducción', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'opmeRegistradoPor', label: 'Registrado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'opmeFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'menuId', label: 'Menú', type: CrudFieldType.number, required: true, lookup: _lookupMenus),
    CrudField(name: 'opmeCodigotraduccion', label: 'Código de traducción', type: CrudFieldType.text, required: true),
    CrudField(name: 'opmeDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true),
    CrudField(name: 'opmeNombre', label: 'Opción', type: CrudFieldType.text, required: true),
    CrudField(name: 'roleId', label: 'Rol', type: CrudFieldType.number, required: true, lookup: _lookupRoles),
  ],
  fromJson: OpcionesMenuResponseModel.fromJson,
  toJson: (OpcionesMenuResponseModel model) => model.toJson(),
);

final pagosConfig = CrudModuleConfig<PagosResponseModel>(
  key: 'pagos',
  title: 'Pagos',
  basePath: '/api/v1/pagos',
  idField: 'pacvId',
  fields: const [
    CrudField(name: 'pacvId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'cuveId', label: 'Cuenta de venta', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupCuentasVenta),
    CrudField(name: 'mepaId', label: 'Medio de pago', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupMediosPago),
    CrudField(name: 'pacvMonto', label: 'Monto', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'pacvObservacion', label: 'Observación', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'pacvRegistradoPor', label: 'Registrado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'pacvFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'cuveId', label: 'Cuenta de venta', type: CrudFieldType.number, required: true, lookup: _lookupCuentasVenta),
    CrudField(name: 'mepaId', label: 'Medio de pago', type: CrudFieldType.number, required: true, lookup: _lookupMediosPago),
    CrudField(name: 'pacvMonto', label: 'Monto', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'pacvObservacion', label: 'Observación', type: CrudFieldType.decimal, required: true),
  ],
  fromJson: PagosResponseModel.fromJson,
  toJson: (PagosResponseModel model) => model.toJson(),
);

final paisesConfig = CrudModuleConfig<PaisesResponseModel>(
  key: 'paises',
  title: 'Países',
  basePath: '/api/v1/paises',
  idField: 'paisId',
  fields: const [
    CrudField(name: 'paisId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupZonasHorarias),
    CrudField(name: 'paisNombre', label: 'País', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'paisCodigo', label: 'Código', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'paisEstado', label: 'Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'paisRegistradoPor', label: 'Registrado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'paisFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'paisCodigo', label: 'Código', type: CrudFieldType.text, required: true),
    CrudField(name: 'paisEstado', label: 'Estado', type: CrudFieldType.number, required: true),
    CrudField(name: 'paisNombre', label: 'País', type: CrudFieldType.text, required: true),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, lookup: _lookupZonasHorarias),
  ],
  fromJson: PaisesResponseModel.fromJson,
  toJson: (PaisesResponseModel model) => model.toJson(),
);

final parametrosConfig = CrudModuleConfig<ParametrosResponseModel>(
  key: 'parametros',
  title: 'Parámetros',
  basePath: '/api/v1/parametros',
  idField: 'paraId',
  fields: const [
    CrudField(name: 'paraId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'emprId', label: 'Empresa de aplicación (opcional)', type: CrudFieldType.number, required: false, readOnly: false, lookup: _lookupEmpresas),
    CrudField(name: 'sucuId', label: 'Sucursal de aplicación (opcional)', type: CrudFieldType.number, required: false, readOnly: false, lookup: _lookupSucursales),
    CrudField(name: 'paraCodigo', label: 'Código', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'paraNombre', label: 'Nombre', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'paraDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'paraTipoDato', label: 'Tipo de dato', type: CrudFieldType.text, required: true, readOnly: false, options: {'TEXTO': 'Texto', 'NUMERO': 'Número', 'DECIMAL': 'Decimal', 'BOOLEANO': 'Booleano', 'FECHA': 'Fecha', 'JSON': 'JSON'}),
    CrudField(name: 'paraValor', label: 'Valor configurado', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'paraValorDefecto', label: 'Valor por defecto (opcional)', type: CrudFieldType.text, required: false, readOnly: false),
    CrudField(name: 'paraGrupo', label: 'Grupo', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'paraEditable', label: 'Editable', type: CrudFieldType.number, required: true, readOnly: false, options: {'1': 'Sí', '0': 'No'}),
    CrudField(name: 'paraEstado', label: 'Estado', type: CrudFieldType.number, required: true, readOnly: false, options: {'1': 'Activo', '0': 'Inactivo'}),
    CrudField(name: 'paraRegistradoPor', label: 'Registrado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'paraFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'paraCodigo', label: 'Código', type: CrudFieldType.text, required: true),
    CrudField(name: 'paraDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true),
    CrudField(name: 'paraEditable', label: 'Editable', type: CrudFieldType.number, required: true, options: {'1': 'Sí', '0': 'No'}),
    CrudField(name: 'paraEstado', label: 'Estado', type: CrudFieldType.number, required: true, options: {'1': 'Activo', '0': 'Inactivo'}),
    CrudField(name: 'paraGrupo', label: 'Grupo', type: CrudFieldType.text, required: true),
    CrudField(name: 'paraNombre', label: 'Nombre', type: CrudFieldType.text, required: true),
    CrudField(name: 'paraTipoDato', label: 'Tipo de dato', type: CrudFieldType.text, required: true, options: {'TEXTO': 'Texto', 'NUMERO': 'Número', 'DECIMAL': 'Decimal', 'BOOLEANO': 'Booleano', 'FECHA': 'Fecha', 'JSON': 'JSON'}),
    CrudField(name: 'paraValor', label: 'Valor configurado', type: CrudFieldType.text, required: true),
    CrudField(name: 'emprId', label: 'Empresa de aplicación (opcional)', type: CrudFieldType.number, required: false, lookup: _lookupEmpresas),
    CrudField(name: 'sucuId', label: 'Sucursal de aplicación (opcional)', type: CrudFieldType.number, required: false, lookup: _lookupSucursales),
    CrudField(name: 'paraValorDefecto', label: 'Valor por defecto (opcional)', type: CrudFieldType.text, required: false),
  ],
  fromJson: ParametrosResponseModel.fromJson,
  toJson: (ParametrosResponseModel model) => model.toJson(),
);

final preciosConfig = CrudModuleConfig<PreciosResponseModel>(
  key: 'precios',
  title: 'Precios',
  basePath: '/api/v1/precios',
  idField: 'precId',
  fields: const [
    CrudField(name: 'precId', label: 'Prec Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'prodId', label: 'Producto', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupProductos),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupSucursales),
    CrudField(name: 'precEstado', label: 'Prec Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'precValorVenta', label: 'Prec Valor Venta', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'precValorCompra', label: 'Prec Valor Compra', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'precFechaInicia', label: 'Prec Fecha Inicia', type: CrudFieldType.dateTime, required: true, readOnly: false),
    CrudField(name: 'precFechaFinaliza', label: 'Prec Fecha Finaliza', type: CrudFieldType.dateTime, required: true, readOnly: false),
    CrudField(name: 'precAplicaImpuesto', label: 'Aplica impuesto', type: CrudFieldType.number, required: false, readOnly: false),
    CrudField(name: 'precPorcentajeImpuesto', label: 'Porcentaje impuesto', type: CrudFieldType.decimal, required: false, readOnly: false),
    CrudField(name: 'precValorImpuesto', label: 'Valor impuesto', type: CrudFieldType.decimal, required: false, readOnly: false),
    CrudField(name: 'precRegistradoPor', label: 'Prec Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'precFechaCambio', label: 'Prec Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'precEstado', label: 'Prec Estado', type: CrudFieldType.number, required: true),
    CrudField(name: 'precFechaInicia', label: 'Prec Fecha Inicia', type: CrudFieldType.dateTime, required: true),
    CrudField(name: 'precValorCompra', label: 'Prec Valor Compra', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'precValorVenta', label: 'Prec Valor Venta', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'prodId', label: 'Producto', type: CrudFieldType.number, required: true, lookup: _lookupProductos),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, lookup: _lookupSucursales),
    CrudField(name: 'precFechaFinaliza', label: 'Prec Fecha Finaliza', type: CrudFieldType.dateTime, required: false),
    CrudField(name: 'precAplicaImpuesto', label: 'Aplica impuesto', type: CrudFieldType.number, required: false),
    CrudField(name: 'precPorcentajeImpuesto', label: 'Porcentaje impuesto', type: CrudFieldType.decimal, required: false),
    CrudField(name: 'precValorImpuesto', label: 'Valor impuesto', type: CrudFieldType.decimal, required: false),
  ],
  fromJson: PreciosResponseModel.fromJson,
  toJson: (PreciosResponseModel model) => model.toJson(),
);

final productosConfig = CrudModuleConfig<ProductosResponseModel>(
  key: 'productos',
  title: 'Productos',
  basePath: '/api/v1/productos',
  idField: 'prodId',
  fields: const [
    CrudField(name: 'prodId', label: 'Código de producto', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupSucursales),
    CrudField(name: 'tpprId', label: 'Tipo de producto', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupTiposProducto),
    CrudField(name: 'mrcaId', label: 'Marca', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupMarcas),
    CrudField(name: 'prodNombre', label: 'Producto', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'prodDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'prodFoto', label: 'Foto', type: CrudFieldType.image, required: false, readOnly: false),
    CrudField(name: 'prodFechaVencimiento', label: 'Fecha de vencimiento', type: CrudFieldType.dateTime, required: false, readOnly: false),
    CrudField(name: 'prodCreadoPor', label: 'Prod Creado Por', type: CrudFieldType.text, required: true, readOnly: true),
    CrudField(name: 'prodFechaCambio', label: 'Prod Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'mrcaId', label: 'Marca', type: CrudFieldType.number, required: true, lookup: _lookupMarcas),
    CrudField(name: 'prodDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true),
    CrudField(name: 'prodNombre', label: 'Producto', type: CrudFieldType.text, required: true),
    CrudField(name: 'prodFoto', label: 'Foto del producto', type: CrudFieldType.image, required: false),
    CrudField(name: 'prodFechaVencimiento', label: 'Fecha de vencimiento', type: CrudFieldType.dateTime, required: false),
    CrudField(name: 'tpprId', label: 'Tipo de producto', type: CrudFieldType.number, required: true, lookup: _lookupTiposProducto),
    CrudField(name: 'prodId', label: 'Código de producto', type: CrudFieldType.number, required: false),
    CrudField(name: 'sucuId', label: 'Sucursal', type: CrudFieldType.number, required: true, lookup: _lookupSucursales),
  ],
  fromJson: ProductosResponseModel.fromJson,
  toJson: (ProductosResponseModel model) => model.toJson(),
);

final regionesConfig = CrudModuleConfig<RegionesResponseModel>(
  key: 'regiones',
  title: 'Regiones',
  basePath: '/api/v1/regiones',
  idField: 'regiId',
  fields: const [
    CrudField(name: 'regiId', label: 'Regi Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'paisId', label: 'País', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupPaises),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupZonasHorarias),
    CrudField(name: 'regiNombre', label: 'Región', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'regiCodigo', label: 'Código', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'regiEstado', label: 'Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'regiRegistradoPor', label: 'Regi Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'regiFechaCambio', label: 'Regi Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'paisId', label: 'País', type: CrudFieldType.number, required: true, lookup: _lookupPaises),
    CrudField(name: 'regiCodigo', label: 'Código', type: CrudFieldType.text, required: true),
    CrudField(name: 'regiNombre', label: 'Región', type: CrudFieldType.text, required: true),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, lookup: _lookupZonasHorarias),
    CrudField(name: 'regiEstado', label: 'Estado', type: CrudFieldType.number, required: true),
  ],
  fromJson: RegionesResponseModel.fromJson,
  toJson: (RegionesResponseModel model) => model.toJson(),
);

final reportesConfig = CrudModuleConfig<ReportesResponseModel>(
  key: 'reportes',
  title: 'Reportes',
  basePath: '/api/v1/reportes',
  idField: 'id',
  fields: const [

  ],
  formFields: const [

  ],
  fromJson: ReportesResponseModel.fromJson,
  toJson: (ReportesResponseModel model) => model.toJson(),
);

final rolesConfig = CrudModuleConfig<RolesResponseModel>(
  key: 'roles',
  title: 'Roles',
  basePath: '/api/v1/roles',
  idField: 'roleId',
  fields: const [
    CrudField(name: 'roleId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'tiusId', label: 'Tipo de usuario', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupTiposUsuario),
    CrudField(name: 'roleNombre', label: 'Rol', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'roleDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'roleRegistradoPor', label: 'Registrado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'roleFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'roleDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true),
    CrudField(name: 'roleNombre', label: 'Rol', type: CrudFieldType.text, required: true),
    CrudField(name: 'tiusId', label: 'Tipo de usuario', type: CrudFieldType.number, required: true, lookup: _lookupTiposUsuario),
  ],
  fromJson: RolesResponseModel.fromJson,
  toJson: (RolesResponseModel model) => model.toJson(),
);

final sucursalesConfig = CrudModuleConfig<SucursalesResponseModel>(
  key: 'sucursales',
  title: 'Sucursales',
  basePath: '/api/v1/sucursales',
  idField: 'sucuId',
  fields: const [
    CrudField(name: 'sucuId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'emprId', label: 'Empresa', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupEmpresas),
    CrudField(name: 'ciudId', label: 'Ciudad', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupCiudades),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupZonasHorarias),
    CrudField(name: 'moneId', label: 'Moneda', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupMonedas),
    CrudField(name: 'paisIdtelefono', label: 'País teléfono', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupPaises),
    CrudField(name: 'sucuNombre', label: 'Sucursal', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'sucuCodigoInterno', label: 'Código interno', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'sucuDireccion', label: 'Dirección', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'sucuTelefono', label: 'Teléfono', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'sucuEstado', label: 'Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'sucuRegistradoPor', label: 'Registrado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'sucuFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'ciudId', label: 'Ciudad', type: CrudFieldType.number, required: true, lookup: _lookupCiudades),
    CrudField(name: 'emprId', label: 'Empresa', type: CrudFieldType.number, required: true, lookup: _lookupEmpresas),
    CrudField(name: 'moneId', label: 'Moneda', type: CrudFieldType.number, required: true, lookup: _lookupMonedas),
    CrudField(name: 'paisIdtelefono', label: 'País teléfono', type: CrudFieldType.number, required: true, lookup: _lookupPaises),
    CrudField(name: 'sucuCodigoInterno', label: 'Código interno', type: CrudFieldType.text, required: true),
    CrudField(name: 'sucuDireccion', label: 'Dirección', type: CrudFieldType.text, required: true),
    CrudField(name: 'sucuEstado', label: 'Estado', type: CrudFieldType.number, required: true),
    CrudField(name: 'sucuNombre', label: 'Sucursal', type: CrudFieldType.text, required: true),
    CrudField(name: 'sucuTelefono', label: 'Teléfono', type: CrudFieldType.text, required: true),
    CrudField(name: 'zohoId', label: 'Zona horaria', type: CrudFieldType.number, required: true, lookup: _lookupZonasHorarias),
  ],
  fromJson: SucursalesResponseModel.fromJson,
  toJson: (SucursalesResponseModel model) => model.toJson(),
);

final tiposmovimientoConfig = CrudModuleConfig<Map<String, dynamic>>(
  key: 'tipos_movimiento',
  title: 'Tipos de movimiento',
  basePath: '/api/v1/tiposmovimiento',
  idField: 'timoId',
  fields: const [
    CrudField(name: 'timoId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'timoNombre', label: 'Tipo de movimiento', type: CrudFieldType.text, required: true),
    CrudField(name: 'timoDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true),
    CrudField(name: 'timoOperacion', label: 'Comportamiento', type: CrudFieldType.text, required: true, options: {
      'ENTRADA': 'Entrada · aumenta inventario',
      'SALIDA': 'Salida · disminuye inventario',
      'AJUSTE': 'Ajuste · el usuario elige el sentido',
    }),
    CrudField(name: 'timoPermitePresentacionCompra', label: 'Permite registrar paquetes o cajas', type: CrudFieldType.boolean, required: false),
    CrudField(name: 'timoRegistradoPor', label: 'Registrado por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'timoFechaCambio', label: 'Última actualización', type: CrudFieldType.dateTime, required: false, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'timoNombre', label: 'Nombre', type: CrudFieldType.text, required: true),
    CrudField(name: 'timoDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true),
    CrudField(name: 'timoOperacion', label: 'Comportamiento en inventario', type: CrudFieldType.text, required: true, options: {
      'ENTRADA': 'Entrada · aumenta inventario',
      'SALIDA': 'Salida · disminuye inventario',
      'AJUSTE': 'Ajuste · preguntar si aumenta o disminuye',
    }),
    CrudField(name: 'timoPermitePresentacionCompra', label: 'Capturar por paquete/caja', type: CrudFieldType.boolean, required: false),
  ],
  fromJson: _mapFromJson,
  toJson: _mapToJson,
  allowDelete: false,
);

Map<String, dynamic> _mapFromJson(Map<String, dynamic> json) => Map<String, dynamic>.from(json);
Map<String, dynamic> _mapToJson(Map<String, dynamic> model) => Map<String, dynamic>.from(model);

final tiposproductoConfig = CrudModuleConfig<TiposProductoResponseModel>(
  key: 'tipos_producto',
  title: 'Parametrización de tipos de producto',
  basePath: '/api/v1/tiposproducto',
  idField: 'tpprId',
  fields: const [
    CrudField(name: 'tpprId', label: 'ID', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'tpprNombre', label: 'Tipo de producto', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'tpprDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'tpprCreadoPor', label: 'Creado por', type: CrudFieldType.text, required: true, readOnly: true),
    CrudField(name: 'tpprFechaCreacion', label: 'Fecha de creación', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'tpprDescripcion', label: 'Descripción', type: CrudFieldType.text, required: true),
    CrudField(name: 'tpprNombre', label: 'Tipo de producto', type: CrudFieldType.text, required: true),
  ],
  fromJson: TiposProductoResponseModel.fromJson,
  toJson: (TiposProductoResponseModel model) => model.toJson(),
);

final usuariosConfig = CrudModuleConfig<UsuariosResponseModel>(
  key: 'usuarios',
  title: 'Usuarios',
  basePath: '/api/v1/usuarios',
  idField: 'usuaId',
  fields: const [
    CrudField(name: 'usuaId', label: 'Usua Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'ciudId', label: 'Ciudad', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupCiudades),
    CrudField(name: 'emprId', label: 'Empresa', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupEmpresas),
    CrudField(name: 'sucuId', label: 'Sucursal operativa', type: CrudFieldType.number, required: false, readOnly: false, lookup: _lookupSucursales),
    CrudField(name: 'usuaEstado', label: 'Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'usuaBloqueado', label: 'Bloqueo', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'usuaPrimerNombre', label: 'Primer nombre', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'usuaSegundoNombre', label: 'Segundo nombre', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'usuaSegundoApellido', label: 'Segundo apellido', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'usuaPrimerApellido', label: 'Primer apellido', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'usuaEmail', label: 'Correo electrónico', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'usuaFechaNacimiento', label: 'Fecha de nacimiento', type: CrudFieldType.dateTime, required: true, readOnly: false),
    CrudField(name: 'usuaDireccion', label: 'Dirección', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'usuaTelefonoPrincipal', label: 'Teléfono principal', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'usuaTelefonoSecundario', label: 'Teléfono secundario', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'usuaFoto', label: 'Foto de perfil', type: CrudFieldType.image, required: false, readOnly: false),
    CrudField(name: 'usuaRegistradoPor', label: 'Usua Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'usuaFechaCambio', label: 'Usua Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'usuaPrimerNombre', label: 'Primer nombre', type: CrudFieldType.text, required: true),
    CrudField(name: 'usuaSegundoNombre', label: 'Segundo nombre', type: CrudFieldType.text, required: false),
    CrudField(name: 'usuaPrimerApellido', label: 'Primer apellido', type: CrudFieldType.text, required: true),
    CrudField(name: 'usuaSegundoApellido', label: 'Segundo apellido', type: CrudFieldType.text, required: true),
    CrudField(name: 'usuaEmail', label: 'Correo electrónico', type: CrudFieldType.text, required: true),
    CrudField(name: 'ciudId', label: 'Ciudad', type: CrudFieldType.number, required: true, lookup: _lookupCiudades),
    CrudField(name: 'emprId', label: 'Empresa', type: CrudFieldType.number, required: true, lookup: _lookupEmpresas),
    CrudField(name: 'sucuId', label: 'Sucursal operativa', type: CrudFieldType.number, required: false, lookup: _lookupSucursales),
    CrudField(name: 'usuaEstado', label: 'Estado', type: CrudFieldType.number, required: true),
    CrudField(name: 'usuaBloqueado', label: 'Bloqueo', type: CrudFieldType.number, required: true),
    CrudField(name: 'usuaFechaNacimiento', label: 'Fecha de nacimiento', type: CrudFieldType.date, required: false),
    CrudField(name: 'usuaDireccion', label: 'Dirección', type: CrudFieldType.text, required: false),
    CrudField(name: 'usuaTelefonoPrincipal', label: 'Teléfono principal', type: CrudFieldType.text, required: false),
    CrudField(name: 'usuaTelefonoSecundario', label: 'Teléfono secundario', type: CrudFieldType.text, required: false),
    CrudField(name: 'usuaFoto', label: 'Foto de perfil', type: CrudFieldType.image, required: false),
  ],
  fromJson: UsuariosResponseModel.fromJson,
  toJson: (UsuariosResponseModel model) => model.toJson(),
);

final ventasConfig = CrudModuleConfig<VentasResponseModel>(
  key: 'ventas',
  title: 'Ventas',
  basePath: '/api/v1/ventas',
  idField: 'ventId',
  fields: const [
    CrudField(name: 'ventId', label: 'Vent Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'mesaId', label: 'Mesa', type: CrudFieldType.number, required: true, readOnly: false, lookup: _lookupMesas),
    CrudField(name: 'ventFecha', label: 'Vent Fecha', type: CrudFieldType.dateTime, required: true, readOnly: false),
    CrudField(name: 'ventEstado', label: 'Estado de venta', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'ventTotal', label: 'Vent Total', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'ventPropina', label: 'Vent Propina', type: CrudFieldType.decimal, required: true, readOnly: false),
    CrudField(name: 'ventRegistradoPor', label: 'Vent Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'ventFechaCambio', label: 'Vent Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'mesaId', label: 'Mesa', type: CrudFieldType.number, required: true, lookup: _lookupMesas),
    CrudField(name: 'ventEstado', label: 'Estado de venta', type: CrudFieldType.text, required: true),
    CrudField(name: 'ventFecha', label: 'Vent Fecha', type: CrudFieldType.dateTime, required: true),
    CrudField(name: 'ventPropina', label: 'Vent Propina', type: CrudFieldType.decimal, required: true),
    CrudField(name: 'ventTotal', label: 'Vent Total', type: CrudFieldType.decimal, required: true),
  ],
  fromJson: VentasResponseModel.fromJson,
  toJson: (VentasResponseModel model) => model.toJson(),
);

final zonashorariasConfig = CrudModuleConfig<ZonasHorariasResponseModel>(
  key: 'zonas_horarias',
  title: 'Zonas horarias',
  basePath: '/api/v1/zonashorarias',
  idField: 'zohoId',
  fields: const [
    CrudField(name: 'zohoId', label: 'Zoho Id', type: CrudFieldType.number, required: false, readOnly: true),
    CrudField(name: 'zohoNombre', label: 'Zoho Nombre', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'zohoDescripcion', label: 'Zoho Descripcion', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'zohoAbreviatura', label: 'Zoho Abreviatura', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'zohoOffsetOut', label: 'Zoho Offset Out', type: CrudFieldType.text, required: true, readOnly: false),
    CrudField(name: 'zohoEstado', label: 'Zoho Estado', type: CrudFieldType.number, required: true, readOnly: false),
    CrudField(name: 'zohoRegistradoPor', label: 'Zoho Registrado Por', type: CrudFieldType.text, required: false, readOnly: true),
    CrudField(name: 'zohoFechaCambio', label: 'Zoho Fecha Cambio', type: CrudFieldType.dateTime, required: true, readOnly: true),
  ],
  formFields: const [
    CrudField(name: 'zohoAbreviatura', label: 'Zoho Abreviatura', type: CrudFieldType.text, required: true),
    CrudField(name: 'zohoDescripcion', label: 'Zoho Descripcion', type: CrudFieldType.text, required: true),
    CrudField(name: 'zohoEstado', label: 'Zoho Estado', type: CrudFieldType.number, required: true),
    CrudField(name: 'zohoNombre', label: 'Zoho Nombre', type: CrudFieldType.text, required: true),
    CrudField(name: 'zohoOffsetOut', label: 'Zoho Offset Out', type: CrudFieldType.text, required: true),
  ],
  fromJson: ZonasHorariasResponseModel.fromJson,
  toJson: (ZonasHorariasResponseModel model) => model.toJson(),
);

/// Módulos visibles. En producción esta lista puede filtrarse por roles/permisos desde backend.
final moduleRegistry = <CrudModuleConfig<dynamic>>[
  ciudadesConfig,
  cuentasventaConfig,
  detallecuentaventaConfig,
  empresasConfig,
  inventarioConfig,
  marcasConfig,
  mediospagoConfig,
  menusConfig,
  mesasConfig,
  monedasConfig,
  movimientosConfig,
  opcionesmenuConfig,
  pagosConfig,
  paisesConfig,
  parametrosConfig,
  preciosConfig,
  productosConfig,
  regionesConfig,
  rolesConfig,
  sucursalesConfig,
  tiposmovimientoConfig,
  tiposproductoConfig,
  usuariosConfig,
  ventasConfig,
  zonashorariasConfig,
];
