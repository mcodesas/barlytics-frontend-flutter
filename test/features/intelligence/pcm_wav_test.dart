import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/domain/pcm_wav.dart';
void main(){
  test('Whisper-compatible header',(){
    final pcm=Uint8List(32000);
    final wav=pcmWav(pcm), header=ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.take(4)),'RIFF');
    expect(header.getUint16(22,Endian.little),1);
    expect(header.getUint32(24,Endian.little),16000);
    expect(header.getUint16(34,Endian.little),16);
    expect(header.getUint32(40,Endian.little),pcm.length);
    expect(wav.length,32044);
  });
  test('Reject invalid or too long recordings',(){
    for(final length in [0,7999,8001,960002]){
      expect(()=>pcmWav(Uint8List(length)),throwsFormatException);
    }
  });
}
