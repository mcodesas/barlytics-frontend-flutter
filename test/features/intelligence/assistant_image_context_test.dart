import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/domain/assistant_image_context.dart';
void main(){
  test('a follow-up includes the image content, not only the confirmation',(){
    final message=assistantImageMessage('sí','Corona 12000\nAguila 8000')!;
    expect(message,contains('Corona 12000'));
    expect(message,contains('Aguila 8000'));
    expect(message,startsWith('sí'));
  });
  test('does not silently truncate a long attachment or claim empty OCR',(){
    expect(assistantImageMessage('compara',''),isNull);
    expect(assistantImageMessage('compara',List.filled(2000,'x').join()),isNull);
  });
  test('image mutations retain original bytes but price comparison is analysis',(){
    expect(isImageAssignment('Asigna esta imagen al producto Corona'),isTrue);
    expect(isImageAssignment('Compara los precios de los productos de la imagen'),isFalse);
    expect(isImageAssignment('sí'),isFalse);
  });
}
