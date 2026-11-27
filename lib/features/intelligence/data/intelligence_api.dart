import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'progressive_chat.dart';
import '../../../core/providers/core_providers.dart';

final intelligenceApiProvider=Provider<IntelligenceApi>((ref)=>IntelligenceApi(ref.watch(apiClientProvider)));

class IntelligenceApi {
  IntelligenceApi(this._api);
  final ApiClient _api;
  static const _path='/api/v1/intelligence/embedded';
  Future<Map<String,dynamic>> _post(String path,Map<String,dynamic> body,{Duration timeout=const Duration(seconds:210)}) async {
    final result=await _api.post<Map<String,dynamic>>('$_path/$path',body,
      (data)=>Map<String,dynamic>.from(data as Map),receiveTimeout:timeout);
    if(result.data==null)throw StateError('El asistente no devolvió información.');
    return result.data!;
  }
  Future<Map<String,dynamic>> history(int branch,{String? conversation,int offset=0})=>
    _post('history',{'branchId':branch,'conversationId':conversation,'offset':offset});
  Future<Map<String,dynamic>> chat(int branch,String? conversation,String text)=>
    _post('chat',{'branchId':branch,'conversationId':conversation,'message':text});
  Future<Map<String,dynamic>> chatProgressive(int branch,String? conversation,String text,{
    required void Function(String) onPartial,required bool Function() isActive,required bool Function() shouldCancel,String? currentModule,
  })=>ProgressiveChat((path,body)=>_post(path,body,timeout:const Duration(seconds:15))).send(
    branch:branch,conversation:conversation,text:text,onPartial:onPartial,isActive:isActive,shouldCancel:shouldCancel,currentModule:currentModule);
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
