/// Modelo de respuesta del módulo Inventario basado en la colección Postman.
class InventarioResponseModel {
  const InventarioResponseModel({
    this.invtId,
    this.prodId,
    this.sucuId,
    this.invtCantidad,
    this.invtFecha,
    this.invtOrigen,
    this.invtCantidadEsperada,
    this.invtDiferencia,
    this.invtRegistradoPor,
    this.invtFechaCambio,
  });

  final int? invtId;
  final int? prodId;
  final int? sucuId;
  final double? invtCantidad;
  final String? invtFecha;
  final String? invtOrigen;
  final double? invtCantidadEsperada;
  final double? invtDiferencia;
  final String? invtRegistradoPor;
  final String? invtFechaCambio;

  factory InventarioResponseModel.fromJson(Map<String, dynamic> json) => InventarioResponseModel(
      invtId: (json['invtId'] as num?)?.toInt(),
      prodId: (json['prodId'] as num?)?.toInt(),
      sucuId: (json['sucuId'] as num?)?.toInt(),
      invtCantidad: (json['invtCantidad'] as num?)?.toDouble(),
      invtFecha: json['invtFecha']?.toString(),
      invtOrigen: json['invtOrigen']?.toString(),
      invtCantidadEsperada: (json['invtCantidadEsperada'] as num?)?.toDouble(),
      invtDiferencia: (json['invtDiferencia'] as num?)?.toDouble(),
      invtRegistradoPor: json['invtRegistradoPor']?.toString(),
      invtFechaCambio: json['invtFechaCambio']?.toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
      'invtId': invtId,
      'prodId': prodId,
      'sucuId': sucuId,
      'invtCantidad': invtCantidad,
      'invtFecha': invtFecha,
      'invtOrigen': invtOrigen,
      'invtCantidadEsperada': invtCantidadEsperada,
      'invtDiferencia': invtDiferencia,
      'invtRegistradoPor': invtRegistradoPor,
      'invtFechaCambio': invtFechaCambio,
  };

  Object? get id => invtId;

  String label() {
    final values = <Object?>[invtId, prodId, sucuId, invtCantidad];
    return values.where((e) => e != null && e.toString().isNotEmpty).join(' · ');
  }
}
