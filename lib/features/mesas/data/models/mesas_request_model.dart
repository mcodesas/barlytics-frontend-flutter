/// Modelo de request para crear o actualizar registros del módulo Mesas.
class MesasRequestModel {
  const MesasRequestModel({
    this.mesaEstado,
    this.mesaNumero,
    this.sucuId,
  });

  final String? mesaEstado;
  final int? mesaNumero;
  final int? sucuId;

  factory MesasRequestModel.fromJson(Map<String, dynamic> json) => MesasRequestModel(
      mesaEstado: json['mesaEstado']?.toString(),
      mesaNumero: (json['mesaNumero'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (mesaEstado != null) 'mesaEstado': mesaEstado,
      if (mesaNumero != null) 'mesaNumero': mesaNumero,
      if (sucuId != null) 'sucuId': sucuId,
  };
}
