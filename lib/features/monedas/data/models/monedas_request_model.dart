/// Modelo de request para crear o actualizar registros del módulo Monedas.
class MonedasRequestModel {
  const MonedasRequestModel({
    this.moneCodigoiso,
    this.moneDecimales,
    this.moneEstado,
    this.moneNombre,
    this.moneSimbolo,
  });

  final String? moneCodigoiso;
  final int? moneDecimales;
  final int? moneEstado;
  final String? moneNombre;
  final String? moneSimbolo;

  factory MonedasRequestModel.fromJson(Map<String, dynamic> json) => MonedasRequestModel(
      moneCodigoiso: json['moneCodigoiso']?.toString(),
      moneDecimales: (json['moneDecimales'] as num?)?.toInt(),
      moneEstado: (json['moneEstado'] as num?)?.toInt(),
      moneNombre: json['moneNombre']?.toString(),
      moneSimbolo: json['moneSimbolo']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (moneCodigoiso != null) 'moneCodigoiso': moneCodigoiso,
      if (moneDecimales != null) 'moneDecimales': moneDecimales,
      if (moneEstado != null) 'moneEstado': moneEstado,
      if (moneNombre != null) 'moneNombre': moneNombre,
      if (moneSimbolo != null) 'moneSimbolo': moneSimbolo,
  };
}
