import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ephemeral UI context. A screen registers a reader only for its own lifetime.
final assistantScreenContextProvider=Provider<AssistantScreenContextRegistry>(
  (ref)=>AssistantScreenContextRegistry());

typedef ScreenContextReader=String? Function(String module,int branch);

class AssistantScreenContextRegistry {
  final Map<Object,ScreenContextReader> _readers={};
  void register(Object owner,ScreenContextReader reader)=>_readers[owner]=reader;
  void unregister(Object owner)=>_readers.remove(owner);
  String resolve(String module,int branch){
    if(module.isEmpty)return module;
    for(final reader in _readers.values.toList().reversed){
      final candidate=reader(module,branch);
      if(candidate!=null&&candidate.startsWith('$module/')&&candidate.length<=120&&
          RegExp(r'^[a-zA-Z0-9_/-]+$').hasMatch(candidate))return candidate;
    }
    return module;
  }
  static String? sale(String module,int? saleId,int? accountId){
    if(!const {'mesero','ventas'}.contains(module)||saleId==null||saleId<=0)return null;
    return '$module/venta/$saleId${accountId!=null&&accountId>0?'/cuenta/$accountId':''}';
  }
}
