import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'progressive_chat.dart';
import '../../../core/providers/core_providers.dart';
import '../../navigation/presentation/providers/active_role_provider.dart';
import '../../navigation/presentation/providers/user_assigned_roles_provider.dart';

final intelligenceApiProvider=Provider<IntelligenceApi>((ref){
  final api=ref.watch(apiClientProvider);
  // Rebuild workspace resources when the active role changes; each request
  // also reads the current selection, including polling and confirmation.
  ref.watch(selectedRolesProvider);
  ref.watch(userAssignedRolesProvider);
  return IntelligenceApi(api,roleHeaders:(){
    final selection=ref.read(selectedRolesProvider);
    if(selection==null)return const <String,dynamic>{};
    final roles=ref.read(userAssignedRolesProvider).valueOrNull??const <UserAssignedRole>[];
    final ids=<int>{};
    for(final key in selection){
      final id=systemRoleIdFromSelection(key)??customRoleIdFromSelection(key);
      if(id!=null){ids.add(id);continue;}
      for(final r in roles){
        if(normalizeRoleName(r.name)==normalizeRoleName(key))ids.add(r.roleId);
      }
    }
    final ordered=ids.toList()..sort();
    return {'X-Intelligence-Role-Ids':ordered.isEmpty?'none':ordered.join(',')};
  });
});

class IntelligenceApi {
  IntelligenceApi(this._api,{this.roleHeaders});
  final ApiClient _api;
  final Map<String,dynamic> Function()? roleHeaders;
  static const _path='/api/v1/intelligence/embedded';
  Future<Map<String,dynamic>> _post(String path,Map<String,dynamic> body,{Duration timeout=const Duration(seconds:210)}) async {
    final result=await _api.post<Map<String,dynamic>>('$_path/$path',body,
      (data)=>Map<String,dynamic>.from(data as Map),receiveTimeout:timeout,headers:roleHeaders?.call());
    if(result.data==null)throw StateError('El asistente no devolvió información.');
    return result.data!;
  }
  Future<Map<String,dynamic>> memory(int branch)=>_post('memory',{'branchId':branch},timeout:const Duration(seconds:15));
  Future<Map<String,dynamic>> configureMemory(int branch,{required bool recallHistory,required bool recallNotes,bool resetHistory=false})=>
    _post('memory-config',{'branchId':branch,'recallHistory':recallHistory,'recallNotes':recallNotes,'resetHistory':resetHistory},timeout:const Duration(seconds:15));
  Future<Map<String,dynamic>> saveMemory(int branch,String title,String content,{String? noteId})=>
    _post('memory-save',{'branchId':branch,'title':title,'content':content,if(noteId!=null)'noteId':noteId},timeout:const Duration(seconds:15));
  Future<Map<String,dynamic>> deleteMemory(int branch,String noteId)=>_post('memory-delete',{'branchId':branch,'noteId':noteId},timeout:const Duration(seconds:15));
  Future<Map<String,dynamic>> forecastOptions(int branch)=>_post('forecast-options',{'branchId':branch},timeout:const Duration(seconds:15));
  Future<Map<String,dynamic>> forecast(int branch,Map<String,dynamic> plan)=>_post('forecast',{'branchId':branch,'forecast':plan},timeout:const Duration(seconds:40));
  Future<Map<String,dynamic>> alertSettings(int branch)=>_post('alert-settings',{'branchId':branch},timeout:const Duration(seconds:15));
  Future<Map<String,dynamic>> saveAlertSettings(int branch,Map<String,dynamic> settings)=>_post('alert-settings-save',{'branchId':branch,'settings':settings},timeout:const Duration(seconds:15));
  Future<Map<String,dynamic>> alerts(int branch,{bool includeFinance=false})=>_post('alerts',{'branchId':branch,'includeFinance':includeFinance},timeout:const Duration(seconds:40));
  Future<Map<String,dynamic>> exportData(int branch,Map<String,dynamic> plan)=>
    _post('export',{'branchId':branch,'export':plan},timeout:const Duration(seconds:45));
  Future<Map<String,dynamic>> workspaceCatalog(int branch)=>
    _post('workspace-catalog',{'branchId':branch},timeout:const Duration(seconds:15));
  Future<Map<String,dynamic>> workspaceQuery(int branch,Map<String,dynamic> plan)=>
    _post('workspace-query',{'branchId':branch,'plan':plan},timeout:const Duration(seconds:15));
  Future<Map<String,dynamic>> history(int branch,{String? conversation,int offset=0})=>
    _post('history',{'branchId':branch,'conversationId':conversation,'offset':offset});
  Future<Map<String,dynamic>> chat(int branch,String? conversation,String text)=>
    _post('chat',{'branchId':branch,'conversationId':conversation,'message':text});
  Future<Map<String,dynamic>> chatProgressive(int branch,String? conversation,String text,{
    required void Function(String) onPartial,required bool Function() isActive,required bool Function() shouldCancel,String? currentModule,List<Map<String,String>>? menuCatalog,
  })=>ProgressiveChat((path,body)=>_post(path,body,timeout:const Duration(seconds:15))).send(
    branch:branch,conversation:conversation,text:text,onPartial:onPartial,isActive:isActive,shouldCancel:shouldCancel,currentModule:currentModule,menuCatalog:menuCatalog);
  Future<Map<String,dynamic>> prepareAction(int branch,Map<String,dynamic> plan,{Uint8List? image})=>
    _post('action-prepare',{'branchId':branch,'plan':plan,if(image!=null)'imageBase64':base64Encode(image)},timeout:const Duration(seconds:30));
  Future<Map<String,dynamic>> confirmAction(int branch,String draft)=>
    _post('action-confirm',{'branchId':branch,'draftId':draft},timeout:const Duration(seconds:45));
  Future<Map<String,dynamic>> cancelAction(int branch,String draft)=>
    _post('action-cancel',{'branchId':branch,'draftId':draft},timeout:const Duration(seconds:15));
  Future<Uint8List> speech(int branch,String text) async {
    final r=await _post('speech',{'branchId':branch,'text':text});
    if(r['format']!='wav'||r['audioBase64'] is! String)throw const FormatException('Audio no válido.');
    final raw=r['audioBase64'] as String;
    if(raw.length>8*1024*1024)throw const FormatException('Audio demasiado grande.');
    return base64Decode(raw);
  }
  Future<Map<String,dynamic>> media(int branch,String kind,String filename,Uint8List bytes)=>
    _post('media',{'branchId':branch,'kind':kind,'filename':filename,'contentBase64':base64Encode(bytes)});
}
