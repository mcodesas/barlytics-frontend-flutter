import 'package:barlytics_frontend/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required retorna error cuando está vacío', () {
    // Arrange / Act / Assert
    expect(Validators.required(''), isNotNull);
    expect(Validators.required('dato'), isNull);
  });

  test('email valida formato básico', () {
    // Arrange / Act / Assert
    expect(Validators.email('correo-invalido'), isNotNull);
    expect(Validators.email('admin@barlytics.com'), isNull);
  });
}
