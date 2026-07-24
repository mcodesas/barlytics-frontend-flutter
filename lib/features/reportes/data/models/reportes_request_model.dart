/// Modelo de request para consultas del módulo Reportes.
///
/// Los endpoints de reportes disponibles en la colección Postman no requieren
/// cuerpo JSON; por eso este modelo se mantiene sin propiedades, pero con una
/// sintaxis válida para Dart.
class ReportesRequestModel {
  const ReportesRequestModel();

  factory ReportesRequestModel.fromJson(Map<String, dynamic> json) {
    return const ReportesRequestModel();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{};
}
