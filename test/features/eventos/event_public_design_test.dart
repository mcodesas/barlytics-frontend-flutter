import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/presentation/widgets/event_public_landing.dart';

void main() {
  test('Carta mantiene categorías completas sin mezclar productos de otra hoja', () {
    final catalog=<String,List<int>>{
      'Bruschettas':[1],
      'Limonadas':[2,3,4,5],
      'Comida':[6],
      'Hamburguesas':[7,8,9,10],
      'Jugos':[11],
      'Alitas':[12,13,14],
    };
    final pages=eventMenuPages<int>(catalog);
    expect(pages.length,2);
    expect(pages[0].map((x)=>x.key).toList(),
      ['Bruschettas','Limonadas','Comida']);
    expect(pages[1].map((x)=>x.key).toList(),
      ['Hamburguesas','Jugos','Alitas']);
    expect(pages.map((p)=>p.fold<int>(0,(n,c)=>n+c.value.length)).toList(),
      [6,8]);
    expect(pages.expand((p)=>p).expand((x)=>x.value).toList(),
      List.generate(14,(i)=>i+1));
  });

  test('Categoría grande se reparte sin perder ni duplicar productos',(){
    final pages=eventMenuPages<int>({
      'Bebidas':List.generate(18,(i)=>i+1),
    });
    expect(pages.length,3);
    expect(pages.map((p)=>p.first.value.length).toList(),[8,8,2]);
    expect(pages.expand((p)=>p).expand((e)=>e.value).toSet().length,18);
  });

  test('No genera hojas vacías con categorías sin productos',(){
    final pages=eventMenuPages<int>({
      'Sin productos':[],
      'Postres':[1,2],
    });
    expect(pages.length,1);
    expect(pages.first.length,1);
    expect(pages.first.first.key,'Postres');
  });
}
