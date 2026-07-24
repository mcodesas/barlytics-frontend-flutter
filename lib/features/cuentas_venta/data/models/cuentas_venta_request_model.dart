/// Modelo de request para crear o actualizar registros del módulo Cuentas venta.
class CuentasVentaRequestModel {
  const CuentasVentaRequestModel({
    this.cuevEstado,
    this.cuevDescripcion,
    this.cuevNumero,
    this.cuevPropina,
    this.cuevTotal,
    this.ventId,
  });

  final int? cuevEstado;
  final String? cuevDescripcion;
  final int? cuevNumero;
  final double? cuevPropina;
  final double? cuevTotal;
  final int? ventId;

  factory CuentasVentaRequestModel.fromJson(Map<String, dynamic> json) => CuentasVentaRequestModel(
      cuevEstado: (json['cuevEstado'] as num?)?.toInt(),
      cuevDescripcion: json['cuevDescripcion']?.toString(),
      cuevNumero: (json['cuevNumero'] as num?)?.toInt(),
      cuevPropina: (json['cuevPropina'] as num?)?.toDouble(),
      cuevTotal: (json['cuevTotal'] as num?)?.toDouble(),
      ventId: (json['ventId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (cuevEstado != null) 'cuevEstado': cuevEstado,
      if ((cuevDescripcion ?? '').trim().isNotEmpty) 'cuevDescripcion': cuevDescripcion!.trim(),
      if (cuevNumero != null) 'cuevNumero': cuevNumero,
      if (cuevPropina != null) 'cuevPropina': cuevPropina,
      if (cuevTotal != null) 'cuevTotal': cuevTotal,
      if (ventId != null) 'ventId': ventId,
  };
}
