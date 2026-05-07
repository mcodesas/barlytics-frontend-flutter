/// Modelo de request para crear o actualizar registros del módulo Cuentas venta.
class CuentasVentaRequestModel {
  const CuentasVentaRequestModel({
    this.cuevEstado,
    this.cuevNumero,
    this.cuevPropina,
    this.cuevTotal,
    this.ventId,
  });

  final int? cuevEstado;
  final int? cuevNumero;
  final double? cuevPropina;
  final double? cuevTotal;
  final int? ventId;

  factory CuentasVentaRequestModel.fromJson(Map<String, dynamic> json) => CuentasVentaRequestModel(
      cuevEstado: (json['cuevEstado'] as num?)?.toInt(),
      cuevNumero: (json['cuevNumero'] as num?)?.toInt(),
      cuevPropina: (json['cuevPropina'] as num?)?.toDouble(),
      cuevTotal: (json['cuevTotal'] as num?)?.toDouble(),
      ventId: (json['ventId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (cuevEstado != null) 'cuevEstado': cuevEstado,
      if (cuevNumero != null) 'cuevNumero': cuevNumero,
      if (cuevPropina != null) 'cuevPropina': cuevPropina,
      if (cuevTotal != null) 'cuevTotal': cuevTotal,
      if (ventId != null) 'ventId': ventId,
  };
}
