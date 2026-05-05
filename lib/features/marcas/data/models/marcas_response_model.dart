/// Modelo de respuesta del módulo Marcas basado en la colección Postman.
class MarcasResponseModel {
  const MarcasResponseModel({
    this.mrcaId,
    this.mrcaNombre,
    this.mrcaIdentificacion,
    this.mrcaLogo,
    this.mrcaCreadoPor,
    this.mrcaFechaCambio,
  });

  final int? mrcaId;
  final String? mrcaNombre;
  final String? mrcaIdentificacion;
  final String? mrcaLogo;
  final String? mrcaCreadoPor;
  final String? mrcaFechaCambio;

  factory MarcasResponseModel.fromJson(Map<String, dynamic> json) => MarcasResponseModel(
      mrcaId: (json['mrcaId'] as num?)?.toInt(),
      mrcaNombre: json['mrcaNombre']?.toString(),
      mrcaIdentificacion: json['mrcaIdentificacion']?.toString(),
      mrcaLogo: json['mrcaLogo']?.toString(),
      mrcaCreadoPor: json['mrcaCreadoPor']?.toString(),
      mrcaFechaCambio: json['mrcaFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'mrcaId': mrcaId,
      'mrcaNombre': mrcaNombre,
      'mrcaIdentificacion': mrcaIdentificacion,
      'mrcaLogo': mrcaLogo,
      'mrcaCreadoPor': mrcaCreadoPor,
      'mrcaFechaCambio': mrcaFechaCambio,
  };

  Object? get id => mrcaId;

  String label() {
    final values = <Object?>[mrcaId, mrcaNombre, mrcaIdentificacion, mrcaLogo];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
