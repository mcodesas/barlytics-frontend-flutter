import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/domain/assistant_navigation.dart';
import 'package:barlytics_frontend/features/navigation/data/models/user_menu_item.dart';
void main(){
  const menus=[UserMenuItem(keyName:'inventario',title:'Inventario',path:'/inventario'),
    UserMenuItem(keyName:'ganancias',title:'Ganancias',path:'/ganancias')];
  test('interpreta apertura de un menú autorizado',(){
    final target=AssistantNavigation.requestedDestination('Ábreme el módulo de inventario');
    expect(target,'inventario');
    expect(AssistantNavigation.resolve(target!,menus)?.path,'/inventario');
    expect(AssistantNavigation.resolve('usuarios',menus),isNull);
    expect(AssistantNavigation.requestedDestination('¿Cómo funciona inventario?'),isNull);
  });
  test('contexto no envía parámetros ni destinos no autorizados',(){
    expect(AssistantNavigation.module('/inventario/123?token=secret',menus),'inventario');
    expect(AssistantNavigation.module('/usuarios/99',menus),'');
  });
  test('no permite navegación externa',(){
    expect(AssistantNavigation.resolve('inventario',[const UserMenuItem(keyName:'inventario',title:'Inventario',path:'//example.com')]),isNull);
  });
}
