/// Modelo de request para crear o actualizar registros del módulo Mesas.
class MesasRequestModel {
  const MesasRequestModel({
    this.mesaEstado,
    this.mesaNumero,
    this.sucuId,
    this.mesaDescripcion,
    this.mesaFoto,
  });

  final String? mesaEstado;
  final int? mesaNumero;
  final int? sucuId;
  final String? mesaDescripcion;
  final String? mesaFoto;

  factory MesasRequestModel.fromJson(Map<String, dynamic> json) => MesasRequestModel(
      mesaEstado: json['mesaEstado']?.toString(),
      mesaNumero: (json['mesaNumero'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      mesaDescripcion: json['mesaDescripcion']?.toString(),
      mesaFoto: json['mesaFoto']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (mesaEstado != null) 'mesaEstado': mesaEstado,
      if (mesaNumero != null) 'mesaNumero': mesaNumero,
      if (sucuId != null) 'sucuId': sucuId,
      if (mesaDescripcion != null) 'mesaDescripcion': mesaDescripcion,
      if (mesaFoto != null) 'mesaFoto': mesaFoto,
  };
}
