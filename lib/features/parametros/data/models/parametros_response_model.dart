/// Modelo de respuesta del módulo Parametros basado en la colección Postman.
class ParametrosResponseModel {
  const ParametrosResponseModel({
    this.paraId,
    this.emprId,
    this.sucuId,
    this.paraCodigo,
    this.paraNombre,
    this.paraDescripcion,
    this.paraTipoDato,
    this.paraValor,
    this.paraValorDefecto,
    this.paraGrupo,
    this.paraEditable,
    this.paraEstado,
    this.paraRegistradoPor,
    this.paraFechaCambio,
  });

  final int? paraId;
  final int? emprId;
  final int? sucuId;
  final String? paraCodigo;
  final String? paraNombre;
  final String? paraDescripcion;
  final String? paraTipoDato;
  final String? paraValor;
  final String? paraValorDefecto;
  final String? paraGrupo;
  final int? paraEditable;
  final int? paraEstado;
  final String? paraRegistradoPor;
  final String? paraFechaCambio;

  factory ParametrosResponseModel.fromJson(Map<String, dynamic> json) => ParametrosResponseModel(
      paraId: (json['paraId'] as num?)?.toInt(),
      emprId: (json['emprId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      paraCodigo: json['paraCodigo']?.toString(),
      paraNombre: json['paraNombre']?.toString(),
      paraDescripcion: json['paraDescripcion']?.toString(),
      paraTipoDato: json['paraTipoDato']?.toString(),
      paraValor: json['paraValor']?.toString(),
      paraValorDefecto: json['paraValorDefecto']?.toString(),
      paraGrupo: json['paraGrupo']?.toString(),
      paraEditable: (json['paraEditable'] as num?)?.toInt(),
      paraEstado: (json['paraEstado'] as num?)?.toInt(),
      paraRegistradoPor: json['paraRegistradoPor']?.toString(),
      paraFechaCambio: json['paraFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'paraId': paraId,
      'emprId': emprId,
      'sucuId': sucuId,
      'paraCodigo': paraCodigo,
      'paraNombre': paraNombre,
      'paraDescripcion': paraDescripcion,
      'paraTipoDato': paraTipoDato,
      'paraValor': paraValor,
      'paraValorDefecto': paraValorDefecto,
      'paraGrupo': paraGrupo,
      'paraEditable': paraEditable,
      'paraEstado': paraEstado,
      'paraRegistradoPor': paraRegistradoPor,
      'paraFechaCambio': paraFechaCambio,
  };

  Object? get id => paraId;

  String label() {
    final values = <Object?>[paraId, emprId, sucuId, paraCodigo];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
