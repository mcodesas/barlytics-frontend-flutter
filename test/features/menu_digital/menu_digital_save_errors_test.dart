import 'package:barlytics_frontend/features/menu_digital/domain/menu_digital_save_errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException failed(int? status, {Object? payload}) => DioException(
  requestOptions: RequestOptions(path: '/api/v1/menu-digital'),
  response: status == null
      ? null
      : Response(
          requestOptions: RequestOptions(path: '/api/v1/menu-digital'),
          statusCode: status,
          data: payload,
        ),
);

void main() {
  test('Un 409 al guardar BISTRO explica migración V75 sin exponer Dio', () {
    final msg = menuDigitalSaveErrorMessage(failed(
      409, payload: {'message': 'La operación viola la integridad de los datos'},
    ), style: 'BISTRO');
    expect(msg, contains('V75'));
    expect(msg, contains('BISTRO'));
    expect(msg, isNot(contains('DioException')));
  });

  test('Un conflicto en diseño original no se atribuye erróneamente a V75', () {
    final msg = menuDigitalSaveErrorMessage(
      failed(409, payload: {'message': 'Registro duplicado'}),
      style: 'LIBRO',
    );
    expect(msg, contains('Registro duplicado'));
    expect(msg, isNot(contains('V75')));
  });

  test('La ausencia de respuesta indica conectividad', () {
    expect(menuDigitalSaveErrorMessage(failed(null), style: 'DOCUMENTO'),
        contains('No hubo respuesta'));
  });

  test('Un 413 indica reducir imágenes', () {
    expect(menuDigitalSaveErrorMessage(failed(413), style: 'BISTRO'),
        contains('imágenes'));
  });
}
