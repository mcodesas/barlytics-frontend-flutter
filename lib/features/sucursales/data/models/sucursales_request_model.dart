/// Modelo de request para crear o actualizar registros del módulo Sucursales.
class SucursalesRequestModel {
  const SucursalesRequestModel({
    this.ciudId,
    this.emprId,
    this.moneId,
    this.paisIdtelefono,
    this.sucuCodigoInterno,
    this.sucuDireccion,
    this.sucuEstado,
    this.sucuNombre,
    this.sucuTelefono,
    this.zohoId,
  });

  final int? ciudId;
  final int? emprId;
  final int? moneId;
  final int? paisIdtelefono;
  final String? sucuCodigoInterno;
  final String? sucuDireccion;
  final int? sucuEstado;
  final String? sucuNombre;
  final String? sucuTelefono;
  final int? zohoId;

  factory SucursalesRequestModel.fromJson(Map<String, dynamic> json) => SucursalesRequestModel(
      ciudId: (json['ciudId'] as num?)?.toInt(),
      emprId: (json['emprId'] as num?)?.toInt(),
      moneId: (json['moneId'] as num?)?.toInt(),
      paisIdtelefono: (json['paisIdtelefono'] as num?)?.toInt(),
      sucuCodigoInterno: json['sucuCodigoInterno']?.toString(),
      sucuDireccion: json['sucuDireccion']?.toString(),
      sucuEstado: (json['sucuEstado'] as num?)?.toInt(),
      sucuNombre: json['sucuNombre']?.toString(),
      sucuTelefono: json['sucuTelefono']?.toString(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (ciudId != null) 'ciudId': ciudId,
      if (emprId != null) 'emprId': emprId,
      if (moneId != null) 'moneId': moneId,
      if (paisIdtelefono != null) 'paisIdtelefono': paisIdtelefono,
      if (sucuCodigoInterno != null) 'sucuCodigoInterno': sucuCodigoInterno,
      if (sucuDireccion != null) 'sucuDireccion': sucuDireccion,
      if (sucuEstado != null) 'sucuEstado': sucuEstado,
      if (sucuNombre != null) 'sucuNombre': sucuNombre,
      if (sucuTelefono != null) 'sucuTelefono': sucuTelefono,
      if (zohoId != null) 'zohoId': zohoId,
  };
}
