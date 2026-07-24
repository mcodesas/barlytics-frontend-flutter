import 'package:barlytics_frontend/features/ciudades/data/models/ciudades_response_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CiudadesResponseModel serializa y deserializa JSON', () {
    // Arrange
    final json = <String, dynamic>{
      'ciudId': 1,
      'regiId': 1,
      'zohoId': 1,
      'ciudNombre': 'demo',
      'ciudCodigoDane': 'demo',

    };

    // Act
    final model = CiudadesResponseModel.fromJson(json);
    final result = model.toJson();

    // Assert
    expect(result, isA<Map<String, dynamic>>());
  });
}
