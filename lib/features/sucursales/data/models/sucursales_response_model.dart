/// Modelo de respuesta del módulo Sucursales basado en la colección Postman.
class SucursalesResponseModel {
  const SucursalesResponseModel({
    this.sucuId,
    this.emprId,
    this.ciudId,
    this.zohoId,
    this.moneId,
    this.paisIdtelefono,
    this.sucuNombre,
    this.sucuCodigoInterno,
    this.sucuDireccion,
    this.sucuTelefono,
    this.sucuFoto,
    this.sucuEstado,
    this.sucuRegistradoPor,
    this.sucuFechaCambio,
  });

  final int? sucuId;
  final int? emprId;
  final int? ciudId;
  final int? zohoId;
  final int? moneId;
  final int? paisIdtelefono;
  final String? sucuNombre;
  final String? sucuCodigoInterno;
  final String? sucuDireccion;
  final String? sucuTelefono;
  final String? sucuFoto;
  final int? sucuEstado;
  final String? sucuRegistradoPor;
  final String? sucuFechaCambio;

  factory SucursalesResponseModel.fromJson(Map<String, dynamic> json) => SucursalesResponseModel(
      sucuId: (json['sucuId'] as num?)?.toInt(),
      emprId: (json['emprId'] as num?)?.toInt(),
      ciudId: (json['ciudId'] as num?)?.toInt(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
      moneId: (json['moneId'] as num?)?.toInt(),
      paisIdtelefono: (json['paisIdtelefono'] as num?)?.toInt(),
      sucuNombre: json['sucuNombre']?.toString(),
      sucuCodigoInterno: json['sucuCodigoInterno']?.toString(),
      sucuDireccion: json['sucuDireccion']?.toString(),
      sucuTelefono: json['sucuTelefono']?.toString(),
      sucuFoto: json['sucuFoto']?.toString(),
      sucuEstado: (json['sucuEstado'] as num?)?.toInt(),
      sucuRegistradoPor: json['sucuRegistradoPor']?.toString(),
      sucuFechaCambio: json['sucuFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'sucuId': sucuId,
      'emprId': emprId,
      'ciudId': ciudId,
      'zohoId': zohoId,
      'moneId': moneId,
      'paisIdtelefono': paisIdtelefono,
      'sucuNombre': sucuNombre,
      'sucuCodigoInterno': sucuCodigoInterno,
      'sucuDireccion': sucuDireccion,
      'sucuTelefono': sucuTelefono,
      'sucuFoto': sucuFoto,
      'sucuEstado': sucuEstado,
      'sucuRegistradoPor': sucuRegistradoPor,
      'sucuFechaCambio': sucuFechaCambio,
  };

  Object? get id => sucuId;

  String label() {
    final name = sucuNombre?.trim();
    if (name != null && name.isNotEmpty) return name;
    final code = sucuCodigoInterno?.trim();
    if (code != null && code.isNotEmpty) return code;
    return sucuId == null ? 'Sucursal' : 'Sucursal #$sucuId';
  }
}
