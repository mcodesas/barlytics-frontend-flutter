import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/domain/assistant_screen_context.dart';

void main(){
  test('typed screen hints retain only allowed filters and references',(){
    expect(AssistantScreenContextRegistry.catalog('productos',productId:92,typeId:2,brandId:4),'productos/producto/92/tipo/2/marca/4');
    expect(AssistantScreenContextRegistry.catalog('precios',typeId:2,status:'withPrice'),'precios/tipo/2/estado/withPrice');
    expect(AssistantScreenContextRegistry.catalog('precios',status:'password'),isNull);
    expect(AssistantScreenContextRegistry.count('inventario','registrados'),'inventario/estado/registrados');
    expect(AssistantScreenContextRegistry.count('inventario','unknown'),isNull);
    expect(AssistantScreenContextRegistry.sale('mesero',21,54,tableId:3),'mesero/venta/21/cuenta/54/mesa/3');
    expect(AssistantScreenContextRegistry.period('reportes','ganancias',DateTime(2026,11,1),DateTime(2026,11,27)),'reportes/reporte/ganancias/desde/2026-11-01/hasta/2026-11-27');
  });
  test('detail route wins over stale list context',(){
    final registry=AssistantScreenContextRegistry();
    registry.register(Object(),(_,__)=>'productos/producto/4');
    expect(registry.resolve('productos/92/editar',10),'productos/92/editar');
  });
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
