import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/mesero_remote_datasource.dart';

/// Gestión de una venta finalizada: nunca borrar físicamente ni reabrir
/// una venta incluida en un cierre de caja. Ambas acciones requieren permiso
/// de gerente/admin y una justificación, y operan transaccionalmente en el back.
class VentaHistoricaActions extends ConsumerStatefulWidget {
  const VentaHistoricaActions({
    super.key,
    required this.ventaId,
    required this.estado,
    required this.autorizado,
    required this.totalPagado,
    required this.onAnulada,
    required this.onCorregida,
  });

  final int ventaId;
  final String estado;
  final bool autorizado;
  final double totalPagado;
  final Future<void> Function() onAnulada;
  final Future<void> Function(int nuevaVentaId) onCorregida;

  @override
  ConsumerState<VentaHistoricaActions> createState() => _VentaHistoricaActionsState();
}

class _VentaHistoricaActionsState extends ConsumerState<VentaHistoricaActions> {
  bool _enProceso = false;
  bool get _anulada => widget.estado.toUpperCase() == 'ANULADA';
  bool get _finalizada => widget.estado.toUpperCase() == 'FINALIZADA';

  Future<void> _operar({required bool corregir}) async {
    if (_enProceso || !widget.autorizado ||
        !(_finalizada || (corregir && _anulada))) return;
    final motivo = TextEditingController();
    var acepto = false;
    final confirmacion = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(builder: (context, refresh) =>
        AlertDialog(
          scrollable: true,
          title: Text(corregir
              ? (_anulada
                  ? 'Retomar corrección #${widget.ventaId}'
                  : 'Corregir venta #${widget.ventaId}')
              : 'Anular venta #${widget.ventaId}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Esta operación es administrativa y deja auditoría. '
                  'No se borrarán la venta original, los pagos ni el cierre de caja.'),
              const SizedBox(height: 10),
              Text(corregir
                ? (_anulada
                    ? 'Esta venta ya está anulada. Se abrirá la corrección '
                      'pendiente si existe, o se creará un borrador editable '
                      'con sus productos y descuentos. La venta original '
                      'seguirá anulada: NO se volverá a devolver stock, '
                      'modificar el cierre ni duplicar pagos.'
                    : 'Se anulará la original y se generará una nueva venta '
                      'directa editable con los mismos productos, cantidades '
                      'y descuentos, pero sin pagos. Revisa el cobro anterior '
                      'antes de cobrar de nuevo.')
                : 'Se devolverá al inventario únicamente lo descontado por '
                  'la venta y se ajustarán los totales del sistema del cierre '
                  'sin modificar el dinero declarado en el arqueo.'),
              const SizedBox(height: 10),
              if (widget.totalPagado > 0)
                const Text('Atención: los pagos originales no se devuelven '
                    'automáticamente. Deberás gestionar su reembolso o '
                    'conciliación; quedarán marcados como pendientes.',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: motivo,
                autofocus: true,
                minLines: 2, maxLines: 4, maxLength: 300,
                onChanged: (_) => refresh(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motivo obligatorio (mínimo 8 caracteres)',
                  hintText: 'Explica el error y por qué se requiere corregir',
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acepto,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => refresh(() => acepto = value ?? false),
                title: Text(_anulada && corregir
                    ? 'Entiendo que se retoma una corrección y no se altera '
                      'nuevamente el inventario ni el cierre.'
                    : 'Confirmo el ajuste de inventario, cierre y '
                      'conciliación financiera.'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Volver')),
            FilledButton.icon(
              onPressed: acepto && motivo.text.trim().length >= 8
                  ? () => Navigator.pop(dialog, motivo.text.trim()) : null,
              icon: Icon(corregir
                  ? Icons.edit_note_rounded : Icons.block_rounded),
              label: Text(corregir
                  ? (_anulada ? 'Retomar corrección'
                      : 'Anular y crear corrección')
                  : 'Confirmar anulación'),
            ),
          ],
        ),
      ),
    );
    motivo.dispose();
    if (confirmacion == null || !mounted) return;
    setState(() => _enProceso = true);
    try {
      final api = MeseroRemoteDataSource(ref.read(apiClientProvider));
      if (corregir) {
        final result = await api.corregirVentaFinalizada(
            widget.ventaId, confirmacion);
        final nueva = (result['nuevaVentaId'] as num?)?.toInt();
        if (nueva == null) throw StateError('No se recibió la venta de reemplazo');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_anulada
              ? 'Corrección #$nueva lista para continuar. '
                'El stock y el cierre originales no se modificaron nuevamente.'
              : 'Venta #${widget.ventaId} anulada. '
                'Nueva venta editable #$nueva. Revisa pagos e inventario.')));
        await widget.onCorregida(nueva);
      } else {
        final result = await api.anularVentaFinalizada(
            widget.ventaId, confirmacion);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Venta anulada. '
              'Se reintegraron ${result['movimientosReintegrados'] ?? 0} '
              'productos de inventario. Reembolso: '
              '${result['reembolsoEstado'] ?? 'PENDIENTE'}')));
        await widget.onAnulada();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible realizar la corrección: $e')),
      );
    } finally {
      if (mounted) setState(() => _enProceso = false);
    }
  }

  Future<void> _desanular() async {
    if (_enProceso || !widget.autorizado || !_anulada) return;
    final motivo = TextEditingController();
    var acepto = false;
    final confirmacion = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          scrollable: true,
          title: Text('Desanular venta #${widget.ventaId}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 510),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Se restaurará la venta original como FINALIZADA. '
                'El inventario volverá a descontarse según las cantidades '
                'que se reintegraron al anular y el cierre se recalculará.'),
              const SizedBox(height: 10),
              const Text('No se crearán nuevos pagos ni una venta duplicada. '
                'El dinero realmente entregado en el cierre seguirá intacto.'),
              const SizedBox(height: 10),
              const Text('Si existe una corrección en borrador sin pagos, '
                'se archivará automáticamente. No se permite si la '
                'corrección ya se cobró, hubo reembolso o falta stock.',
                style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: motivo,
                autofocus: true,
                minLines: 2, maxLines: 4, maxLength: 300,
                onChanged: (_) => refresh(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motivo de desanulación (mínimo 8 caracteres)',
                  hintText: 'Explica por qué la venta debe recuperarse',
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                value: acepto,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => refresh(() => acepto = v ?? false),
                title: const Text('Confirmo que no se ha devuelto dinero '
                  'al cliente y que deseo recuperar esta venta.'),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: acepto && motivo.text.trim().length >= 8
                ? () => Navigator.pop(dialog, motivo.text.trim()) : null,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Confirmar desanulación')),
          ],
        ),
      ),
    );
    motivo.dispose();
    if (confirmacion == null || !mounted) return;
    setState(() => _enProceso = true);
    try {
      final data = await MeseroRemoteDataSource(ref.read(apiClientProvider))
          .desanularVentaFinalizada(widget.ventaId, confirmacion);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Venta #${widget.ventaId} restaurada como '
          '${data['estado'] ?? 'FINALIZADA'}. '
          'Stock y cierre reconciliados.')));
      await widget.onAnulada(); // Actualiza el detalle y los indicadores.
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo desanular: $e')));
    } finally {
      if (mounted) setState(() => _enProceso = false);
    }
  }

  Future<void> _verAuditoria() async {
    try {
      final result = await MeseroRemoteDataSource(ref.read(apiClientProvider))
          .auditoriaAnulacionVenta(widget.ventaId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text('Auditoría de venta #${widget.ventaId}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in <(String, String)>[
                  ('Motivo', result['motivo']?.toString() ?? 'No disponible'),
                  ('Responsable', result['actor']?.toString() ?? '-'),
                  ('Fecha', result['fecha']?.toString() ?? '-'),
                  ('Estado de reembolso', result['reembolso_estado']?.toString() ?? '-'),
                  ('Cierre original', result['cierre_id']?.toString() ?? 'Sin cierre'),
                  ('Nueva venta', result['reemplazo_vent_id']?.toString() ?? 'No aplica'),
                ]) ...[
                  Text(field.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText(field.$2),
                  const SizedBox(height: 11),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog),
              child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo consultar la auditoría: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.autorizado) return const SizedBox.shrink();
    if (_anulada) {
      return Card(
        child: Padding(padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 12, runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Chip(avatar: Icon(Icons.block_rounded, size: 18),
                label: Text('Venta anulada')),
              FilledButton.icon(
                onPressed: _enProceso
                    ? null : () => _operar(corregir: true),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Retomar o corregir venta'),
              ),
              OutlinedButton.icon(
                onPressed: _enProceso ? null : _desanular,
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Desanular venta'),
              ),
              OutlinedButton.icon(
                onPressed: _enProceso ? null : _verAuditoria,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Ver motivo y auditoría'),
              ),
              if (_enProceso) const SizedBox(
                width: 150,
                child: LinearProgressIndicator(),
              ),
            ],
          ),
        ),
      );
    }
    if (!_finalizada) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Administración de esta venta',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 5),
          const Text('Acciones exclusivas para Gerente y Administrador. '
              'Los movimientos originales y el arqueo quedan auditados.'),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(
              onPressed: _enProceso ? null : () => _operar(corregir: true),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Corregir venta'),
            ),
            OutlinedButton.icon(
              onPressed: _enProceso ? null : () => _operar(corregir: false),
              icon: const Icon(Icons.block_rounded),
              label: const Text('Anular venta'),
            ),
          ]),
          if (_enProceso) const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
        ]),
      ),
    );
  }
}
