/// Modelo de request para crear o actualizar registros del módulo Parametros.
class ParametrosRequestModel {
  const ParametrosRequestModel({
    this.paraCodigo,
    this.paraDescripcion,
    this.paraEditable,
    this.paraEstado,
    this.paraGrupo,
    this.paraNombre,
    this.paraTipoDato,
    this.paraValor,
    this.emprId,
    this.sucuId,
    this.paraValorDefecto,
  });

  final String? paraCodigo;
  final String? paraDescripcion;
  final int? paraEditable;
  final int? paraEstado;
  final String? paraGrupo;
  final String? paraNombre;
  final String? paraTipoDato;
  final String? paraValor;
  final int? emprId;
  final int? sucuId;
  final String? paraValorDefecto;

  factory ParametrosRequestModel.fromJson(Map<String, dynamic> json) => ParametrosRequestModel(
      paraCodigo: json['paraCodigo']?.toString(),
      paraDescripcion: json['paraDescripcion']?.toString(),
      paraEditable: (json['paraEditable'] as num?)?.toInt(),
      paraEstado: (json['paraEstado'] as num?)?.toInt(),
      paraGrupo: json['paraGrupo']?.toString(),
      paraNombre: json['paraNombre']?.toString(),
      paraTipoDato: json['paraTipoDato']?.toString(),
      paraValor: json['paraValor']?.toString(),
      emprId: (json['emprId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      paraValorDefecto: json['paraValorDefecto']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (paraCodigo != null) 'paraCodigo': paraCodigo,
      if (paraDescripcion != null) 'paraDescripcion': paraDescripcion,
      if (paraEditable != null) 'paraEditable': paraEditable,
      if (paraEstado != null) 'paraEstado': paraEstado,
      if (paraGrupo != null) 'paraGrupo': paraGrupo,
      if (paraNombre != null) 'paraNombre': paraNombre,
      if (paraTipoDato != null) 'paraTipoDato': paraTipoDato,
      if (paraValor != null) 'paraValor': paraValor,
      if (emprId != null) 'emprId': emprId,
      if (sucuId != null) 'sucuId': sucuId,
      if (paraValorDefecto != null) 'paraValorDefecto': paraValorDefecto,
  };
}
