import 'package:flutter/material.dart';

class ModuleHelpEntry {
  const ModuleHelpEntry(this.title, this.description);
  final String title;
  final String description;
}

class ModuleHelp {
  const ModuleHelp(this.title, this.description, this.entries);
  final String title;
  final String description;
  final List<ModuleHelpEntry> entries;
}

/// Guía de opciones funcionales. Ordenar los prefijos de los más específicos a los generales.
const _helps = <String, ModuleHelp>{
  '/mesero/cierre-caja': ModuleHelp('Cierre de caja', 'Cuadra el efectivo y los ingresos al terminar el turno.', [
    ModuleHelpEntry('Base inicial', 'Registra el dinero físico recibido al empezar.'),
    ModuleHelpEntry('Medios de pago', 'Separa efectivo de pagos digitales; estos no suman dinero físico.'),
    ModuleHelpEntry('Gastos', 'Revisa los gastos de caja previamente registrados.'),
    ModuleHelpEntry('Conteo', 'Cuenta billetes y monedas y compara contra lo esperado.'),
    ModuleHelpEntry('Confirmar', 'Verifica la diferencia antes de cerrar.'),
  ]),
  '/mesero/historial': ModuleHelp('Historial operativo', 'Consulta ventas anteriores de la sucursal activa.', [
    ModuleHelpEntry('Fecha', 'Selecciona el día de operación.'),
    ModuleHelpEntry('Buscar', 'Encuentra ventas por número o texto.'),
    ModuleHelpEntry('Estados', 'Filtra ventas abiertas y finalizadas.'),
    ModuleHelpEntry('Detalle', 'Revisa cuentas, productos y pagos asociados.'),
  ]),
  '/mesero/productos': ModuleHelp('Productos para vender', 'Selecciona productos disponibles y revisa sus precios.', [
    ModuleHelpEntry('Buscar producto', 'Filtra por nombre, tipo o marca.'),
    ModuleHelpEntry('Agregar', 'Incorpora productos a la venta en curso.'),
    ModuleHelpEntry('Cantidades', 'Verifica unidades antes de guardar.'),
  ]),
  '/mesero/resumen': ModuleHelp('Resumen de operación', 'Consulta la actividad y ventas del turno.', [
    ModuleHelpEntry('Ventas', 'Revisa operaciones abiertas o terminadas.'),
    ModuleHelpEntry('Actualizar', 'Recarga los valores para obtener el estado más reciente.'),
  ]),
  '/mesero': ModuleHelp('Mesas y venta directa', 'Atiende las mesas y registra ventas sin mesa.', [
    ModuleHelpEntry('Mesas', 'Selecciona una mesa disponible para iniciar la venta.'),
    ModuleHelpEntry('Cuentas', 'Divide cuentas y mueve productos entre ellas.'),
    ModuleHelpEntry('Productos', 'Busca productos y agrega cantidades.'),
    ModuleHelpEntry('Pagos', 'Registra uno o varios medios de pago.'),
    ModuleHelpEntry('Venta directa', 'Registra una venta sin asociarla a una mesa.'),
  ]),
  '/administrar_mesas': ModuleHelp('Administrar mesas', 'Organiza las mesas de la sucursal.', [
    ModuleHelpEntry('Crear', 'Registra número y descripción de mesa.'),
    ModuleHelpEntry('Editar', 'Modifica la información permitida.'),
    ModuleHelpEntry('Desactivar o eliminar', 'Verifica que la mesa no tenga operación activa.'),
  ]),
  '/cierre_caja': ModuleHelp('Cierre de caja', 'Revisa el efectivo y registra el cierre del turno.', [
    ModuleHelpEntry('Base inicial', 'Introduce el efectivo de apertura.'),
    ModuleHelpEntry('Conteo', 'Cuenta billetes y monedas.'),
    ModuleHelpEntry('Cruce', 'Separa pagos digitales del efectivo en caja.'),
    ModuleHelpEntry('Cerrar', 'Confirma el resultado y revisa diferencias.'),
  ]),
  '/historial_ventas': ModuleHelp('Historial de ventas', 'Consulta ventas por fecha y estado.', [
    ModuleHelpEntry('Filtrar', 'Selecciona fecha y estado.'),
    ModuleHelpEntry('Detalle', 'Revisa productos y pagos de la operación.'),
  ]),
  '/ventas': ModuleHelp('Ventas', 'Consulta ventas y resultados de la sucursal elegida.', [
    ModuleHelpEntry('Periodo', 'Ajusta fechas de inicio y fin.'),
    ModuleHelpEntry('Estado', 'Filtra ventas por estado.'),
    ModuleHelpEntry('Buscar', 'Localiza operaciones por su información.'),
    ModuleHelpEntry('Detalle', 'Examina pagos y productos.'),
    ModuleHelpEntry('Tiempo real', 'Actualiza las ventas recientes.'),
  ]),
  '/productos': ModuleHelp('Productos', 'Administra el catálogo comercial de cada sucursal.', [
    ModuleHelpEntry('Crear', 'Registra nombre, tipo, marca e imagen.'),
    ModuleHelpEntry('Clasificar', 'Distingue producto normal, insumo y preparado.'),
    ModuleHelpEntry('Recetas y adiciones', 'Configura ingredientes u opciones cuando el producto lo permita.'),
    ModuleHelpEntry('Editar', 'Actualiza datos sin perder referencias de inventario.'),
    ModuleHelpEntry('Inactivar', 'Oculta productos sin borrar historial.'),
    ModuleHelpEntry('Importación', 'Revisa la plantilla disponible antes de cargar.'),
  ]),
  '/precios': ModuleHelp('Precios', 'Administra costos, precios de venta y márgenes.', [
    ModuleHelpEntry('Consultar', 'Alterna las vistas disponibles y usa filtros.'),
    ModuleHelpEntry('Compra por paquete', 'Indica las unidades del paquete para calcular el costo unitario.'),
    ModuleHelpEntry('Venta', 'Edita el valor unitario y comprueba el margen.'),
    ModuleHelpEntry('Historial', 'Revisa cambios previos cuando estén disponibles.'),
  ]),
  '/inventario_admin': ModuleHelp('Inventario operativo', 'Controla existencias y conteos de la sucursal.', [
    ModuleHelpEntry('Existencias', 'Revisa cantidades registradas.'),
    ModuleHelpEntry('Conteo', 'Registra unidades físicas.'),
    ModuleHelpEntry('Diferencias', 'Compara conteo frente al sistema.'),
    ModuleHelpEntry('Sincronizar', 'Justifica diferencias antes de ajustar inventario.'),
  ]),
  '/inventario': ModuleHelp('Inventario', 'Consulta las cantidades disponibles y registros de inventario.', [
    ModuleHelpEntry('Buscar', 'Filtra productos.'),
    ModuleHelpEntry('Contar', 'Introduce cantidades físicas.'),
    ModuleHelpEntry('Movimientos', 'Revisa las entradas y salidas.'),
    ModuleHelpEntry('Ajustar', 'Registra correcciones justificadas cuando corresponda.'),
  ]),
  '/movimientos': ModuleHelp('Movimientos de inventario', 'Registra entradas y salidas que afectan existencias.', [
    ModuleHelpEntry('Compra y entrada', 'Registra unidades incorporadas.'),
    ModuleHelpEntry('Venta y salida', 'Comprueba disminuciones de stock.'),
    ModuleHelpEntry('Ajustes', 'Usa el tipo positivo o negativo según corresponda.'),
    ModuleHelpEntry('Préstamos y devoluciones', 'Distingue préstamo entrante, saliente y devolución.'),
    ModuleHelpEntry('Historial', 'Filtra movimientos y revisa su responsable.'),
  ]),
  '/proximo_pedido': ModuleHelp('Próximo pedido', 'Planifica reposición según las existencias.', [
    ModuleHelpEntry('Recomendaciones', 'Consulta cantidades sugeridas.'),
    ModuleHelpEntry('Pedido manual', 'Puedes preparar un pedido aun cuando el stock esté cubierto.'),
    ModuleHelpEntry('Confirmación', 'Revisa los productos antes de confirmar.'),
    ModuleHelpEntry('Recepción', 'El stock debe actualizarse cuando el pedido sea recibido, no solo confirmado.'),
  ]),
  '/proveedores': ModuleHelp('Proveedores de pedidos', 'Organiza contactos de WhatsApp para compras.', [
    ModuleHelpEntry('Contactos', 'Configura los números asociados a los productos o proveedores.'),
    ModuleHelpEntry('Asignación', 'Selecciona el proveedor para cada producto.'),
    ModuleHelpEntry('WhatsApp', 'Prepara mensajes separados por destinatario.'),
  ]),
  '/pedidos': ModuleHelp('Pedidos de compra', 'Prepara, confirma y recibe compras a proveedores.', [
    ModuleHelpEntry('Crear pedido', 'Selecciona productos y cantidades.'),
    ModuleHelpEntry('Proveedor', 'Agrupa los productos por destinatario.'),
    ModuleHelpEntry('Confirmar', 'Verifica el pedido antes de enviarlo.'),
    ModuleHelpEntry('WhatsApp', 'Comparte el pedido sin marcarlo como recibido.'),
    ModuleHelpEntry('Recibir', 'Confirma lo entregado para actualizar existencias.'),
    ModuleHelpEntry('Historial', 'Consulta pedidos previos y su estado.'),
  ]),
  '/gastos_fijos': ModuleHelp('Gastos fijos', 'Registra gastos recurrentes y costos de personal.', [
    ModuleHelpEntry('Crear', 'Indica nombre, categoría, valor y periodo.'),
    ModuleHelpEntry('Periodicidad', 'Distingue costos diarios, semanales o mensuales.'),
    ModuleHelpEntry('Mano de obra', 'Configura cargos, turnos y valores por días cuando aplique.'),
    ModuleHelpEntry('Editar y eliminar', 'Corrige registros duplicados o desactualizados.'),
    ModuleHelpEntry('Ganancias', 'Estos costos forman parte del análisis de rentabilidad.'),
  ]),
  '/ganancias': ModuleHelp('Ganancias', 'Analiza ingresos, costos y resultado del negocio.', [
    ModuleHelpEntry('Periodo', 'Selecciona el rango de fechas.'),
    ModuleHelpEntry('Costos', 'Verifica costo de productos y gastos fijos.'),
    ModuleHelpEntry('Resultado', 'Compara ventas y costos.'),
    ModuleHelpEntry('Exportar', 'Descarga el reporte cuando esté disponible.'),
  ]),
  '/reportes': ModuleHelp('Reportes', 'Analiza ventas, inventario y desempeño.', [
    ModuleHelpEntry('Filtros', 'Elige fechas y sucursal.'),
    ModuleHelpEntry('Indicadores', 'Revisa cifras antes de tomar decisiones.'),
    ModuleHelpEntry('Descargar', 'Exporta cuando la opción esté habilitada.'),
  ]),
  '/reporte_': ModuleHelp('Reportes especializados', 'Consulta una métrica concreta del negocio.', [
    ModuleHelpEntry('Periodo', 'Configura rango de análisis.'),
    ModuleHelpEntry('Filtros', 'Ajusta sucursal, producto o responsable.'),
    ModuleHelpEntry('Datos', 'Interpreta los totales y las diferencias.'),
    ModuleHelpEntry('Exportación', 'Genera el archivo cuando esté disponible.'),
  ]),
  '/dashboard': ModuleHelp('Panel de control', 'Consulta indicadores operativos y financieros.', [
    ModuleHelpEntry('Resumen', 'Identifica ventas, mesas e indicadores destacados.'),
    ModuleHelpEntry('Sucursal', 'Elige la sede para delimitar la consulta.'),
    ModuleHelpEntry('Detalle', 'Abre el módulo correspondiente para revisar resultados.'),
  ]),
  '/home': ModuleHelp('Inicio', 'Accede a las funciones principales disponibles para tu rol.', [
    ModuleHelpEntry('Menú', 'Abre el módulo que necesites.'),
    ModuleHelpEntry('Vista por rol', 'Selecciona uno o varios roles si están asignados.'),
    ModuleHelpEntry('Sucursal', 'Cambia la sede de los datos cuando tengas acceso.'),
  ]),
  '/comandas': ModuleHelp('Comandas', 'Consulta y gestiona los pedidos enviados a preparación.', [
    ModuleHelpEntry('Pendientes', 'Identifica comandas que requieren atención.'),
    ModuleHelpEntry('Detalle', 'Revisa productos, cantidades y observaciones.'),
    ModuleHelpEntry('Estado', 'Actualiza la preparación o entrega según permisos.'),
  ]),
  '/medios_pago': ModuleHelp('Medios de pago', 'Configura cómo reciben pagos las sucursales.', [
    ModuleHelpEntry('Activar', 'Habilita los medios aceptados.'),
    ModuleHelpEntry('QR', 'Configura información de Nequi y DaviPlata cuando corresponda.'),
    ModuleHelpEntry('Sucursal', 'Comprueba que cada medio esté asociado a la sede correcta.'),
  ]),
  '/usuarios': ModuleHelp('Usuarios', 'Administra el acceso del personal.', [
    ModuleHelpEntry('Crear', 'Registra la cuenta del empleado.'),
    ModuleHelpEntry('Asignar sucursales', 'Delimita las sedes autorizadas.'),
    ModuleHelpEntry('Roles', 'Asigna las funciones necesarias.'),
    ModuleHelpEntry('Estado', 'Desactiva accesos cuando corresponda.'),
  ]),
  '/roles_personalizados': ModuleHelp('Roles personalizados', 'Configura menús y permisos específicos.', [
    ModuleHelpEntry('Crear', 'Define el nombre del rol.'),
    ModuleHelpEntry('Opciones', 'Selecciona los menús delegables.'),
    ModuleHelpEntry('Orden', 'Organiza la visibilidad de los elementos.'),
    ModuleHelpEntry('Aplicar', 'Asigna el rol a los usuarios indicados.'),
  ]),
  '/roles': ModuleHelp('Roles', 'Consulta los perfiles que controlan el acceso.', [
    ModuleHelpEntry('Permisos', 'Revisa qué acciones habilita cada perfil.'),
    ModuleHelpEntry('Asignaciones', 'Comprueba los usuarios asociados.'),
    ModuleHelpEntry('Personalización', 'Utiliza roles personalizados cuando corresponda.'),
  ]),
  '/sucursales': ModuleHelp('Sucursales', 'Administra sedes de una empresa.', [
    ModuleHelpEntry('Crear', 'Registra los datos de una nueva sede.'),
    ModuleHelpEntry('Editar', 'Actualiza nombre y demás información.'),
    ModuleHelpEntry('Inactivar', 'Una sede inactiva no debe contar como disponible.'),
    ModuleHelpEntry('Eliminar', 'Verifica dependencias antes de eliminar.'),
  ]),
  '/empresas': ModuleHelp('Empresas', 'Administra los datos de las organizaciones.', [
    ModuleHelpEntry('Crear', 'Registra una nueva empresa.'),
    ModuleHelpEntry('Sucursales', 'Asigna los establecimientos correspondientes.'),
    ModuleHelpEntry('Editar', 'Mantén actualizada la información.'),
    ModuleHelpEntry('Acceso', 'Verifica los permisos sobre la empresa.'),
  ]),
  '/profile': ModuleHelp('Mi perfil', 'Consulta y actualiza la información de tu cuenta.', [
    ModuleHelpEntry('Datos', 'Revisa información personal.'),
    ModuleHelpEntry('Credenciales', 'Utiliza las opciones de seguridad disponibles.'),
    ModuleHelpEntry('Sesión', 'Cierra sesión al terminar si el dispositivo es compartido.'),
  ]),
  '/planes_suscripcion': ModuleHelp('Planes y suscripción', 'Consulta los planes disponibles.', [
    ModuleHelpEntry('Plan', 'Compara características y límites.'),
    ModuleHelpEntry('Suscripción', 'Revisa vigencia y cobros.'),
    ModuleHelpEntry('Cambiar o cancelar', 'Consulta las condiciones antes de confirmar.'),
  ]),
  '/parametros_operativos': ModuleHelp('Parámetros operativos', 'Configura los datos necesarios para operar.', [
    ModuleHelpEntry('Revisar', 'Comprueba la configuración de cada opción.'),
    ModuleHelpEntry('Guardar', 'Aplica los cambios autorizados.'),
  ]),
  '/parametros': ModuleHelp('Parámetros', 'Configura valores del aplicativo.', [
    ModuleHelpEntry('Consultar', 'Busca el parámetro requerido.'),
    ModuleHelpEntry('Editar', 'Modifica únicamente valores autorizados.'),
    ModuleHelpEntry('Verificar', 'Comprueba el efecto del ajuste.'),
  ]),
  '/marcas': ModuleHelp('Marcas', 'Organiza el catálogo por marcas.', [
    ModuleHelpEntry('Crear', 'Registra una marca.'),
    ModuleHelpEntry('Editar', 'Corrige nombre o información.'),
    ModuleHelpEntry('Filtrar', 'Localiza productos asociados.'),
  ]),
  '/tipos_producto': ModuleHelp('Tipos de producto', 'Clasifica artículos del catálogo.', [
    ModuleHelpEntry('Crear', 'Registra una categoría de producto.'),
    ModuleHelpEntry('Editar', 'Actualiza la clasificación.'),
    ModuleHelpEntry('Asociar', 'Selecciona el tipo correcto al crear artículos.'),
  ]),
  '/tablas_parametricas': ModuleHelp('Tablas paramétricas', 'Administra catálogos auxiliares.', [
    ModuleHelpEntry('Consultar', 'Selecciona la tabla correspondiente.'),
    ModuleHelpEntry('Crear o editar', 'Mantén los valores de referencia.'),
    ModuleHelpEntry('Eliminar', 'Verifica que el valor no esté en uso.'),
  ]),
  '/soporte': ModuleHelp('Soporte administrativo', 'Gestiona incidencias y asistencia técnica autorizada.', [
    ModuleHelpEntry('Diagnóstico', 'Consulta el estado de la operación.'),
    ModuleHelpEntry('Auditoría', 'Revisa acciones registradas.'),
    ModuleHelpEntry('Accesos', 'Verifica permisos y cuentas.'),
    ModuleHelpEntry('Mantenimiento', 'Aplica cambios solo bajo autorización.'),
  ]),
  '/explorador_datos': ModuleHelp('Explorador de datos', 'Consulta registros internos con permisos de soporte.', [
    ModuleHelpEntry('Tablas', 'Elige el conjunto de datos.'),
    ModuleHelpEntry('Filtrar', 'Reduce resultados.'),
    ModuleHelpEntry('Seguridad', 'No modifiques datos de clientes sin autorización.'),
  ]),
  '/auditoria': ModuleHelp('Auditoría', 'Consulta el historial de acciones de soporte.', [
    ModuleHelpEntry('Buscar', 'Filtra por fecha u operación.'),
    ModuleHelpEntry('Detalle', 'Revisa el resultado de la acción.'),
  ]),
  '/paises': ModuleHelp('Países', 'Administra referencias geográficas.', [
    ModuleHelpEntry('Consultar', 'Revisa valores registrados.'),
    ModuleHelpEntry('Editar', 'Corrige datos autorizados.'),
  ]),
  '/ciudades': ModuleHelp('Ciudades', 'Administra ubicaciones disponibles.', [
    ModuleHelpEntry('Crear', 'Registra la ciudad requerida.'),
    ModuleHelpEntry('Editar', 'Verifica la región y país asociados.'),
  ]),
  '/regiones': ModuleHelp('Regiones', 'Administra divisiones geográficas.', [
    ModuleHelpEntry('Consultar', 'Revisa regiones configuradas.'),
    ModuleHelpEntry('Editar', 'Mantén asociaciones coherentes.'),
  ]),
  '/zonas_horarias': ModuleHelp('Zonas horarias', 'Configura las zonas utilizadas por el sistema.', [
    ModuleHelpEntry('Seleccionar', 'Verifica la zona aplicable.'),
    ModuleHelpEntry('Guardar', 'Confirma el cambio autorizado.'),
  ]),
  '/monedas': ModuleHelp('Monedas', 'Administra referencias monetarias.', [
    ModuleHelpEntry('Consultar', 'Verifica moneda y formato.'),
    ModuleHelpEntry('Editar', 'Actualiza la configuración autorizada.'),
  ]),
  '/mesas': ModuleHelp('Mesas', 'Administra los registros de mesas.', [
    ModuleHelpEntry('Crear', 'Registra una mesa.'),
    ModuleHelpEntry('Editar', 'Actualiza su descripción.'),
    ModuleHelpEntry('Eliminar', 'Valida que no existan operaciones activas.'),
  ]),
  '/pagos': ModuleHelp('Pagos', 'Consulta y registra información de cobros.', [
    ModuleHelpEntry('Detalle', 'Revisa monto y medio de pago.'),
    ModuleHelpEntry('Validar', 'Comprueba relación con la venta.'),
    ModuleHelpEntry('Modificar', 'Realiza correcciones solo si tienes permisos.'),
  ]),
  '/cuentas_venta': ModuleHelp('Cuentas de venta', 'Gestiona subdivisiones de las ventas.', [
    ModuleHelpEntry('Cuentas', 'Consulta los grupos de consumo.'),
    ModuleHelpEntry('Productos', 'Revisa detalles asignados.'),
    ModuleHelpEntry('Pago', 'Verifica el estado de cada cuenta.'),
  ]),
  '/detalle_cuenta_venta': ModuleHelp('Detalle de cuenta', 'Consulta productos agregados a una cuenta.', [
    ModuleHelpEntry('Productos', 'Verifica cantidades y precios.'),
    ModuleHelpEntry('Cambios', 'Realiza modificaciones autorizadas.'),
  ]),
  '/menus': ModuleHelp('Menús', 'Configura las opciones disponibles en la navegación.', [
    ModuleHelpEntry('Crear', 'Registra opciones del menú.'),
    ModuleHelpEntry('Ordenar', 'Organiza su posición.'),
    ModuleHelpEntry('Permisos', 'Vincula opciones a roles autorizados.'),
  ]),
  '/opciones_menu': ModuleHelp('Opciones de menú', 'Administra accesos a funciones específicas.', [
    ModuleHelpEntry('Consultar', 'Revisa opciones registradas.'),
    ModuleHelpEntry('Editar', 'Ajusta información permitida.'),
  ]),
  '/tipos_movimiento': ModuleHelp('Tipos de movimiento', 'Clasifica operaciones de inventario.', [
    ModuleHelpEntry('Consultar', 'Revisa entrada y salida por tipo.'),
    ModuleHelpEntry('Editar', 'Modifica solo las categorías autorizadas.'),
  ]),
  '/sincronizar_catalogo': ModuleHelp('Sincronizar catálogo', 'Copia referencias permitidas al catálogo de una sucursal.', [
    ModuleHelpEntry('Seleccionar', 'Marca productos del catálogo maestro.'),
    ModuleHelpEntry('Precios', 'Comprueba importes de compra y venta.'),
    ModuleHelpEntry('Confirmar', 'Verifica duplicados antes de sincronizar.'),
  ]),
};

ModuleHelp helpForRoute(String path) {
  final current = path.toLowerCase().replaceAll('-', '_');
  for (final entry in _helps.entries) {
    if (current.startsWith(entry.key.replaceAll('-', '_'))) return entry.value;
  }
  return const ModuleHelp('Ayuda · BarLytics',
    'Explora las opciones de esta pantalla según los permisos asignados a tu usuario.', [
      ModuleHelpEntry('Consultar', 'Revisa registros y utiliza los filtros disponibles.'),
      ModuleHelpEntry('Crear y editar', 'Usa las acciones visibles cuando tengas autorización.'),
      ModuleHelpEntry('Guardar', 'Revisa los datos antes de confirmar los cambios.'),
    ]);
}

/// Diferencia operaciones de detalle, alta y edición sin asumir capacidades inexistentes.
List<ModuleHelpEntry> helpForOperation(String path) {
  final parts = path.split('/').where((x) => x.isNotEmpty).toList();
  if (parts.isEmpty) return const [];
  if (parts.last == 'nuevo') return const [
    ModuleHelpEntry('Nuevo registro', 'Completa los campos obligatorios y guarda cuando hayas verificado los datos.'),
  ];
  if (parts.last == 'editar') return const [
    ModuleHelpEntry('Editar registro', 'Modifica los campos autorizados y guarda para aplicar el cambio.'),
  ];
  if (parts.length > 1 && int.tryParse(parts.last) != null) return const [
    ModuleHelpEntry('Detalle del registro', 'Revisa los datos asociados a este elemento antes de hacer cambios.'),
  ];
  return const [];
}
