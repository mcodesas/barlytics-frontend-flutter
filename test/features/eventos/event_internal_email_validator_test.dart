import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_internal_email_validator.dart';

void main() {
  test('Correo obligatorio para reservas por llamada o en el bar', () {
    expect(validateInternalBookingEmail(''), isNotNull);
    expect(validateInternalBookingEmail(null), isNotNull);
    expect(validateInternalBookingEmail('sin-arroba'), isNotNull);
    expect(validateInternalBookingEmail('nombre@'), isNotNull);
    expect(validateInternalBookingEmail('nombre@dominio'), isNotNull);
    expect(validateInternalBookingEmail('nombre@@dominio.com'), isNotNull);
    expect(validateInternalBookingEmail('nombre con espacio@dominio.com'), isNotNull);
    expect(validateInternalBookingEmail(List.filled(212, 'x').join() + '@dominio.com'), isNotNull);
    expect(validateInternalBookingEmail('cliente@example.com'), isNull);
    expect(validateInternalBookingEmail(' cliente@example.com '), isNull);
  });
}
