import '../../../core/errors/app_exception.dart';

typedef ChatRequest=Future<Map<String,dynamic>> Function(String path,Map<String,dynamic> body);

class ProgressiveChat {
  ProgressiveChat(this.request,{this.interval=const Duration(milliseconds:750),this.maxWait=const Duration(seconds:200)});
  final ChatRequest request;
  final Duration interval,maxWait;

  Future<Map<String,dynamic>> send({required int branch,required String? conversation,required String text,
    required void Function(String) onPartial,required bool Function() isActive,required bool Function() shouldCancel,String? currentModule,List<Map<String,String>>? menuCatalog}) async {
    if(!isActive())throw const ApiException('Conversación cerrada',code:'CHAT_CLOSED');
    final clock=Stopwatch()..start();
    var snapshot=await request('chat-start',{'branchId':branch,'conversationId':conversation,'message':text,if(currentModule!=null)'currentModule':currentModule,if(menuCatalog!=null&&menuCatalog.isNotEmpty)'menuCatalog':menuCatalog});
    final id=snapshot['jobId'];
    if(id is! String||id.isEmpty)throw const FormatException('Trabajo inválido');
    final scope={'branchId':branch,'jobId':id};
    bool cancelSent=false;
    String previous='';
    while(true){
      // Do not issue another authenticated request after logout/branch change.
      if(!isActive())throw const ApiException('Conversación cerrada',code:'CHAT_CLOSED');
      if(snapshot['jobId']!=id)throw const FormatException('Trabajo incorrecto');
      final status=snapshot['status'],partial=snapshot['text'];
      if(partial is! String||partial.length>65536)throw const FormatException('Respuesta inválida');
      if(partial!=previous){previous=partial;onPartial(partial);}
      if(status=='done'){
        final conversationId=snapshot['conversationId'];
        if(conversationId is! String||conversationId.isEmpty||partial.trim().isEmpty)throw const FormatException('Respuesta no confirmada');
        return {'conversationId':conversationId,'answer':partial,if(snapshot['navigation'] is String)'navigation':snapshot['navigation'],if(snapshot['action'] is Map)'action':snapshot['action'],if(snapshot['export'] is Map)'export':snapshot['export'],if(snapshot['alerts']==true)'alerts':true};
      }
      if(status=='cancelled')throw const ApiException('Generación cancelada',code:'CHAT_CANCELLED');
      if(status=='failed'){
        final code=snapshot['errorStatus'];
        throw ApiException('El asistente no completó la respuesta',statusCode:code is int?code:503);
      }
      if(status!='running')throw const FormatException('Estado inválido');
      if(clock.elapsed>=maxWait){
        if(!cancelSent&&isActive()){
          try{await request('chat-cancel',scope);}catch(_){}
        }
        throw const ApiException('Tiempo de espera agotado',statusCode:504);
      }
      if(shouldCancel()&&!cancelSent){
        cancelSent=true;
        snapshot=await request('chat-cancel',scope);
      }else{
        await Future<void>.delayed(interval);
        if(!isActive())throw const ApiException('Conversación cerrada',code:'CHAT_CLOSED');
        snapshot=await request('chat-status',scope);
      }
    }
  }
}
