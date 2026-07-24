import 'package:barlytics_frontend/features/auth/data/models/login_response_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LoginResponseModel parsea token y roles', () {
    // Arrange
    final json = {'token': 'abc', 'userId': 1, 'empresaId': 2, 'email': 'admin@barlytics.com', 'roles': ['ADMIN']};

    // Act
    final model = LoginResponseModel.fromJson(json);

    // Assert
    expect(model.token, 'abc');
    expect(model.roles, contains('ADMIN'));
  });
}
