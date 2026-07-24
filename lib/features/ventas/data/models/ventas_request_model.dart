/// Modelo de request para crear o actualizar registros del módulo Ventas.
class VentasRequestModel {
  const VentasRequestModel({
    this.mesaId,
    this.ventEstado,
    this.ventFecha,
    this.ventPropina,
    this.ventTotal,
  });

  final int? mesaId;
  final String? ventEstado;
  final String? ventFecha;
  final double? ventPropina;
  final double? ventTotal;

  factory VentasRequestModel.fromJson(Map<String, dynamic> json) => VentasRequestModel(
      mesaId: (json['mesaId'] as num?)?.toInt(),
      ventEstado: json['ventEstado']?.toString(),
      ventFecha: json['ventFecha']?.toString(),
      ventPropina: (json['ventPropina'] as num?)?.toDouble(),
      ventTotal: (json['ventTotal'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (mesaId != null) 'mesaId': mesaId,
      if (ventEstado != null) 'ventEstado': ventEstado,
      if (ventFecha != null) 'ventFecha': ventFecha,
      if (ventPropina != null) 'ventPropina': ventPropina,
      if (ventTotal != null) 'ventTotal': ventTotal,
  };
}
