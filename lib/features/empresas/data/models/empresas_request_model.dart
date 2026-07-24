/// Modelo de request para crear o actualizar registros del módulo Empresas.
class EmpresasRequestModel {
  const EmpresasRequestModel({
    this.ciudId,
    this.emprCorreoElectronico,
    this.emprDireccion,
    this.emprEstado,
    this.emprIdentificacion,
    this.emprRazonSocial,
    this.emprTelefono,
    this.empreNombreComercial,
    this.paisIdtelefono,
    this.tiidId,
    this.zohoId,
    this.emprCodigoPostal,
    this.emprSitioWeb,
    this.emprLogo,
  });

  final int? ciudId;
  final String? emprCorreoElectronico;
  final String? emprDireccion;
  final int? emprEstado;
  final String? emprIdentificacion;
  final String? emprRazonSocial;
  final String? emprTelefono;
  final String? empreNombreComercial;
  final int? paisIdtelefono;
  final int? tiidId;
  final int? zohoId;
  final String? emprCodigoPostal;
  final String? emprSitioWeb;
  final String? emprLogo;

  factory EmpresasRequestModel.fromJson(Map<String, dynamic> json) => EmpresasRequestModel(
      ciudId: (json['ciudId'] as num?)?.toInt(),
      emprCorreoElectronico: json['emprCorreoElectronico']?.toString(),
      emprDireccion: json['emprDireccion']?.toString(),
      emprEstado: (json['emprEstado'] as num?)?.toInt(),
      emprIdentificacion: json['emprIdentificacion']?.toString(),
      emprRazonSocial: json['emprRazonSocial']?.toString(),
      emprTelefono: json['emprTelefono']?.toString(),
      empreNombreComercial: json['empreNombreComercial']?.toString(),
      paisIdtelefono: (json['paisIdtelefono'] as num?)?.toInt(),
      tiidId: (json['tiidId'] as num?)?.toInt(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
      emprCodigoPostal: json['emprCodigoPostal']?.toString(),
      emprSitioWeb: json['emprSitioWeb']?.toString(),
      emprLogo: json['emprLogo']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (ciudId != null) 'ciudId': ciudId,
      if (emprCorreoElectronico != null) 'emprCorreoElectronico': emprCorreoElectronico,
      if (emprDireccion != null) 'emprDireccion': emprDireccion,
      if (emprEstado != null) 'emprEstado': emprEstado,
      if (emprIdentificacion != null) 'emprIdentificacion': emprIdentificacion,
      if (emprRazonSocial != null) 'emprRazonSocial': emprRazonSocial,
      if (emprTelefono != null) 'emprTelefono': emprTelefono,
      if (empreNombreComercial != null) 'empreNombreComercial': empreNombreComercial,
      if (paisIdtelefono != null) 'paisIdtelefono': paisIdtelefono,
      if (tiidId != null) 'tiidId': tiidId,
      if (zohoId != null) 'zohoId': zohoId,
      if (emprCodigoPostal != null) 'emprCodigoPostal': emprCodigoPostal,
      if (emprSitioWeb != null) 'emprSitioWeb': emprSitioWeb,
      if (emprLogo != null) 'emprLogo': emprLogo,
  };
}
