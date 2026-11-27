import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';

final intelligenceApiProvider=Provider<IntelligenceApi>((ref)=>IntelligenceApi(ref.watch(apiClientProvider)));

class IntelligenceApi {
  IntelligenceApi(this._api);
  final ApiClient _api;
  static const _path='/api/v1/intelligence/embedded';
  Future<Map<String,dynamic>> _post(String path,Map<String,dynamic> body) async {
    final result=await _api.post<Map<String,dynamic>>('$_path/$path',body,
      (data)=>Map<String,dynamic>.from(data as Map),receiveTimeout:const Duration(seconds:210));
    if(result.data==null)throw StateError('El asistente no devolvió información.');
    return result.data!;
  }
  Future<Map<String,dynamic>> chat(int branch,String? conversation,String text)=>
    _post('chat',{'branchId':branch,'conversationId':conversation,'message':text});
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
