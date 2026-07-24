/// Modelo genérico de respuesta para reportes no tabulares.
class ReportesResponseModel {
  const ReportesResponseModel({this.values = const {}});

  final Map<String, dynamic> values;

  factory ReportesResponseModel.fromJson(Map<String, dynamic> json) => ReportesResponseModel(values: json);

  Map<String, dynamic> toJson() => values;

  Object? get id => values['id'];

  String label() => values.entries.take(3).map((e) => '${e.key}: ${e.value}').join(' · ');
}
