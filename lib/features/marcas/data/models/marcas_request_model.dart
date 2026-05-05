/// Modelo de request para crear o actualizar registros del módulo Marcas.
class MarcasRequestModel {
  const MarcasRequestModel({
    this.mrcaNombre,
    this.mrcaIdentificacion,
    this.mrcaLogo,
  });

  final String? mrcaNombre;
  final String? mrcaIdentificacion;
  final String? mrcaLogo;

  factory MarcasRequestModel.fromJson(Map<String, dynamic> json) => MarcasRequestModel(
      mrcaNombre: json['mrcaNombre']?.toString(),
      mrcaIdentificacion: json['mrcaIdentificacion']?.toString(),
      mrcaLogo: json['mrcaLogo']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (mrcaNombre != null) 'mrcaNombre': mrcaNombre,
      if (mrcaIdentificacion != null) 'mrcaIdentificacion': mrcaIdentificacion,
      if (mrcaLogo != null) 'mrcaLogo': mrcaLogo,
  };
}
