import 'package:barlytics_frontend/core/network/api_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiResponse parsea respuesta estándar exitosa', () {
    // Arrange
    final json = {
      'code': '200',
      'message': 'OK',
      'success': true,
      'data': {'id': 1},
      'errors': [],
      'timestamp': '2026-05-04T10:15:30',
    };

    // Act
    final response = ApiResponse<Map<String, dynamic>>.fromJson(json, (data) => Map<String, dynamic>.from(data as Map));

    // Assert
    expect(response.success, true);
    expect(response.data?['id'], 1);
  });
}
