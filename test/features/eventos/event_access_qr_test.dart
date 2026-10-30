import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_access_qr.dart';

void main() {
  const token='cc04af31-9b5d-4d58-ae4b-88cf6b3d3120';
  test('Reconoce QR de entrada individual y UUID',(){
    expect(extractEventEntryToken(token),token);
    expect(extractEventEntryToken(
      'https://www.barlytics.com.co/#/evento/entrada/$token'),token);
    expect(extractEventEntryToken(
      'https://barlytics.com.co/#/evento/entrada/$token?utm_source=mail'),token);
  });
  test('Rechaza QR de otro dominio, reserva general y datos falsos',(){
    expect(extractEventEntryToken(''),isNull);
    expect(extractEventEntryToken('https://fraude.example/#/evento/entrada/$token'),isNull);
    expect(extractEventEntryToken('http://www.barlytics.com.co/#/evento/entrada/$token'),isNull);
    expect(extractEventEntryToken('https://www.barlytics.com.co/#/evento/$token'),isNull);
    expect(extractEventEntryToken('https://www.barlytics.com.co/#/evento/entrada/ABC'),isNull);
    expect(extractEventEntryToken('https://www.barlytics.com.co/#/evento/entrada/$token/falso'),isNull);
  });
}
