/// Modelo de respuesta del módulo Ciudades basado en la colección Postman.
class CiudadesResponseModel {
  const CiudadesResponseModel({
    this.ciudId,
    this.regiId,
    this.zohoId,
    this.ciudNombre,
    this.ciudCodigoDane,
    this.ciudCodigoPostal,
    this.ciudEstado,
    this.ciudRegistradoPor,
    this.ciudFechaCambio,
  });

  final int? ciudId;
  final int? regiId;
  final int? zohoId;
  final String? ciudNombre;
  final String? ciudCodigoDane;
  final String? ciudCodigoPostal;
  final int? ciudEstado;
  final String? ciudRegistradoPor;
  final String? ciudFechaCambio;

  factory CiudadesResponseModel.fromJson(Map<String, dynamic> json) => CiudadesResponseModel(
      ciudId: (json['ciudId'] as num?)?.toInt(),
      regiId: (json['regiId'] as num?)?.toInt(),
      zohoId: (json['zohoId'] as num?)?.toInt(),
      ciudNombre: json['ciudNombre']?.toString(),
      ciudCodigoDane: json['ciudCodigoDane']?.toString(),
      ciudCodigoPostal: json['ciudCodigoPostal']?.toString(),
      ciudEstado: (json['ciudEstado'] as num?)?.toInt(),
      ciudRegistradoPor: json['ciudRegistradoPor']?.toString(),
      ciudFechaCambio: json['ciudFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'ciudId': ciudId,
      'regiId': regiId,
      'zohoId': zohoId,
      'ciudNombre': ciudNombre,
      'ciudCodigoDane': ciudCodigoDane,
      'ciudCodigoPostal': ciudCodigoPostal,
      'ciudEstado': ciudEstado,
      'ciudRegistradoPor': ciudRegistradoPor,
      'ciudFechaCambio': ciudFechaCambio,
  };

  Object? get id => ciudId;

  String label() {
    final values = <Object?>[ciudId, regiId, zohoId, ciudNombre];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
