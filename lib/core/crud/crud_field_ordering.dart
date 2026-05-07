import 'crud_field.dart';
import 'crud_module_config.dart';

/// Define el campo humano principal por módulo.
///
/// Esta lista evita que una relación técnica (`paisId`, `regiId`, `emprId`, etc.)
/// aparezca como primer dato visible en tarjetas, tablas o detalles. El primer
/// campo debe ser el más entendible para el usuario final.
const Map<String, String> _preferredPrimaryFields = <String, String>{
  'ciudades': 'ciudNombre',
  'cuentas_venta': 'cuevNumero',
  'detalle_cuenta_venta': 'decvCantidad',
  'empresas': 'empreNombreComercial',
  'inventario': 'invtCantidad',
  'marcas': 'mrcaNombre',
  'medios_pago': 'mepaNombre',
  'menus': 'menuNombre',
  'mesas': 'mesaNumero',
  'monedas': 'moneNombre',
  'movimientos': 'moviMotivo',
  'opciones_menu': 'opmeNombre',
  'pagos': 'pacvMonto',
  'paises': 'paisNombre',
  'parametros': 'paraNombre',
  'precios': 'precValorVenta',
  'productos': 'prodNombre',
  'regiones': 'regiNombre',
  'reportes': 'nombre',
  'roles': 'roleNombre',
  'sucursales': 'sucuNombre',
  'tipos_producto': 'tpprNombre',
  'usuarios': 'usuaPrimerNombre',
  'ventas': 'ventFecha',
  'zonas_horarias': 'zohoNombre',
};

/// Retorna el campo principal de negocio para un módulo.
///
/// Regla central: el campo principal debe ser humano y funcional. No debe ser
/// una llave foránea ni un identificador técnico, salvo que el módulo no tenga
/// otro dato entendible.
CrudField crudPrimaryField<T>(CrudModuleConfig<T> config, {List<CrudField>? fields}) {
  final source = fields ?? config.fields;
  if (source.isEmpty) {
    throw StateError('El módulo ${config.key} no tiene campos configurados.');
  }

  final preferred = _preferredPrimaryFields[config.key];
  if (preferred != null) {
    for (final field in source) {
      if (field.name == preferred) return field;
    }
  }

  final nonTechnical = source.where((field) {
    final name = field.name.toLowerCase();
    return field.name != config.idField && !name.endsWith('id') && field.lookup == null;
  }).toList();

  int score(CrudField field) {
    final name = field.name.toLowerCase();
    final label = field.label.toLowerCase();
    final text = '$name $label';

    if (text.contains('nombre comercial')) return 130;
    if (text.contains('razon') || text.contains('razón')) return 125;
    if (text.contains('primer nombre')) return 122;
    if (text.contains('nombre')) return 120;
    if (text.contains('numero') || text.contains('número')) return 110;
    if (text.contains('codigo') || text.contains('código')) return 100;
    if (text.contains('email') || text.contains('correo')) return 95;
    if (text.contains('motivo')) return 90;
    if (text.contains('fecha')) return 80;
    if (text.contains('total') || text.contains('monto') || text.contains('valor')) return 75;
    if (text.contains('estado')) return 60;
    if (text.contains('descripcion') || text.contains('descripción')) return 55;
    return 10;
  }

  if (nonTechnical.isNotEmpty) {
    nonTechnical.sort((a, b) => score(b).compareTo(score(a)));
    return nonTechnical.first;
  }

  return source.firstWhere(
    (field) => field.name != config.idField,
    orElse: () => source.first,
  );
}

/// Ordena campos para UI dejando siempre el campo principal de negocio primero.
///
/// El resto de campos conserva su orden original, para no romper contratos ni
/// formularios. Esto aplica a tablas, tarjetas, detalles y formularios.
List<CrudField> crudOrderedFields<T>(CrudModuleConfig<T> config, {List<CrudField>? fields}) {
  final source = fields ?? config.fields;
  if (source.length <= 1) return source;
  final primary = crudPrimaryField(config, fields: source);
  return <CrudField>[
    primary,
    ...source.where((field) => field.name != primary.name),
  ];
}

/// Campos cortos para tarjetas móviles: primero el campo principal y luego datos
/// complementarios, evitando duplicar el identificador como información central.
List<CrudField> crudSummaryFields<T>(CrudModuleConfig<T> config) {
  final visible = crudVisibleFields(config);
  if (visible.isEmpty) return const <CrudField>[];

  final primary = visible.first;
  final others = visible
      .where((field) => field.name != primary.name)
      .take(4)
      .toList();

  return <CrudField>[primary, ...others];
}

/// Indica si un campo es un identificador técnico que no debe mostrarse
/// directamente al usuario.
///
/// Regla visual: el frontend puede usar los IDs internamente para navegar,
/// editar, eliminar o enviar relaciones al backend, pero no debe imprimirlos
/// como dato visible en tarjetas, tablas, detalles ni formularios.
bool crudIsTechnicalIdField<T>(CrudModuleConfig<T> config, CrudField field) {
  final name = field.name.toLowerCase();

  // El identificador principal del registro nunca se muestra en UI.
  if (field.name == config.idField) return true;

  // Si un campo termina en ID y no tiene ayuda de búsqueda, es un dato
  // técnico. Si tiene lookup, sí se puede mostrar porque se renderiza como
  // nombre/descripción y no como número.
  return name.endsWith('id') && field.lookup == null;
}

/// Retorna los campos visibles para la UI, ocultando identificadores técnicos.
/// Los campos relacionales con ayuda de búsqueda se conservan porque muestran
/// etiquetas humanas, no IDs.
List<CrudField> crudVisibleFields<T>(CrudModuleConfig<T> config, {List<CrudField>? fields}) {
  final ordered = crudOrderedFields(config, fields: fields);
  return ordered.where((field) => !crudIsTechnicalIdField(config, field)).toList();
}
