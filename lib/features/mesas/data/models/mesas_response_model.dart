/// Modelo de respuesta del módulo Mesas basado en la colección Postman.
class MesasResponseModel {
  const MesasResponseModel({
    this.mesaId,
    this.sucuId,
    this.mesaNumero,
    this.mesaEstado,
    this.mesaRegistradoPor,
    this.mesaFechaCambio,
  });

  final int? mesaId;
  final int? sucuId;
  final int? mesaNumero;
  final String? mesaEstado;
  final String? mesaRegistradoPor;
  final String? mesaFechaCambio;

  factory MesasResponseModel.fromJson(Map<String, dynamic> json) => MesasResponseModel(
      mesaId: (json['mesaId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      mesaNumero: (json['mesaNumero'] as num?)?.toInt(),
      mesaEstado: json['mesaEstado']?.toString(),
      mesaRegistradoPor: json['mesaRegistradoPor']?.toString(),
      mesaFechaCambio: json['mesaFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'mesaId': mesaId,
      'sucuId': sucuId,
      'mesaNumero': mesaNumero,
      'mesaEstado': mesaEstado,
      'mesaRegistradoPor': mesaRegistradoPor,
      'mesaFechaCambio': mesaFechaCambio,
  };

  Object? get id => mesaId;

  String label() {
    final values = <Object?>[mesaId, sucuId, mesaNumero, mesaEstado];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
