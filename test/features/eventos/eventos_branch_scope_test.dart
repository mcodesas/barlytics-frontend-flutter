import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/eventos/data/eventos_api.dart';

void main(){
  test('La lista y el detalle se consultan solo en la sucursal activa',()async{
    int? branch=11;
    final requests=<String>[];
    final dio=Dio(BaseOptions(baseUrl:'https://example.com'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest:(options,handler){
        requests.add(options.path);
        final result=options.path.contains('/api/v1/eventos/99')
          ?<String,dynamic>{'even_id':99,'sucu_id':branch}
          :<Map<String,dynamic>>[];
        handler.resolve(Response(requestOptions:options,data:result,statusCode:200));
      },
    ));
    final api=EventosApi(dio,()=>branch);
    await api.eventos();
    expect(requests.last,contains('sucursalId=11'));
    branch=12;
    await api.eventos();
    expect(requests.last,contains('sucursalId=12'));
    await api.detalle(99);
    expect(requests.last,contains('sucursalId=12'));
  });

  test('No consulta al servidor sin sucursal seleccionada',()async{
    final api=EventosApi(Dio(),()=>null);
    expect(await api.eventos(),isEmpty);
    expect(()=>api.requireBranch(),throwsStateError);
  });

  test('No permite guardar un evento en otra sucursal',(){
    final api=EventosApi(Dio(),()=>12);
    expect(()=>api.ensureBranch({'sucursalId':11}),throwsStateError);
    expect(()=>api.ensureBranch({'sucursalId':12}),returnsNormally);
  });
}
