/// Modelo de respuesta del módulo Empresas basado en la colección Postman.
class EmpresasResponseModel {
  const EmpresasResponseModel({
    this.emprId,
    this.tiidId,
    this.paisIdtelefono,
    this.ciudId,
    this.zohoId,
    this.empreNombreComercial,
    this.emprRazonSocial,
    this.emprIdentificacion,
    this.emprDireccion,
    this.emprCodigoPostal,
    this.emprTelefono,
    this.emprCorreoElectronico,
    this.emprSitioWeb,
    this.emprLogo,
    this.emprEstado,
    this.emprRegistradoPor,
    this.emprFechaCambio,
  });

  final int? emprId;
  final int? tiidId;
  final int? paisIdtelefono;
  final int? ciudId;
  final int? zohoId;
  final String? empreNombreComercial;
  final String? emprRazonSocial;
  final String? emprIdentificacion;
  final String? emprDireccion;
  final String? emprCodigoPostal;
  final String? emprTelefono;
  final String? emprCorreoElectronico;
  final String? emprSitioWeb;
  final String? emprLogo;
  final int? emprEstado;
  final String? emprRegistradoPor;
  final String? emprFechaCambio;

  factory EmpresasResponseModel.fromJson(Map<String, dynamic> json) => EmpresasResponseModel(
      emprId: (json['emprId'] as num?)?.toInt(),
      tiidId: (json['tiidId'] as num?)?.toInt(),
      paisIdtelefono: (json['paisIdtelefono'] as num?)?.toInt(),
      ciudId: (json['ciudId'] as num?)?.toInt(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
      empreNombreComercial: json['empreNombreComercial']?.toString(),
      emprRazonSocial: json['emprRazonSocial']?.toString(),
      emprIdentificacion: json['emprIdentificacion']?.toString(),
      emprDireccion: json['emprDireccion']?.toString(),
      emprCodigoPostal: json['emprCodigoPostal']?.toString(),
      emprTelefono: json['emprTelefono']?.toString(),
      emprCorreoElectronico: json['emprCorreoElectronico']?.toString(),
      emprSitioWeb: json['emprSitioWeb']?.toString(),
      emprLogo: json['emprLogo']?.toString(),
      emprEstado: (json['emprEstado'] as num?)?.toInt(),
      emprRegistradoPor: json['emprRegistradoPor']?.toString(),
      emprFechaCambio: json['emprFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'emprId': emprId,
      'tiidId': tiidId,
      'paisIdtelefono': paisIdtelefono,
      'ciudId': ciudId,
      'zohoId': zohoId,
      'empreNombreComercial': empreNombreComercial,
      'emprRazonSocial': emprRazonSocial,
      'emprIdentificacion': emprIdentificacion,
      'emprDireccion': emprDireccion,
      'emprCodigoPostal': emprCodigoPostal,
      'emprTelefono': emprTelefono,
      'emprCorreoElectronico': emprCorreoElectronico,
      'emprSitioWeb': emprSitioWeb,
      'emprLogo': emprLogo,
      'emprEstado': emprEstado,
      'emprRegistradoPor': emprRegistradoPor,
      'emprFechaCambio': emprFechaCambio,
  };

  Object? get id => emprId;

  String label() {
    final values = <Object?>[emprId, tiidId, paisIdtelefono, ciudId];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
