import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/evento_publico_page.dart';

void main(){
  test('Acepta enlace HTTPS de pago de Mercado Pago',(){
    final link=eventCheckoutUri(
      'https://www.mercadopago.com.co/checkout/v1/redirect?pref_id=123');
    expect(link,isNotNull);
    expect(link?.scheme,'https');
    expect(link?.queryParameters['pref_id'],'123');
  });
  test('No ejecuta pagos en enlaces no válidos',(){
    expect(eventCheckoutUri(''),isNull);
    expect(eventCheckoutUri('javascript:alert(1)'),isNull);
    expect(eventCheckoutUri('http://example.com/pay'),isNull);
    expect(eventCheckoutUri('no es una url'),isNull);
  });
}
