import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:barlytics_frontend/features/intelligence/domain/voice_turn_detector.dart';
void main(){
  Uint8List frames(int count,int amplitude){
    final b=Uint8List(count*640),d=ByteData.sublistView(b);
    for(var i=0;i<b.length;i+=2)d.setInt16(i,amplitude,Endian.little);
    return b;
  }
  test('ignores silence and emits one voice turn after a pause',(){
    final d=VoiceTurnDetector();
    expect(d.add(frames(100,0)),isNull);
    expect(d.add(frames(20,1400)),isNull);
    final turn=d.add(frames(50,0));expect(turn,isNotNull);expect(turn!.length,greaterThan(8000));
    expect(d.add(frames(30,1500)),isNull);
  });
  test('short impulse does not become a turn',(){
    final d=VoiceTurnDetector();
    expect(d.add(frames(4,2000)),isNull);expect(d.add(frames(60,0)),isNull);
  });
  test('bounded utterance',(){
    final d=VoiceTurnDetector();
    final turn=d.add(frames(1400,1400));
    expect(turn,isNotNull);expect(turn!.length,lessThanOrEqualTo(800000));
  });
}
