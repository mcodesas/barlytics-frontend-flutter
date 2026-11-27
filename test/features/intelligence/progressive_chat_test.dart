import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/data/progressive_chat.dart';
import 'package:barlytics_frontend/core/errors/app_exception.dart';

void main(){
  Map<String,dynamic> snapshot(String status,String text,{String? conversation,int? error})=>
    {'jobId':'job','status':status,'text':text,'conversationId':conversation,'errorStatus':error};
  test('shows real partial snapshots and returns only confirmed response',() async {
    final responses=[snapshot('running',''),snapshot('running','Hola '),snapshot('done','Hola mundo',conversation:'id')];
    final paths=<String>[],partials=<String>[];
    final client=ProgressiveChat((path,body) async{
      paths.add(path);expect(body['branchId'],10);
      return responses.removeAt(0);
    },interval:Duration.zero);
    final result=await client.send(branch:10,conversation:null,text:'Hola',onPartial:partials.add,isActive:()=>true,shouldCancel:()=>false);
    expect(paths,['chat-start','chat-status','chat-status']);
    expect(partials,['Hola ','Hola mundo']);
    expect(result,{'conversationId':'id','answer':'Hola mundo'});
  });
  test('returns structured export proposal without inventing report data',() async {
    final export={'format':'xlsx','query':{'resource':'productos','operation':'list'}};
    final client=ProgressiveChat((path,body) async=>{...snapshot('done','Informe preparado',conversation:'id'),'export':export},interval:Duration.zero);
    final result=await client.send(branch:10,conversation:null,text:'Exporta productos a Excel',onPartial:(_){},isActive:()=>true,shouldCancel:()=>false);
    expect(result['export'],export);
    expect(result.containsKey('action'),isFalse);
  });
  test('cancellation is explicit and never returns partial as success',() async {
    final calls=<String>[];
    final client=ProgressiveChat((path,body) async{
      calls.add(path);
      return path=='chat-start'?snapshot('running','Parcial'):snapshot('cancelled','Parcial');
    },interval:Duration.zero);
    await expectLater(client.send(branch:10,conversation:null,text:'Hola',onPartial:(_){},isActive:()=>true,shouldCancel:()=>true),
      throwsA(isA<ApiException>().having((e)=>e.code,'code','CHAT_CANCELLED')));
    expect(calls,['chat-start','chat-cancel']);
  });
  test('scope invalidation prevents further requests',() async {
    var active=true;var calls=0;
    final client=ProgressiveChat((path,body) async{
      calls++;active=false;
      return snapshot('running','Parcial');
    },interval:Duration.zero);
    await expectLater(client.send(branch:10,conversation:null,text:'Hola',onPartial:(_){},isActive:()=>active,shouldCancel:()=>false),throwsA(isA<ApiException>()));
    expect(calls,1);
  });
}
