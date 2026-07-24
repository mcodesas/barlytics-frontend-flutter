/// Modelo de respuesta del módulo Ventas basado en la colección Postman.
class VentasResponseModel {
  const VentasResponseModel({
    this.ventId,
    this.mesaId,
    this.ventFecha,
    this.ventEstado,
    this.ventTotal,
    this.ventPropina,
    this.ventRegistradoPor,
    this.ventFechaCambio,
  });

  final int? ventId;
  final int? mesaId;
  final String? ventFecha;
  final String? ventEstado;
  final double? ventTotal;
  final double? ventPropina;
  final String? ventRegistradoPor;
  final String? ventFechaCambio;

  factory VentasResponseModel.fromJson(Map<String, dynamic> json) => VentasResponseModel(
      ventId: (json['ventId'] as num?)?.toInt(),
      mesaId: (json['mesaId'] as num?)?.toInt(),
      ventFecha: json['ventFecha']?.toString(),
      ventEstado: json['ventEstado']?.toString(),
      ventTotal: (json['ventTotal'] as num?)?.toDouble(),
      ventPropina: (json['ventPropina'] as num?)?.toDouble(),
      ventRegistradoPor: json['ventRegistradoPor']?.toString(),
      ventFechaCambio: json['ventFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'ventId': ventId,
      'mesaId': mesaId,
      'ventFecha': ventFecha,
      'ventEstado': ventEstado,
      'ventTotal': ventTotal,
      'ventPropina': ventPropina,
      'ventRegistradoPor': ventRegistradoPor,
      'ventFechaCambio': ventFechaCambio,
  };

  Object? get id => ventId;

  String label() {
    final values = <Object?>[ventId, mesaId, ventFecha, ventEstado];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
