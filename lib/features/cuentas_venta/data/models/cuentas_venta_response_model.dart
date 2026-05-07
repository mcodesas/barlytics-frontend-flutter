/// Modelo de respuesta del módulo Cuentas venta basado en la colección Postman.
class CuentasVentaResponseModel {
  const CuentasVentaResponseModel({
    this.cuveId,
    this.ventId,
    this.cuevNumero,
    this.cuevTotal,
    this.cuevPropina,
    this.cuevEstado,
    this.cuevRegistradoPor,
    this.cuevFechaCambio,
  });

  final int? cuveId;
  final int? ventId;
  final int? cuevNumero;
  final double? cuevTotal;
  final double? cuevPropina;
  final int? cuevEstado;
  final String? cuevRegistradoPor;
  final String? cuevFechaCambio;

  factory CuentasVentaResponseModel.fromJson(Map<String, dynamic> json) => CuentasVentaResponseModel(
      cuveId: (json['cuveId'] as num?)?.toInt(),
      ventId: (json['ventId'] as num?)?.toInt(),
      cuevNumero: (json['cuevNumero'] as num?)?.toInt(),
      cuevTotal: (json['cuevTotal'] as num?)?.toDouble(),
      cuevPropina: (json['cuevPropina'] as num?)?.toDouble(),
      cuevEstado: (json['cuevEstado'] as num?)?.toInt(),
      cuevRegistradoPor: json['cuevRegistradoPor']?.toString(),
      cuevFechaCambio: json['cuevFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'cuveId': cuveId,
      'ventId': ventId,
      'cuevNumero': cuevNumero,
      'cuevTotal': cuevTotal,
      'cuevPropina': cuevPropina,
      'cuevEstado': cuevEstado,
      'cuevRegistradoPor': cuevRegistradoPor,
      'cuevFechaCambio': cuevFechaCambio,
  };

  Object? get id => cuveId;

  String label() {
    final values = <Object?>[cuveId, ventId, cuevNumero, cuevTotal];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
