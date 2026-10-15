import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_ticket_printer.dart';

/// Permite configurar una impresora LAN por sucursal y enviar un ticket ESC/POS.
Future<bool> printTicketOverLan(BuildContext context, int branchId, String ticket, {bool autoPrintIfConfigured = false}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return false;
  final prefix = 'barlytics.ticket.$branchId';
  final ip = TextEditingController(text: prefs.getString('$prefix.ip') ?? '');
  final port = TextEditingController(text: '${prefs.getInt('$prefix.port') ?? 9100}');
  try {
    final savedIp = (prefs.getString('$prefix.ip') ?? '').trim();
    final savedPort = prefs.getInt('$prefix.port') ?? 9100;
    final (String, int)? choice = autoPrintIfConfigured &&
            savedIp.isNotEmpty && savedPort > 0 && savedPort <= 65535
        ? (savedIp, savedPort)
        : await showDialog<(String, int)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Imprimir por Wi-Fi / LAN'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('La impresora y el dispositivo deben estar conectados a la misma red.'),
                const SizedBox(height: 24),
                TextField(
                  controller: ip,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Dirección IP',
                    hintText: '192.168.1.100',
                    helperText: 'IP local asignada a la impresora',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: port,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Puerto TCP',
                    hintText: '9100',
                    helperText: 'Habitualmente 9100',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final p = int.tryParse(port.text.trim());
            if (ip.text.trim().isNotEmpty && p != null && p > 0 && p <= 65535) {
              Navigator.pop(dialogContext, (ip.text.trim(), p));
            }
          }, child: const Text('Imprimir')),
        ],
      ),
    );
    if (choice == null) return false;
    await prefs.setString('$prefix.ip', choice.$1);
    await prefs.setInt('$prefix.port', choice.$2);
    final clean = ticket.replaceAll(RegExp(r'[^\x00-\xFF]'), '?');
    final bytes = Uint8List.fromList([
      0x1b, 0x40, // ESC @: inicializar
      0x1b, 0x74, 0x10, // página de códigos occidental compatible
      ...latin1.encode(clean),
      0x0a, 0x0a, 0x0a,
      0x1d, 0x56, 0x00, // corte total
    ]);
    await sendNetworkTicket(choice.$1, choice.$2, bytes);
    return true;
  } finally {
    ip.dispose();
    port.dispose();
  }
}
