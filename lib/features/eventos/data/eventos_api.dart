import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/branch/branch_scope_provider.dart';
import '../../../core/config/app_config.dart';

final eventosApiProvider=Provider<EventosApi>((ref)=>EventosApi(ref.watch(dioProvider),()=>ref.read(branchScopeProvider).activeBranchId));
class EventosApi{
 final Dio dio;
 EventosApi(this.dio,this.currentBranchId);
 final int? Function() currentBranchId;
 int requireBranch(){
  final id=currentBranchId();
  if(id==null)throw StateError('Selecciona primero una sucursal');
  return id;
 }
 String scoped(String path){
  final branch=requireBranch();
  return path+(path.contains('?')?'&':'?')+'sucursalId=$branch';
 }
 void ensureBranch(dynamic payload){
  final id=payload is Map?int.tryParse(payload['sucursalId']?.toString()??''):null;
  if(id!=requireBranch())throw StateError('El evento no pertenece a la sucursal seleccionada');
 }
 String get base=>AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'),'');
 Future<dynamic> get(String path)async=>(await dio.get<dynamic>(path)).data;
 Future<dynamic> post(String path,[dynamic payload])async=>(await dio.post<dynamic>(path,data:payload)).data;
 Future<dynamic> put(String path,dynamic payload)async=>(await dio.put<dynamic>(path,data:payload)).data;
 Map<String,dynamic> map(dynamic v)=>Map<String,dynamic>.from(v as Map);
 List<Map<String,dynamic>> list(dynamic v)=>(v as List).map((e)=>map(e)).toList();
 Future<List<Map<String,dynamic>>> eventos()async=>currentBranchId()==null?[]:list(await get(scoped('/api/v1/eventos')));
 Future<Map<String,dynamic>> detalle(int id)async=>map(await get(scoped('/api/v1/eventos/$id')));
 Future<Map<String,dynamic>> crear(dynamic payload)async{
  ensureBranch(payload);
  return map(await post(scoped('/api/v1/eventos'),payload));
 }
 Future<Map<String,dynamic>> cambiar(int id,dynamic payload)async{
  ensureBranch(payload);
  return map(await put(scoped('/api/v1/eventos/$id'),payload));
 }
 Future<void> publicar(int id)async{await post(scoped('/api/v1/eventos/$id/publicar'));}
 Future<void> cancelar(int id)async{await post(scoped('/api/v1/eventos/$id/cancelar'));}
 Future<void> aprobar(int id)async{await post(scoped('/api/v1/eventos/reservas/$id/aprobar'));}
 Future<void> cancelarReserva(int id)async{await post(scoped('/api/v1/eventos/reservas/$id/cancelar'));}
 Future<Map<String,dynamic>> retirarReserva(int reservationId,Map<String,dynamic> body)async=>
   map(await post(scoped('/api/v1/eventos/reservas/$reservationId/retirar'),body));
 Future<Map<String,dynamic>> pagoConfig()async=>map(await get('/api/v1/eventos/pasarela'));
 Future<Map<String,dynamic>> configurar(String token,String secret)async=>map(await post('/api/v1/eventos/pasarela',{'accessToken':token,'webhookSecret':secret}));
 Future<List<Map<String,dynamic>>> mesasEvento(int eventId)async=>
   list(await get(scoped('/api/v1/eventos/$eventId/mesas')));
 Future<Map<String,dynamic>> reservarInterna(int eventId,Map<String,dynamic> values)async=>
   map(await post(scoped('/api/v1/eventos/$eventId/reservas-internas'),values));
 Future<Map<String,dynamic>> editarReservaInterna(int reservationId,Map<String,dynamic> values)async=>
   map(await put(scoped('/api/v1/eventos/reservas/$reservationId/editar-interna'),values));
 Future<Map<String,dynamic>> reenviarEntradas(int reservationId)async=>
   map(await post(scoped('/api/v1/eventos/reservas/$reservationId/reenviar-entradas')));
 Future<Map<String,dynamic>> ingresosEvento(int eventId)async=>
   map(await get(scoped('/api/v1/eventos/$eventId/accesos')));
 Future<Map<String,dynamic>> consultarEntradaQr(int eventId,String token)async=>
   map(await get(scoped('/api/v1/eventos/$eventId/accesos/consultar')+
     '&token=${Uri.encodeQueryComponent(token)}'));
 Future<Map<String,dynamic>> validarEntradaQr(int eventId,String token)async=>
   map(await post(scoped('/api/v1/eventos/$eventId/accesos/validar'),{'token':token}));
 Future<Map<String,dynamic>> registrarIngresoManual(int eventId,int entryId)async=>
   map(await post(scoped('/api/v1/eventos/$eventId/accesos/$entryId/manual')));
 Future<List<Map<String,dynamic>>> productos(int branch)async{
  if(branch!=requireBranch())throw StateError('Catálogo de otra sucursal no autorizado');
  return list(await get('/api/v1/eventos/catalogo?sucursalId=$branch'));
 }
 Future<List<Map<String,dynamic>>> mesas(int branch)async{
  if(branch!=requireBranch())throw StateError('Mesas de otra sucursal no autorizadas');
  final raw=map(await get('/api/v1/mesas/sucursal/$branch'));
  return list(raw['data']??[]);
 }
 Future<Map<String,dynamic>> eventoPublico(String slug)async=>map(await get('/api/v1/eventos/public/$slug'));
 Future<Map<String,dynamic>> reservar(String slug,dynamic values)async=>map(await post('/api/v1/eventos/public/$slug/reservar',values));
 Future<Map<String,dynamic>> entrada(String token)async=>map(await get('/api/v1/eventos/public/entradas/$token'));
 String link(String slug)=> 'https://www.barlytics.com.co/api/v1/eventos/public/$slug/compartir';
 String entradaLink(String token)=>'https://www.barlytics.com.co/#/evento/entrada/$token';
 String qrLink(String token)=>'$base/api/v1/eventos/public/entradas/$token/qr';
}
