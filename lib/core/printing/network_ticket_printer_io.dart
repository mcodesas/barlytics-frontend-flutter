import 'dart:io';
import 'dart:typed_data';

Future<void> sendNetworkTicket(String host, int port, Uint8List data) async {
  if (host.trim().isEmpty || port < 1 || port > 65535) {
    throw ArgumentError('Dirección IP o puerto de impresora inválidos.');
  }
  final socket = await Socket.connect(host.trim(), port, timeout: const Duration(seconds: 5));
  try {
    socket.add(data);
    await socket.flush();
  } finally {
    await socket.close();
  }
}
