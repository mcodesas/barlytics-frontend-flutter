/// Modelo de respuesta del módulo Tipos producto basado en la colección Postman.
class TiposProductoResponseModel {
  const TiposProductoResponseModel({
    this.tpprId,
    this.tpprNombre,
    this.tpprDescripcion,
    this.tpprCreadoPor,
    this.tpprFechaCreacion,
  });

  final int? tpprId;
  final String? tpprNombre;
  final String? tpprDescripcion;
  final String? tpprCreadoPor;
  final String? tpprFechaCreacion;

  factory TiposProductoResponseModel.fromJson(Map<String, dynamic> json) => TiposProductoResponseModel(
      tpprId: (json['tpprId'] as num?)?.toInt(),
      tpprNombre: json['tpprNombre']?.toString(),
      tpprDescripcion: json['tpprDescripcion']?.toString(),
      tpprCreadoPor: json['tpprCreadoPor']?.toString(),
      tpprFechaCreacion: json['tpprFechaCreacion']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'tpprId': tpprId,
      'tpprNombre': tpprNombre,
      'tpprDescripcion': tpprDescripcion,
      'tpprCreadoPor': tpprCreadoPor,
      'tpprFechaCreacion': tpprFechaCreacion,
  };

  Object? get id => tpprId;

  String label() {
    final values = <Object?>[tpprId, tpprNombre, tpprDescripcion, tpprCreadoPor];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
