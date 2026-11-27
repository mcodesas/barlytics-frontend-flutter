import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/intelligence/domain/intelligence_attachment.dart';

void main(){
  final png=Uint8List.fromList([137,80,78,71,13,10,26,10,0]);
  test('browser uses bytes without a native path',() async{
    final file=PlatformFile(name:'foto.png',size:png.length,bytes:png);
    expect(await readIntelligenceAttachment(file,web:true,limit:100),orderedEquals(png));
  });
  test('missing browser data and oversized actual data are rejected',() async{
    await expectLater(readIntelligenceAttachment(PlatformFile(name:'foto.png',size:9),web:true,limit:100),throwsA(isA<AttachmentReadException>()));
    await expectLater(readIntelligenceAttachment(PlatformFile(name:'foto.png',size:1,bytes:png),web:true,limit:2),throwsA(isA<AttachmentReadException>()));
  });
  test('image chosen as document becomes a photo; format is checked',(){
    expect(validateIntelligenceAttachment('file','FOTO.PNG',png,100).kind,'photo');
    expect(validateIntelligenceAttachment('photo','foto.png',png,100).name,'foto.png');
    expect(()=>validateIntelligenceAttachment('photo','foto.jpg',png,100),throwsA(isA<AttachmentReadException>()));
    expect(()=>validateIntelligenceAttachment('photo','foto.heic',png,100),throwsA(isA<AttachmentReadException>()));
  });
}
