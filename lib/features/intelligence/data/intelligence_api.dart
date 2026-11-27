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
  Future<Map<String,dynamic>> media(int branch,String kind,String filename,Uint8List bytes)=>
    _post('media',{'branchId':branch,'kind':kind,'filename':filename,'contentBase64':base64Encode(bytes)});
}
