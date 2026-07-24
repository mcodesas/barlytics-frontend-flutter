/// Modelo de respuesta del módulo Monedas basado en la colección Postman.
class MonedasResponseModel {
  const MonedasResponseModel({
    this.moneId,
    this.moneCodigoiso,
    this.moneNombre,
    this.moneSimbolo,
    this.moneDecimales,
    this.moneEstado,
    this.moneRegistradoPor,
    this.moneFechaCambio,
  });

  final int? moneId;
  final String? moneCodigoiso;
  final String? moneNombre;
  final String? moneSimbolo;
  final int? moneDecimales;
  final int? moneEstado;
  final String? moneRegistradoPor;
  final String? moneFechaCambio;

  factory MonedasResponseModel.fromJson(Map<String, dynamic> json) => MonedasResponseModel(
      moneId: (json['moneId'] as num?)?.toInt(),
      moneCodigoiso: json['moneCodigoiso']?.toString(),
      moneNombre: json['moneNombre']?.toString(),
      moneSimbolo: json['moneSimbolo']?.toString(),
      moneDecimales: (json['moneDecimales'] as num?)?.toInt(),
      moneEstado: (json['moneEstado'] as num?)?.toInt(),
      moneRegistradoPor: json['moneRegistradoPor']?.toString(),
      moneFechaCambio: json['moneFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'moneId': moneId,
      'moneCodigoiso': moneCodigoiso,
      'moneNombre': moneNombre,
      'moneSimbolo': moneSimbolo,
      'moneDecimales': moneDecimales,
      'moneEstado': moneEstado,
      'moneRegistradoPor': moneRegistradoPor,
      'moneFechaCambio': moneFechaCambio,
  };

  Object? get id => moneId;

  String label() {
    final values = <Object?>[moneId, moneCodigoiso, moneNombre, moneSimbolo];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
