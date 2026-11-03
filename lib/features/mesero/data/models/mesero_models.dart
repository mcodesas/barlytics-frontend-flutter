class MeseroMesaResumenModel {
  const MeseroMesaResumenModel({
    this.mesaId,
    this.mesaNumero,
    this.sucursalId,
    this.estadoMesa,
    this.mesaDescripcion,
    this.mesaFoto,
    this.ventaId,
    this.estadoVenta,
    this.totalPendiente,
    this.numeroCuentas,
  });

  final int? mesaId;
  final int? mesaNumero;
  final int? sucursalId;
  final String? estadoMesa;
  final String? mesaDescripcion;
  final String? mesaFoto;
  final int? ventaId;
  final String? estadoVenta;
  final double? totalPendiente;
  final int? numeroCuentas;

  factory MeseroMesaResumenModel.fromJson(Map<String, dynamic> json) => MeseroMesaResumenModel(
        mesaId: (json['mesaId'] as num?)?.toInt(),
        mesaNumero: (json['mesaNumero'] as num?)?.toInt(),
        sucursalId: (json['sucursalId'] as num?)?.toInt(),
        estadoMesa: json['estadoMesa']?.toString(),
        mesaDescripcion: json['mesaDescripcion']?.toString(),
        mesaFoto: json['mesaFoto']?.toString(),
        ventaId: (json['ventaId'] as num?)?.toInt(),
        estadoVenta: json['estadoVenta']?.toString(),
        totalPendiente: (json['totalPendiente'] as num?)?.toDouble(),
        numeroCuentas: (json['numeroCuentas'] as num?)?.toInt(),
      );
}

class MeseroMedioPagoModel {
  const MeseroMedioPagoModel({
    this.medioPagoId,
    this.nombre,
    this.descripcion,
    this.qr,
  });

  final int? medioPagoId;
  final String? nombre;
  final String? descripcion;
  final String? qr;

  factory MeseroMedioPagoModel.fromJson(Map<String, dynamic> json) => MeseroMedioPagoModel(
        medioPagoId: (json['medioPagoId'] as num?)?.toInt(),
        nombre: json['nombre']?.toString(),
        descripcion: json['descripcion']?.toString(),
        qr: json['qr']?.toString(),
      );
}

class MeseroIngredienteGastroModel {
  const MeseroIngredienteGastroModel({
    this.id,
    this.prodId,
    this.nombre,
    this.cantidad,
    this.unidad,
    this.removible,
    this.precioCompra,
    this.precioVenta,
  });

  final int? id;
  final int? prodId;
  final String? nombre;
  final double? cantidad;
  final String? unidad;
  final bool? removible;
  final double? precioCompra;
  final double? precioVenta;

  factory MeseroIngredienteGastroModel.fromJson(Map<String, dynamic> json) =>
      MeseroIngredienteGastroModel(
        id: (json['id'] as num?)?.toInt(),
        prodId: (json['prodId'] as num?)?.toInt(),
        nombre: json['nombre']?.toString(),
        cantidad: (json['cantidad'] as num?)?.toDouble(),
        unidad: json['unidad']?.toString(),
        removible: json['removible'] as bool?,
        precioCompra: (json['precioCompra'] as num?)?.toDouble(),
        precioVenta: (json['precioVenta'] as num?)?.toDouble(),
      );
}

class MeseroAdicionGastroModel {
  const MeseroAdicionGastroModel({
    this.id,
    this.prodId,
    this.nombre,
    this.cantidad,
    this.unidad,
    this.precioAdicional,
    this.precioCompra,
    this.precioVenta,
  });

  final int? id;
  final int? prodId;
  final String? nombre;
  final double? cantidad;
  final String? unidad;
  final double? precioAdicional;
  final double? precioCompra;
  final double? precioVenta;

  factory MeseroAdicionGastroModel.fromJson(Map<String, dynamic> json) =>
      MeseroAdicionGastroModel(
        id: (json['id'] as num?)?.toInt(),
        prodId: (json['prodId'] as num?)?.toInt(),
        nombre: json['nombre']?.toString(),
        cantidad: (json['cantidad'] as num?)?.toDouble(),
        unidad: json['unidad']?.toString(),
        precioAdicional: (json['precioAdicional'] as num?)?.toDouble(),
        precioCompra: (json['precioCompra'] as num?)?.toDouble(),
        precioVenta: (json['precioVenta'] as num?)?.toDouble(),
      );
}

class MeseroProductoModel {
  const MeseroProductoModel({
    this.prodId,
    this.sucuId,
    this.precId,
    this.tipoProductoId,
    this.tipoProductoNombre,
    this.marcaId,
    this.marcaNombre,
    this.nombre,
    this.descripcion,
    this.foto,
    this.precioVenta,
    this.tipoControl,
    this.unidadBase,
    this.ingredientes = const <MeseroIngredienteGastroModel>[],
    this.adiciones = const <MeseroAdicionGastroModel>[],
  });

  final int? prodId;
  final int? sucuId;
  final int? precId;
  final int? tipoProductoId;
  final String? tipoProductoNombre;
  final int? marcaId;
  final String? marcaNombre;
  final String? nombre;
  final String? descripcion;
  final String? foto;
  final double? precioVenta;
  final String? tipoControl;
  final String? unidadBase;
  final List<MeseroIngredienteGastroModel> ingredientes;
  final List<MeseroAdicionGastroModel> adiciones;

  factory MeseroProductoModel.fromJson(Map<String, dynamic> json) => MeseroProductoModel(
        prodId: (json['prodId'] as num?)?.toInt(),
        sucuId: (json['sucuId'] as num?)?.toInt(),
        precId: (json['precId'] as num?)?.toInt(),
        tipoProductoId: (json['tipoProductoId'] as num?)?.toInt(),
        tipoProductoNombre: json['tipoProductoNombre']?.toString(),
        marcaId: (json['marcaId'] as num?)?.toInt(),
        marcaNombre: json['marcaNombre']?.toString(),
        nombre: json['nombre']?.toString(),
        descripcion: json['descripcion']?.toString(),
        foto: json['foto']?.toString() ?? json['prodFoto']?.toString(),
        precioVenta: (json['precioVenta'] as num?)?.toDouble(),
        tipoControl: json['tipoControl']?.toString(),
        unidadBase: json['unidadBase']?.toString(),
        ingredientes: (json['ingredientes'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => MeseroIngredienteGastroModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        adiciones: (json['adiciones'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => MeseroAdicionGastroModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

class MeseroDetalleProductoModel {
  const MeseroDetalleProductoModel({
    this.detalleId,
    this.cuentaId,
    this.precioId,
    this.productoId,
    this.productoNombre,
    this.productoFoto,
    this.cantidad,
    this.valorUnitario,
    this.precioAdicionalUnitario,
    this.subtotal,
    this.descuentoTipo,
    this.descuentoValor,
    this.descuentoAplicado,
    this.personalizacion,
    this.pagado,
  });

  final int? detalleId;
  final int? cuentaId;
  final int? precioId;
  final int? productoId;
  final String? productoNombre;
  final String? productoFoto;
  final double? cantidad;
  final double? valorUnitario;
  final double? precioAdicionalUnitario;
  final double? subtotal;
  final String? descuentoTipo;
  final double? descuentoValor;
  final double? descuentoAplicado;
  final String? personalizacion;
  final bool? pagado;

  factory MeseroDetalleProductoModel.fromJson(Map<String, dynamic> json) => MeseroDetalleProductoModel(
        detalleId: (json['detalleId'] as num?)?.toInt(),
        cuentaId: (json['cuentaId'] as num?)?.toInt(),
        precioId: (json['precioId'] as num?)?.toInt(),
        productoId: (json['productoId'] as num?)?.toInt(),
        productoNombre: json['productoNombre']?.toString(),
        productoFoto: json['productoFoto']?.toString() ?? json['foto']?.toString(),
        cantidad: (json['cantidad'] as num?)?.toDouble(),
        valorUnitario: (json['valorUnitario'] as num?)?.toDouble(),
        precioAdicionalUnitario: (json['precioAdicionalUnitario'] as num?)?.toDouble(),
        subtotal: (json['subtotal'] as num?)?.toDouble(),
        descuentoTipo: json['descuentoTipo']?.toString(),
        descuentoValor: (json['descuentoValor'] as num?)?.toDouble(),
        descuentoAplicado: (json['descuentoAplicado'] as num?)?.toDouble(),
        personalizacion: json['personalizacion']?.toString(),
        pagado: json['pagado'] is bool
            ? json['pagado'] as bool
            : json['pagado'] == 1 ||
                ((json['decvPagado'] as num?)?.toInt() == 1) ||
                json['pagado']?.toString().toLowerCase() == 'true',
      );
}

class MeseroPagoModel {
  const MeseroPagoModel({
    this.pagoId,
    this.cuentaId,
    this.medioPagoId,
    this.medioPagoNombre,
    this.valor,
    this.valorRecibido,
    this.cambio,
    this.fecha,
  });

  final int? pagoId;
  final int? cuentaId;
  final int? medioPagoId;
  final String? medioPagoNombre;
  final double? valor;
  final double? valorRecibido;
  final double? cambio;
  final String? fecha;

  factory MeseroPagoModel.fromJson(Map<String, dynamic> json) => MeseroPagoModel(
        pagoId: (json['pagoId'] as num?)?.toInt(),
        cuentaId: (json['cuentaId'] as num?)?.toInt(),
        medioPagoId: (json['medioPagoId'] as num?)?.toInt(),
        medioPagoNombre: json['medioPagoNombre']?.toString(),
        valor: (json['valor'] as num?)?.toDouble(),
        valorRecibido: (json['valorRecibido'] as num?)?.toDouble(),
        cambio: (json['cambio'] as num?)?.toDouble(),
        fecha: json['fecha']?.toString(),
      );
}

class MeseroCuentaModel {
  const MeseroCuentaModel({
    this.cuentaId,
    this.numero,
    this.descripcion,
    this.total,
    this.propina,
    this.subtotalProductos,
    this.descuentoTipo,
    this.descuentoValor,
    this.descuentoAplicado,
    this.totalPagado,
    this.saldoPendiente,
    this.pagada,
    this.estado,
    this.productos = const <MeseroDetalleProductoModel>[],
    this.pagos = const <MeseroPagoModel>[],
  });

  final int? cuentaId;
  final int? numero;
  final String? descripcion;
  final double? total;
  final double? propina;
  final double? subtotalProductos;
  final String? descuentoTipo;
  final double? descuentoValor;
  final double? descuentoAplicado;
  final double? totalPagado;
  final double? saldoPendiente;
  final bool? pagada;
  final int? estado;
  final List<MeseroDetalleProductoModel> productos;
  final List<MeseroPagoModel> pagos;

  factory MeseroCuentaModel.fromJson(Map<String, dynamic> json) => MeseroCuentaModel(
        cuentaId: (json['cuentaId'] as num?)?.toInt(),
        numero: (json['numero'] as num?)?.toInt(),
        descripcion: json['descripcion']?.toString(),
        total: (json['total'] as num?)?.toDouble(),
        propina: (json['propina'] as num?)?.toDouble(),
        subtotalProductos: (json['subtotalProductos'] as num?)?.toDouble(),
        descuentoTipo: json['descuentoTipo']?.toString(),
        descuentoValor: (json['descuentoValor'] as num?)?.toDouble(),
        descuentoAplicado: (json['descuentoAplicado'] as num?)?.toDouble(),
        totalPagado: (json['totalPagado'] as num?)?.toDouble(),
        saldoPendiente: (json['saldoPendiente'] as num?)?.toDouble(),
        pagada: json['pagada'] as bool?,
        estado: (json['estado'] as num?)?.toInt(),
        productos: (json['productos'] as List? ?? const [])
            .map((e) => MeseroDetalleProductoModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        pagos: (json['pagos'] as List? ?? const [])
            .map((e) => MeseroPagoModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
      );
}

class MeseroVentaModel {
  const MeseroVentaModel({
    this.ventaId,
    this.mesaId,
    this.mesaNumero,
    this.sucursalId,
    this.tipoVenta,
    this.mesaDescripcion,
    this.mesaFoto,
    this.fecha,
    this.estado,
    this.total,
    this.propina,
    this.totalPagado,
    this.saldoPendiente,
    this.pagada,
    this.cuentas = const <MeseroCuentaModel>[],
  });

  final int? ventaId;
  final int? mesaId;
  final int? mesaNumero;
  final int? sucursalId;
  final String? tipoVenta;
  final String? mesaDescripcion;
  final String? mesaFoto;
  final String? fecha;
  final String? estado;
  final double? total;
  final double? propina;
  final double? totalPagado;
  final double? saldoPendiente;
  final bool? pagada;
  final List<MeseroCuentaModel> cuentas;

  factory MeseroVentaModel.fromJson(Map<String, dynamic> json) => MeseroVentaModel(
        ventaId: (json['ventaId'] as num?)?.toInt(),
        mesaId: (json['mesaId'] as num?)?.toInt(),
        mesaNumero: (json['mesaNumero'] as num?)?.toInt(),
        sucursalId: (json['sucursalId'] as num?)?.toInt(),
        tipoVenta: json['tipoVenta']?.toString(),
        mesaDescripcion: json['mesaDescripcion']?.toString(),
        mesaFoto: json['mesaFoto']?.toString(),
        fecha: json['fecha']?.toString(),
        estado: json['estado']?.toString(),
        total: (json['total'] as num?)?.toDouble(),
        propina: (json['propina'] as num?)?.toDouble(),
        totalPagado: (json['totalPagado'] as num?)?.toDouble(),
        saldoPendiente: (json['saldoPendiente'] as num?)?.toDouble(),
        pagada: json['pagada'] as bool?,
        cuentas: (json['cuentas'] as List? ?? const [])
            .map((e) => MeseroCuentaModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
      );
}

class CierreCajaMedioPagoModel {
  const CierreCajaMedioPagoModel({this.medioPagoId, this.medioPagoNombre, this.totalSistema, this.valorEntregado, this.diferencia, this.observacion});
  final int? medioPagoId;
  final String? medioPagoNombre;
  final double? totalSistema;
  final double? valorEntregado;
  final double? diferencia;
  final String? observacion;
  factory CierreCajaMedioPagoModel.fromJson(Map<String, dynamic> json) => CierreCajaMedioPagoModel(
        medioPagoId: (json['medioPagoId'] as num?)?.toInt(),
        medioPagoNombre: json['medioPagoNombre']?.toString(),
        totalSistema: (json['totalSistema'] as num?)?.toDouble(),
        valorEntregado: (json['valorEntregado'] as num?)?.toDouble(),
        diferencia: (json['diferencia'] as num?)?.toDouble(),
        observacion: json['observacion']?.toString(),
      );
}

class CierreCajaProductoModel {
  const CierreCajaProductoModel({
    this.productoId,
    this.productoNombre,
    this.cantidad,
    this.valorUnitario,
    this.totalVenta,
  });
  final int? productoId;
  final String? productoNombre;
  final double? cantidad;
  final double? valorUnitario;
  final double? totalVenta;
  factory CierreCajaProductoModel.fromJson(Map<String, dynamic> json) => CierreCajaProductoModel(
        productoId: (json['productoId'] as num?)?.toInt(),
        productoNombre: json['productoNombre']?.toString(),
        cantidad: (json['cantidad'] as num?)?.toDouble(),
        valorUnitario: (json['valorUnitario'] as num?)?.toDouble(),
        totalVenta: (json['totalVenta'] as num?)?.toDouble(),
      );
}

class CierreCajaVentaIncluidaModel {
  const CierreCajaVentaIncluidaModel({this.ventaId, this.mesaId, this.mesaNumero, this.tipoVenta, this.fecha, this.subtotalVenta, this.propina, this.total});
  final int? ventaId;
  final int? mesaId;
  final int? mesaNumero;
  final String? tipoVenta;
  final String? fecha;
  final double? subtotalVenta;
  final double? propina;
  final double? total;
  factory CierreCajaVentaIncluidaModel.fromJson(Map<String, dynamic> json) => CierreCajaVentaIncluidaModel(
        ventaId: (json['ventaId'] as num?)?.toInt(),
        mesaId: (json['mesaId'] as num?)?.toInt(),
        mesaNumero: (json['mesaNumero'] as num?)?.toInt(),
        tipoVenta: json['tipoVenta']?.toString(),
        fecha: json['fecha']?.toString(),
        subtotalVenta: (json['subtotalVenta'] as num?)?.toDouble(),
        propina: (json['propina'] as num?)?.toDouble(),
        total: (json['total'] as num?)?.toDouble(),
      );
}

class CierreCajaGastoModel {
  const CierreCajaGastoModel({this.gastoId, this.descripcion, this.valor});
  final int? gastoId;
  final String? descripcion;
  final double? valor;

  factory CierreCajaGastoModel.fromJson(Map<String, dynamic> json) => CierreCajaGastoModel(
        gastoId: (json['gastoId'] as num?)?.toInt(),
        descripcion: json['descripcion']?.toString(),
        valor: (json['valor'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (gastoId != null) 'gastoId': gastoId,
        'descripcion': descripcion,
        'valor': valor ?? 0,
      };
}

class SalidaCajaModel {
  const SalidaCajaModel({
    this.salidaId,
    this.sucursalId,
    this.cierreCajaId,
    this.fecha,
    this.fechaHora,
    this.tipo,
    this.categoria,
    this.descripcion,
    this.valor,
    this.gastoId,
    this.pedidoId,
    this.medioPagoNombre,
    this.afectaResultado,
    this.estado,
    this.registradoPor,
  });

  final int? salidaId;
  final int? sucursalId;
  final int? cierreCajaId;
  final String? fecha;
  final String? fechaHora;
  final String? tipo;
  final String? categoria;
  final String? descripcion;
  final double? valor;
  final int? gastoId;
  final int? pedidoId;
  final String? medioPagoNombre;
  final bool? afectaResultado;
  final String? estado;
  final String? registradoPor;

  factory SalidaCajaModel.fromJson(Map<String, dynamic> json) => SalidaCajaModel(
        salidaId: (json['salidaId'] as num?)?.toInt(),
        sucursalId: (json['sucursalId'] as num?)?.toInt(),
        cierreCajaId: (json['cierreCajaId'] as num?)?.toInt(),
        fecha: json['fecha']?.toString(),
        fechaHora: json['fechaHora']?.toString(),
        tipo: json['tipo']?.toString(),
        categoria: json['categoria']?.toString(),
        descripcion: json['descripcion']?.toString(),
        valor: (json['valor'] as num?)?.toDouble(),
        gastoId: (json['gastoId'] as num?)?.toInt(),
        pedidoId: (json['pedidoId'] as num?)?.toInt(),
        medioPagoNombre: json['medioPagoNombre']?.toString(),
        afectaResultado: json['afectaResultado'] as bool?,
        estado: json['estado']?.toString(),
        registradoPor: json['registradoPor']?.toString(),
      );
}

class SalidaCajaGastoOpcionModel {
  const SalidaCajaGastoOpcionModel({
    required this.id,
    required this.nombre,
    this.categoria,
    this.tipo,
    this.valorConfigurado,
  });

  final int id;
  final String nombre;
  final String? categoria;
  final String? tipo;
  final double? valorConfigurado;

  factory SalidaCajaGastoOpcionModel.fromJson(Map<String, dynamic> json) =>
      SalidaCajaGastoOpcionModel(
        id: (json['id'] as num).toInt(),
        nombre: json['nombre']?.toString() ?? 'Gasto',
        categoria: json['categoria']?.toString(),
        tipo: json['tipo']?.toString(),
        valorConfigurado: (json['valorConfigurado'] as num?)?.toDouble(),
      );
}

class SalidaCajaPedidoOpcionModel {
  const SalidaCajaPedidoOpcionModel({
    required this.id,
    this.fecha,
    this.total = 0,
    this.pagado = 0,
    this.saldoPendiente = 0,
    this.estadoPago,
  });

  final int id;
  final String? fecha;
  final double total;
  final double pagado;
  final double saldoPendiente;
  final String? estadoPago;

  factory SalidaCajaPedidoOpcionModel.fromJson(Map<String, dynamic> json) =>
      SalidaCajaPedidoOpcionModel(
        id: (json['id'] as num).toInt(),
        fecha: json['fecha']?.toString(),
        total: (json['total'] as num?)?.toDouble() ?? 0,
        pagado: (json['pagado'] as num?)?.toDouble() ?? 0,
        saldoPendiente: (json['saldoPendiente'] as num?)?.toDouble() ?? 0,
        estadoPago: json['estadoPago']?.toString(),
      );
}

class SalidaCajaOpcionesModel {
  const SalidaCajaOpcionesModel({
    this.gastosConfigurados = const [],
    this.pedidosPendientes = const [],
  });

  final List<SalidaCajaGastoOpcionModel> gastosConfigurados;
  final List<SalidaCajaPedidoOpcionModel> pedidosPendientes;

  factory SalidaCajaOpcionesModel.fromJson(Map<String, dynamic> json) =>
      SalidaCajaOpcionesModel(
        gastosConfigurados: (json['gastosConfigurados'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SalidaCajaGastoOpcionModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
        pedidosPendientes: (json['pedidosPendientes'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SalidaCajaPedidoOpcionModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
}

class CierreCajaResumenModel {
  const CierreCajaResumenModel({
    this.cierreCajaId,
    this.fecha,
    this.fechaRegistro,
    this.sucursalId,
    this.cerrado,
    this.ventasIncluidas,
    this.ventasPendientes = const <CierreCajaVentaIncluidaModel>[],
    this.totalVentasPendientes,
    this.totalVendido,
    this.totalVentasSinPropina,
    this.totalPropinas,
    this.totalEntregado,
    this.valorBase,
    this.totalGastos,
    this.totalSalidasCaja,
    this.totalGastosTurno,
    this.totalPagosPedidos,
    this.totalPagosGastosConfigurados,
    this.totalCruce,
    this.diferencia,
    this.observacion,
    this.mediosPago = const <CierreCajaMedioPagoModel>[],
    this.gastos = const <CierreCajaGastoModel>[],
    this.salidasCaja = const <SalidaCajaModel>[],
    this.productos = const <CierreCajaProductoModel>[],
    this.ventas = const <CierreCajaVentaIncluidaModel>[],
  });
  final int? cierreCajaId;
  final String? fecha;
  final String? fechaRegistro;
  final int? sucursalId;
  final bool? cerrado;
  final int? ventasIncluidas;
  final List<CierreCajaVentaIncluidaModel> ventasPendientes;
  final double? totalVentasPendientes;
  final double? totalVendido;
  final double? totalVentasSinPropina;
  final double? totalPropinas;
  final double? totalEntregado;
  final double? valorBase;
  final double? totalGastos;
  final double? totalSalidasCaja;
  final double? totalGastosTurno;
  final double? totalPagosPedidos;
  final double? totalPagosGastosConfigurados;
  final double? totalCruce;
  final double? diferencia;
  final String? observacion;
  final List<CierreCajaMedioPagoModel> mediosPago;
  final List<CierreCajaGastoModel> gastos;
  final List<SalidaCajaModel> salidasCaja;
  final List<CierreCajaProductoModel> productos;
  final List<CierreCajaVentaIncluidaModel> ventas;
  factory CierreCajaResumenModel.fromJson(Map<String, dynamic> json) => CierreCajaResumenModel(
        cierreCajaId: (json['cierreCajaId'] as num?)?.toInt(),
        fecha: json['fecha']?.toString(),
        fechaRegistro: json['fechaRegistro']?.toString(),
        sucursalId: (json['sucursalId'] as num?)?.toInt(),
        cerrado: json['cerrado'] as bool?,
        ventasIncluidas: (json['ventasIncluidas'] as num?)?.toInt(),
        ventasPendientes: (json['ventasPendientes'] as List? ?? const [])
            .map((e) => CierreCajaVentaIncluidaModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        totalVentasPendientes: (json['totalVentasPendientes'] as num?)?.toDouble(),
        totalVendido: (json['totalVendido'] as num?)?.toDouble(),
        totalVentasSinPropina: (json['totalVentasSinPropina'] as num?)?.toDouble(),
        totalPropinas: (json['totalPropinas'] as num?)?.toDouble(),
        totalEntregado: (json['totalEntregado'] as num?)?.toDouble(),
        valorBase: (json['valorBase'] as num?)?.toDouble(),
        totalGastos: (json['totalGastos'] as num?)?.toDouble(),
        totalSalidasCaja: (json['totalSalidasCaja'] as num?)?.toDouble(),
        totalGastosTurno: (json['totalGastosTurno'] as num?)?.toDouble(),
        totalPagosPedidos: (json['totalPagosPedidos'] as num?)?.toDouble(),
        totalPagosGastosConfigurados:
            (json['totalPagosGastosConfigurados'] as num?)?.toDouble(),
        totalCruce: (json['totalCruce'] as num?)?.toDouble(),
        diferencia: (json['diferencia'] as num?)?.toDouble(),
        observacion: json['observacion']?.toString(),
        mediosPago: (json['mediosPago'] as List? ?? const [])
            .map((e) => CierreCajaMedioPagoModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        gastos: (json['gastos'] as List? ?? const [])
            .map((e) => CierreCajaGastoModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        salidasCaja: (json['salidasCaja'] as List? ?? const [])
            .map((e) => SalidaCajaModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        productos: (json['productos'] as List? ?? const [])
            .map((e) => CierreCajaProductoModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        ventas: (json['ventas'] as List? ?? const [])
            .map((e) => CierreCajaVentaIncluidaModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
      );
}
