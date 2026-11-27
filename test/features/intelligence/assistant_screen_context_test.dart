import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/domain/assistant_screen_context.dart';

void main(){
  test('selected account belongs to the currently mounted screen and branch',(){
    final registry=AssistantScreenContextRegistry();
    final owner=Object();
    registry.register(owner,(module,branch)=>branch==10?AssistantScreenContextRegistry.sale(module,21,54):null);
    expect(registry.resolve('mesero',10),'mesero/venta/21/cuenta/54');
    expect(registry.resolve('mesero',11),'mesero');
    expect(registry.resolve('productos',10),'productos');
    registry.unregister(owner);
    expect(registry.resolve('mesero',10),'mesero');
  });
  test('rejects unrecognized modules and invalid identifiers',(){
    expect(AssistantScreenContextRegistry.sale('mesero',0,5),isNull);
    expect(AssistantScreenContextRegistry.sale('productos',2,5),isNull);
    expect(AssistantScreenContextRegistry.sale('mesero',2,null),'mesero/venta/2');
  });
  test('rejects unexpected context and external URLs',(){
    final registry=AssistantScreenContextRegistry();
    registry.register(Object(),(_,__)=>'mesero/https://example.com');
    expect(registry.resolve('mesero',10),'mesero');
  });
}
