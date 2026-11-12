import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/core/network/api_client.dart';
import 'package:barlytics_frontend/core/providers/core_providers.dart';
import 'package:barlytics_frontend/features/subscription/presentation/widgets/store_catalog_admin_tab.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1200.0]) {
    testWidgets('Catálogo Apple y Google responsivo a ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dio = Dio(BaseOptions(baseUrl:'https://backend.invalid'));
      dio.interceptors.add(InterceptorsWrapper(onRequest:(options,handler) {
        final path=options.path;
        final value=path.endsWith('/readiness')
            ? <String,dynamic>{
                'catalogEnabled':false,
                'checkoutEnabled':false,
                'appleConfigured':false,
                'googleConfigured':false,
              }
            : <String,dynamic>{};
        final data=path.endsWith('/catalog')
            ? <Map<String,dynamic>>[{
                'planId':10,'code':'PRO','name':'Profesional',
                'monthlyPrice':70000,'currency':'COP','active':1,
                'appleSku':null,'googleSku':null,
              }]
            : value;
        handler.resolve(Response<dynamic>(requestOptions:options,
          statusCode:200,data:{
            'code':'200','success':true,'message':'OK','data':data,
          }));
      }));

      await tester.pumpWidget(ProviderScope(
        overrides:[
          apiClientProvider.overrideWithValue(ApiClient(dio)),
        ],
        child:const MaterialApp(home:Scaffold(
          body:SizedBox(height:620,child:StoreCatalogAdminTab()),
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.text('App Store y Google Play'),findsOneWidget);
      expect(find.text('Profesional'),findsOneWidget);
      expect(find.text('App Store'),findsWidgets);
      expect(find.text('Google Play'),findsWidgets);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      dio.close(force:true);
    });
  }
}
