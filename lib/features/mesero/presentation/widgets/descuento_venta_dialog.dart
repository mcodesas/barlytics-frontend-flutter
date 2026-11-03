import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Respuesta del formulario; NINGUNO con cero elimina un descuento.
class DescuentoVentaInput {
  const DescuentoVentaInput(this.tipo, this.valor, this.motivo);
  final String tipo;
  final double valor;
  final String motivo;
}

/// Diálogo de descuentos usado para venta completa, cuenta y producto.
/// Calcula una vista previa; el servidor vuelve a validar el monto.
Future<DescuentoVentaInput?> mostrarDialogoDescuento(
  BuildContext context, {
  required String titulo,
  required double base,
  String? tipoInicial,
  double? valorInicial,
}) async {
  final value = TextEditingController(
    text: (valorInicial ?? 0) > 0
        ? (valorInicial! % 1 == 0
            ? valorInicial.toInt().toString() : valorInicial.toString())
        : '',
  );
  final reason = TextEditingController();
  var type = tipoInicial == 'PORCENTAJE' ? 'PORCENTAJE' : 'VALOR';
  var submitting = false;
  final money = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
  final result = await showDialog<DescuentoVentaInput>(
    context: context,
    builder: (dialog) => StatefulBuilder(builder: (context, update) {
      double? amount() => double.tryParse(
        value.text.trim().replaceAll('.', '').replaceAll(',', '.'));
      final val = amount();
      final valid = val != null && val >= 0 &&
          (type == 'PORCENTAJE' ? val <= 100 : val <= base + .001);
      final saving = val != null && val > 0 && valid;
      final discounted = saving
          ? (type == 'PORCENTAJE' ? base * val / 100 : val) : 0.0;
      return AlertDialog(
        scrollable: true,
        title: Row(children: [
          const Icon(Icons.percent_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(titulo)),
        ]),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Subtotal antes de descuento: ' + money.format(base),
              style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 13),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PORCENTAJE', label: Text('% Porcentaje')),
                ButtonSegment(value: 'VALOR', label: Text(r'$ Valor fijo')),
              ],
              selected: {type},
              onSelectionChanged: (values) {
                update(() { type = values.first; value.clear(); });
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: value,
              autofocus: false,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => update(() {}),
              decoration: InputDecoration(
                labelText: type == 'PORCENTAJE'
                    ? 'Porcentaje entre 0 y 100'
                    : 'Descuento en pesos COP',
                hintText: type == 'PORCENTAJE' ? '10' : '5.000',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(type == 'PORCENTAJE'
                    ? Icons.percent_rounded : Icons.payments_outlined),
                errorText: value.text.isNotEmpty && !valid
                    ? 'El valor no puede superar el subtotal disponible.'
                    : null,
              ),
            ),
            if (type == 'PORCENTAJE') ...[
              const SizedBox(height: 9),
              Wrap(spacing: 8, children: [
                for (final pct in [5, 10, 15, 20])
                  ActionChip(label: Text('$pct%'), onPressed: () => update(
                    () => value.text = pct.toString())),
              ]),
            ],
            const SizedBox(height: 13),
            TextField(
              controller: reason,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Promoción, cortesía, cliente frecuente…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.42),
                borderRadius: BorderRadius.circular(15)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('DESCUENTO: ' + money.format(discounted),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('A PAGAR (sin propina): ' +
                    money.format((base - discounted).clamp(0, double.infinity)),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ]),
            ),
            const SizedBox(height: 9),
            Text('No se puede modificar un valor ya pagado. '
                'El descuento queda registrado para auditoría.',
                style: TextStyle(fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar')),
          if ((valorInicial ?? 0) > 0)
            TextButton.icon(
              onPressed: submitting ? null
                  : () => Navigator.pop(dialog,
                      const DescuentoVentaInput('NINGUNO', 0, 'Descuento retirado')),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Quitar descuento')),
          FilledButton.icon(
            onPressed: !saving || submitting ? null : () {
              submitting = true;
              Navigator.pop(dialog, DescuentoVentaInput(type, val, reason.text.trim()));
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Aplicar descuento'),
          ),
        ],
      );
    }),
  );
  // Liberar al cerrar el diálogo después de terminar el frame de transición.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    value.dispose();
    reason.dispose();
  });
  return result;
}
