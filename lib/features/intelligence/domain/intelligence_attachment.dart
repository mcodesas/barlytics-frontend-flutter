import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class AttachmentReadException implements Exception {
  const AttachmentReadException(this.message);
  final String message;
  factory AttachmentReadException.tooLarge(int limit)=>AttachmentReadException(
    'Archivo superior al límite de '+(limit~/1024~/1024).toString()+' MiB.');
}

/// Web selections provide bytes, not native filesystem paths.
/// Check the advertised size and actual size independently.
Future<Uint8List> readIntelligenceAttachment(PlatformFile file,{required bool web,required int limit}) async {
  if(file.size>limit)throw AttachmentReadException.tooLarge(limit);
  final Uint8List bytes;
  if(file.bytes!=null){
    bytes=file.bytes!;
  }else if(web){
    throw const AttachmentReadException('El navegador no entregó el contenido del archivo. Vuelve a seleccionarlo.');
  }else{
    final path=file.path;
    if(path==null||path.isEmpty)throw const AttachmentReadException('No se recibió una ubicación válida del archivo.');
    final selected=XFile(path);
    if(await selected.length()>limit)throw AttachmentReadException.tooLarge(limit);
    bytes=await selected.readAsBytes();
  }
  if(bytes.isEmpty)throw const AttachmentReadException('El archivo está vacío.');
  if(bytes.length>limit)throw AttachmentReadException.tooLarge(limit);
  return bytes;
}

({String kind,String name}) validateIntelligenceAttachment(String kind,String name,Uint8List bytes,int limit){
  if(bytes.isEmpty)throw const AttachmentReadException('El archivo está vacío.');
  if(bytes.length>limit)throw AttachmentReadException.tooLarge(limit);
  final clean=name.split(RegExp(r'[/\\]')).last;
  if(clean.isEmpty||clean.length>150||RegExp(r'[\x00-\x1f\x7f]').hasMatch(clean)){
    throw const AttachmentReadException('Nombre de archivo inválido o demasiado largo.');
  }
  final ext=clean.contains('.')?clean.split('.').last.toLowerCase():'';
  final allowed=switch(kind){
    'photo'=>const {'png','jpg','jpeg'},
    'file'=>const {'pdf','xlsx','csv','txt','png','jpg','jpeg'},
    'video'=>const {'mp4','mov','webm'},
    'audio'=>const {'wav'},
    _=>const <String>{},
  };
  if(!allowed.contains(ext))throw const AttachmentReadException('Formato no admitido. Para imágenes utiliza PNG o JPEG.');
  final image=const {'png','jpg','jpeg'}.contains(ext);
  if(image){
    final png=bytes.length>=8&&const [137,80,78,71,13,10,26,10].asMap().entries.every((e)=>bytes[e.key]==e.value);
    final jpeg=bytes.length>=3&&bytes[0]==255&&bytes[1]==216&&bytes[2]==255;
    if(ext=='png'?!png:!jpeg)throw const AttachmentReadException('El contenido no coincide con una imagen PNG o JPEG válida.');
  }
  return (kind:image?'photo':kind,name:clean);
}
