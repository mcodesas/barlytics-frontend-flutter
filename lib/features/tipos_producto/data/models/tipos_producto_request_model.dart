/// Modelo de request para crear o actualizar registros del módulo Tipos producto.
class TiposProductoRequestModel {
  const TiposProductoRequestModel({
    this.tpprDescripcion,
    this.tpprNombre,
  });

  final String? tpprDescripcion;
  final String? tpprNombre;

  factory TiposProductoRequestModel.fromJson(Map<String, dynamic> json) => TiposProductoRequestModel(
      tpprDescripcion: json['tpprDescripcion']?.toString(),
      tpprNombre: json['tpprNombre']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      if (tpprDescripcion != null) 'tpprDescripcion': tpprDescripcion,
      if (tpprNombre != null) 'tpprNombre': tpprNombre,
  };
}
