import 'dart:typed_data';

/// Mono, 16 kHz, signed PCM16 little endian, accepted by Intelligence Whisper.
Uint8List pcmWav(Uint8List pcm){
  if(pcm.length.isOdd||pcm.length<8000||pcm.length>960000)throw const FormatException('Audio de 0,25 a 30 segundos requerido.');
  final bytes=Uint8List(44+pcm.length);
  final header=ByteData.sublistView(bytes);
  void tag(int offset,String text)=>bytes.setRange(offset,offset+text.length,text.codeUnits);
  tag(0,'RIFF');header.setUint32(4,36+pcm.length,Endian.little);tag(8,'WAVE');
  tag(12,'fmt ');header.setUint32(16,16,Endian.little);header.setUint16(20,1,Endian.little);
  header.setUint16(22,1,Endian.little);header.setUint32(24,16000,Endian.little);
  header.setUint32(28,32000,Endian.little);header.setUint16(32,2,Endian.little);
  header.setUint16(34,16,Endian.little);tag(36,'data');header.setUint32(40,pcm.length,Endian.little);
  bytes.setRange(44,bytes.length,pcm);return bytes;
}
