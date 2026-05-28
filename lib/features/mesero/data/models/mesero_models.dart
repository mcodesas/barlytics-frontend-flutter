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
  });

  final int? medioPagoId;
  final String? nombre;
  final String? descripcion;

  factory MeseroMedioPagoModel.fromJson(Map<String, dynamic> json) => MeseroMedioPagoModel(
        medioPagoId: (json['medioPagoId'] as num?)?.toInt(),
        nombre: json['nombre']?.toString(),
        descripcion: json['descripcion']?.toString(),
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
    this.subtotal,
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
  final double? subtotal;
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
        subtotal: (json['subtotal'] as num?)?.toDouble(),
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
