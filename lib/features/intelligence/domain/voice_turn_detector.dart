import 'dart:collection';
import 'dart:typed_data';

/// Local PCM16 energy detector. Keeps a short pre-roll and returns one bounded
/// speech turn. This is not a neural VAD; noisy venues may trigger it.
class VoiceTurnDetector {
  VoiceTurnDetector({this.threshold=650,this.silenceFrames=45});
  final int threshold,silenceFrames;
  static const frameBytes=640; // 20 ms at 16 kHz mono PCM16
  final _preRoll=Queue<Uint8List>();
  final _turn=BytesBuilder(copy:false);
  Uint8List _pending=Uint8List(0);
  int _voiced=0,_silence=0,_start=0;
  bool _speaking=false,_finished=false;

  Uint8List? add(Uint8List bytes){
    if(_finished)return null;
    final input=Uint8List(_pending.length+bytes.length)
      ..setRange(0,_pending.length,_pending)
      ..setRange(_pending.length,_pending.length+bytes.length,bytes);
    var offset=0;
    while(offset+frameBytes<=input.length){
      final frame=Uint8List.fromList(input.sublist(offset,offset+frameBytes));offset+=frameBytes;
      final view=ByteData.sublistView(frame);
      var energy=0;
      for(var i=0;i<frameBytes;i+=2){energy+=view.getInt16(i,Endian.little).abs();}
      final loud=energy~/320>=threshold;
      if(!_speaking){
        _preRoll.add(frame);if(_preRoll.length>15)_preRoll.removeFirst();
        _start=loud?_start+1:0;
        if(_start>=3){
          _speaking=true;_voiced=3;_silence=0;
          for(final f in _preRoll){_turn.add(f);}
          _preRoll.clear();
        }
      }else{
        _turn.add(frame);
        if(loud){_voiced++;_silence=0;}else{_silence++;}
        if(_silence>=silenceFrames||_turn.length>=800000){
          if(_voiced>=10){_finished=true;return _turn.takeBytes();}
          // Short noise impulse: discard and continue listening.
          _turn.clear();_speaking=false;_start=0;_voiced=0;_silence=0;
        }
      }
    }
    _pending=Uint8List.fromList(input.sublist(offset));
    return null;
  }
}
